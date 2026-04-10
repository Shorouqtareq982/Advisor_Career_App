"""
Hybrid Career Analyzer - LLM-First + Alias-Aware Compound Skill Fallback
"""

import json
import re
import logging
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass
from uuid import UUID

from features.career_builder.ml_models.skill_extractor import SkillExtractor
from shared.providers.llm_models.llm_provider import create_llm_provider

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


@dataclass
class HybridAnalysisResult:
    source: str
    matching_method: str
    cv_skills: List[str]
    required_skills: List[str]
    matched_skills: List[Dict]
    missing_skills: List[Dict]
    skill_levels: Optional[List[Dict]] = None
    match_percentage: float = 0.0
    estimated_weeks: int = 0


class HybridCareerAnalyzer:

    def __init__(self, repository=None):
        logger.debug("Initializing HybridCareerAnalyzer")

        if repository:
            self.repo = repository
        else:
            from features.career_builder.repositories.career_repository import CareerRepository
            from shared.providers.supabase.database import db as supabase_db
            self.repo = CareerRepository(supabase_db)

        self.skill_extractor = SkillExtractor()
        self.llm = create_llm_provider()

        logger.debug("HybridCareerAnalyzer ready")

    # =====================================================
    # MAIN ENTRY
    # =====================================================

    async def analyze(
        self,
        cv_id: UUID,
        track_id: Optional[int] = None,
        job_description: Optional[str] = None
    ) -> HybridAnalysisResult:
        cv_data = await self.repo.get_cv_by_id(cv_id)
        if not cv_data:
            raise ValueError(f"CV not found: {cv_id}")

        cv_text = cv_data.get("text_content", "")
        parsed_content = cv_data.get("parsed_content", {})

        cv_skills_result = await self.skill_extractor.extract_skills_from_cv(
            cv_text=cv_text,
            parsed_cv_data=parsed_content
        )
        cv_skills = cv_skills_result.get("normalized_skills", [])

        logger.info(f"🔥 Extracted CV skills: {cv_skills}")
        logger.debug(f"Extracted {len(cv_skills)} CV skills")

        if track_id:
            return await self._analyze_with_database(cv_text, cv_skills, track_id)
        elif job_description:
            return await self._analyze_dynamic(cv_text, cv_skills, job_description)
        else:
            raise ValueError("Must provide track_id or job_description")

    # =====================================================
    # DATABASE ANALYSIS
    # =====================================================

    async def _analyze_with_database(
        self,
        cv_text: str,
        cv_skills: List[str],
        track_id: int
    ) -> HybridAnalysisResult:
        track_skills = await self.repo.get_skills_by_track(track_id)
        if not track_skills:
            logger.warning("No track skills found, falling back to dynamic mode")
            return await self._analyze_dynamic(
                cv_text=cv_text,
                cv_skills=cv_skills,
                job_description="General technical position"
            )

        required_names = [
            s["skill_name"] if isinstance(s, dict) else str(s)
            for s in track_skills
        ]

        matched_names, missing_names, method = await self._match_with_llm_or_fallback(
            cv_skills=cv_skills,
            required_skills=required_names,
            track_skills=track_skills
        )

        matched_skills, missing_skills = self._build_skill_details(
            matched_names=matched_names,
            missing_names=missing_names,
            track_skills=track_skills
        )

        total = len(required_names)
        match_pct = (len(matched_names) / total * 100) if total else 0.0
        est_weeks = sum(s.get("duration_weeks", 4) for s in missing_skills)

        return HybridAnalysisResult(
            source="database",
            matching_method=method,
            cv_skills=cv_skills,
            required_skills=required_names,
            matched_skills=matched_skills,
            missing_skills=missing_skills,
            match_percentage=round(match_pct, 1),
            estimated_weeks=est_weeks
        )

    # =====================================================
    # DYNAMIC ANALYSIS
    # =====================================================

    async def _analyze_dynamic(
        self,
        cv_text: str,
        cv_skills: List[str],
        job_description: str
    ) -> HybridAnalysisResult:
        required_skills = await self._extract_required_skills_from_jd(job_description)

        if not required_skills:
            return HybridAnalysisResult(
                source="dynamic",
                matching_method="failed",
                cv_skills=cv_skills,
                required_skills=[],
                matched_skills=[],
                missing_skills=[],
                match_percentage=0.0,
                estimated_weeks=0
            )

        matched_names, missing_names, method = await self._match_with_llm_or_fallback(
            cv_skills=cv_skills,
            required_skills=required_skills,
            track_skills=None
        )

        matched_skills = [{"skill_name": s} for s in matched_names]
        missing_skills = [{"skill_name": s, "duration_weeks": 4} for s in missing_names]

        total = len(required_skills)

        return HybridAnalysisResult(
            source="dynamic",
            matching_method=method,
            cv_skills=cv_skills,
            required_skills=required_skills,
            matched_skills=matched_skills,
            missing_skills=missing_skills,
            match_percentage=round((len(matched_names) / total * 100), 1) if total else 0.0,
            estimated_weeks=len(missing_skills) * 4
        )

    # =====================================================
    # MATCHING LOGIC
    # =====================================================

    async def _match_with_llm_or_fallback(
        self,
        cv_skills: List[str],
        required_skills: List[str],
        track_skills: Optional[List[Dict[str, Any]]] = None
    ) -> Tuple[List[str], List[str], str]:
        try:
            matched, missing = await self._llm_match_skills(cv_skills, required_skills)

            if not matched and not missing:
                raise ValueError("LLM returned empty results")

            unknown = set(matched + missing) - set(required_skills)
            if unknown:
                logger.warning(f"LLM hallucinated unknown skills: {unknown}")
                raise ValueError("Hallucinated skills detected")

            returned = set(matched + missing)
            expected = set(required_skills)
            skipped = expected - returned
            if skipped:
                logger.warning(f"LLM skipped {len(skipped)} skills")
                missing.extend(list(skipped))

            logger.info(f"LLM matched: {len(matched)}, missing: {len(missing)}")
            return matched, missing, "llm"

        except Exception as e:
            logger.warning(f"LLM matching failed ({e}), using alias-aware compound fallback")

            if track_skills:
                matched, missing = self._compound_skill_fallback(cv_skills, track_skills)
            else:
                matched, missing = self._compound_skill_fallback_legacy(cv_skills, required_skills)

            return matched, missing, "compound_fallback"

    async def _llm_match_skills(
        self,
        cv_skills: List[str],
        required_skills: List[str]
    ) -> Tuple[List[str], List[str]]:
        prompt = f"""
You are a technical skill matching expert.

A required skill can be a compound entry, for example:
- "JavaScript & Frameworks (React/Angular)"
- "Cloud Platforms (AWS/Azure/GCP)"
- "Backend Frameworks (Django/Express)"
- "Containerization (Docker/Kubernetes)"

RULES:
1. A required skill is matched if ANY relevant technology inside it appears in CV skills
2. Consider common aliases and synonyms
3. Return ONLY skills from the required list
4. Every required skill must be placed in either matched or missing
5. Return JSON only

CV Skills:
{json.dumps(cv_skills, ensure_ascii=False)}

Required Skills:
{json.dumps(required_skills, ensure_ascii=False)}

Return:
{{
  "matched": ["..."],
  "missing": ["..."]
}}
"""
        response = await self.llm.get_response(
            prompt=prompt,
            need_json_output=True
        )

        parsed = self._safe_parse_llm_json(response)
        matched = parsed.get("matched", [])
        missing = parsed.get("missing", [])

        if not isinstance(matched, list) or not isinstance(missing, list):
            raise ValueError("LLM response has wrong structure")

        return matched, missing

    # =====================================================
    # FALLBACK MATCHING
    # =====================================================

    def _compound_skill_fallback(
        self,
        cv_skills: List[str],
        track_skills: List[Dict[str, Any]]
    ) -> Tuple[List[str], List[str]]:
        """
        Alias-aware fallback matching.

        A DB skill is considered matched if any of:
        - exact normalized skill_name match
        - exact normalized alias match
        - meaningful token overlap against expanded aliases/skill_name
        """
        matched = []
        missing = []

        normalized_cv_skills = {
            self._normalize(skill)
            for skill in cv_skills
            if skill
        }

        expanded_cv_tokens = set()
        for skill in cv_skills:
            expanded_cv_tokens.update(self._expand_skill_tokens(skill))

        stop_tokens = {
            "and", "or", "for", "with", "the", "tool", "tools",
            "basics", "advanced", "development", "design"
        }

        for skill_obj in track_skills:
            skill_name = skill_obj.get("skill_name", "")
            aliases = skill_obj.get("aliases", []) or []

            candidate_terms = [skill_name] + aliases

            normalized_candidates = set()
            expanded_candidates = set()

            for term in candidate_terms:
                if not term:
                    continue

                normalized_term = self._normalize(term)
                if normalized_term:
                    normalized_candidates.add(normalized_term)

                expanded_candidates.update(self._expand_skill_tokens(term))

            exact_match = any(candidate in normalized_cv_skills for candidate in normalized_candidates)

            meaningful_tokens = {
                token for token in expanded_candidates
                if token and len(token) > 2 and token not in stop_tokens
            }
            matched_tokens = meaningful_tokens.intersection(expanded_cv_tokens)

            token_match = len(matched_tokens) >= 1

            if exact_match or token_match:
                matched.append(skill_name)
            else:
                missing.append(skill_name)

        logger.debug(
            f"Alias-aware fallback matched={matched}, missing={missing}, cv_skills={cv_skills}"
        )
        return matched, missing

    def _compound_skill_fallback_legacy(
        self,
        cv_skills: List[str],
        required_skills: List[str]
    ) -> Tuple[List[str], List[str]]:
        matched = []
        missing = []

        normalized_cv_skills = {
            self._normalize(skill)
            for skill in cv_skills
            if skill
        }

        cv_tokens = set()
        for skill in cv_skills:
            cv_tokens.update(self._expand_skill_tokens(skill))

        for req_skill in required_skills:
            normalized_req = self._normalize(req_skill)
            req_tokens = self._expand_skill_tokens(req_skill)

            exact_match = normalized_req in normalized_cv_skills

            meaningful_tokens = {
                token for token in req_tokens
                if token and len(token) > 2 and token not in {"and", "or", "for", "with", "the"}
            }
            matched_tokens = meaningful_tokens.intersection(cv_tokens)

            token_match = len(matched_tokens) >= 1

            if exact_match or token_match:
                matched.append(req_skill)
            else:
                missing.append(req_skill)

        return matched, missing

    def _expand_skill_tokens(self, skill: str) -> List[str]:
        """
        Break compound skill strings into comparable normalized tokens.
        Example:
        "Cloud Platforms (AWS/Azure/GCP)" -> ["cloud platforms", "aws", "azure", "gcp"]
        """
        normalized = self._normalize(skill)

        tokens = set()
        if normalized:
            tokens.add(normalized)

        parts = re.split(r"[()/,&\-]| or | and ", skill.lower())
        for part in parts:
            cleaned = self._normalize(part)
            if cleaned and len(cleaned) > 1:
                tokens.add(cleaned)

        alias_map = {
            "aws": "amazon web services",
            "gcp": "google cloud platform",
            "nodejs": "node.js",
            "reactjs": "react",
            "vuejs": "vue",
            "cpp": "c++",
            "csharp": "c#",
            "postgres": "postgresql",
            "k8s": "kubernetes",
            "py": "python",
            "js": "javascript",
            "ts": "typescript",
            "plt": "matplotlib",
            "sns": "seaborn",
            "pd": "pandas",
            "np": "numpy",
        }

        expanded = set(tokens)
        for token in list(tokens):
            if token in alias_map:
                expanded.add(alias_map[token])
            for k, v in alias_map.items():
                if token == v:
                    expanded.add(k)

        return list(expanded)

    # =====================================================
    # JOB DESCRIPTION EXTRACTION
    # =====================================================

    async def _extract_required_skills_from_jd(self, job_description: str) -> List[str]:
        prompt = f"""
Extract all technical skills from this job description.
Return ONLY a valid JSON array of strings.

Job Description:
{job_description}

Example:
["Python", "SQL", "Docker", "Communication"]
"""
        try:
            response = await self.llm.get_response(
                prompt=prompt,
                need_json_output=True
            )
            parsed = self._safe_parse_llm_json(response)

            if isinstance(parsed, list):
                return [s for s in parsed if isinstance(s, str)]

            if isinstance(parsed, dict):
                return [s for s in parsed.get("skills", []) if isinstance(s, str)]

            return []
        except Exception as e:
            logger.error(f"JD skill extraction failed: {e}")
            return []

    # =====================================================
    # HELPERS
    # =====================================================

    def _normalize(self, skill: str) -> str:
        if not isinstance(skill, str):
            skill = str(skill)

        normalized = skill.lower().strip()

        replacements = [
            (r"\bc\+\+\b", "cpp"),
            (r"\bc#\b", "csharp"),
            (r"\basp\.net\b", "aspnet"),
            (r"\.net\b", "dotnet"),
            (r"\bnode\.js\b", "nodejs"),
            (r"\breact\.js\b", "reactjs"),
            (r"\bvue\.js\b", "vuejs"),
            (r"\bnext\.js\b", "nextjs"),
            (r"\bnuxt\.js\b", "nuxtjs"),
        ]

        for pattern, replacement in replacements:
            normalized = re.sub(pattern, replacement, normalized)

        normalized = re.sub(r"[^a-z0-9\s]", " ", normalized)
        normalized = " ".join(normalized.split())
        return normalized

    def _safe_parse_llm_json(self, response: Any) -> Any:
        if isinstance(response, (dict, list)):
            return response

        if isinstance(response, str):
            cleaned = re.sub(r"```(?:json)?", "", response).strip()
            match = re.search(r"(\{.*\}|\[.*\])", cleaned, re.DOTALL)
            if match:
                return json.loads(match.group())

        raise ValueError(f"Cannot parse LLM response: {type(response)}")

    def _build_skill_details(
        self,
        matched_names: List[str],
        missing_names: List[str],
        track_skills: List[Any]
    ) -> Tuple[List[Dict], List[Dict]]:
        matched_skills = []
        for name in matched_names:
            db = self._find_skill_in_list(name, track_skills)
            matched_skills.append({
                "skill_name": name,
                "skill_id": db.get("skill_id") if db else None,
                "category": db.get("category", "General") if db else "General",
                "importance": db.get("importance", 3) if db else 3,
            })

        missing_skills = []
        for name in missing_names:
            db = self._find_skill_in_list(name, track_skills)
            missing_skills.append({
                "skill_name": name,
                "skill_id": db.get("skill_id") if db else None,
                "category": db.get("category", "General") if db else "General",
                "importance": db.get("importance", 3) if db else 3,
                "duration_weeks": db.get("duration_weeks", 4) if db else 4,
                "is_core": db.get("is_core", True) if db else True,
            })

        return matched_skills, missing_skills

    def _find_skill_in_list(
        self,
        skill_name: str,
        skill_list: List[Any]
    ) -> Optional[Dict]:
        norm = self._normalize(skill_name)
        for s in skill_list:
            if isinstance(s, dict):
                if self._normalize(s.get("skill_name", "")) == norm:
                    return s
        return None

    # =====================================================
    # TESTING HELPER
    # =====================================================

    async def match_skills(self, cv_skills: List[str], track_id: int) -> Dict[str, Any]:
        track_skills = await self.repo.get_skills_by_track(track_id)
        if not track_skills:
            return {"status": "error", "message": f"No skills for track {track_id}"}

        required_names = [
            s["skill_name"] if isinstance(s, dict) else str(s)
            for s in track_skills
        ]

        matched, missing, method = await self._match_with_llm_or_fallback(
            cv_skills=cv_skills,
            required_skills=required_names,
            track_skills=track_skills
        )

        matched_details = []
        for name in matched:
            skill = self._find_skill_in_list(name, track_skills)
            matched_details.append({
                "skill_name": name,
                "skill_id": skill.get("skill_id") if skill else None,
                "category": skill.get("category", "General") if skill else "General",
                "confidence": 1.0 if method == "llm" else 0.75,
            })

        total = len(required_names)

        return {
            "status": "success",
            "matching_method": method,
            "cv_skills": cv_skills,
            "track_id": track_id,
            "matched_count": len(matched),
            "missing_count": len(missing),
            "match_percentage": round((len(matched) / total * 100), 1) if total else 0.0,
            "matched_skills": matched_details,
            "missing_skills": missing,
        }


SkillMatcher = HybridCareerAnalyzer