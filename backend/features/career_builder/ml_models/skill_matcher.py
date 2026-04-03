"""
Hybrid Career Analyzer - LLM-First + Smart Compound Skill Fallback ✅
"""
import json
import re
import logging
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass
from uuid import UUID

from features.career_builder.ml_models.skill_extractor import SkillExtractor
from features.career_builder.ml_models.level_detector import LevelDetector
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
        logger.debug("🔍 Initializing HybridCareerAnalyzer")

        # ✅ بياخد الـ repository من بره أو بيعمله بنفسه
        if repository:
            self.repo = repository
        else:
            from features.career_builder.repositories.career_repository import CareerRepository
            from shared.providers.supabase.database import db as supabase_db
            self.repo = CareerRepository(supabase_db)

        self.skill_extractor = SkillExtractor()
        self.level_detector  = LevelDetector()
        self.llm             = create_llm_provider()
        logger.debug("✅ HybridCareerAnalyzer ready")

    # =====================================================
    # الطريقة الرئيسية
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

        cv_text = cv_data.get('text_content', '')
        cv_skills_result = await self.skill_extractor.extract_skills_from_cv(
            cv_text=cv_text,
            parsed_cv_data=cv_data.get('parsed_content', {})
        )
        cv_skills = cv_skills_result.get('normalized_skills', [])
        logger.debug(f"🔍 Extracted {len(cv_skills)} CV skills")

        if track_id:
            return await self._analyze_with_database(cv_text, cv_skills, track_id)
        elif job_description:
            return await self._analyze_dynamic(cv_text, cv_skills, job_description)
        else:
            raise ValueError("Must provide track_id or job_description")

    # =====================================================
    # التحليل من قاعدة البيانات
    # =====================================================
    async def _analyze_with_database(
        self,
        cv_text: str,
        cv_skills: List[str],
        track_id: int
    ) -> HybridAnalysisResult:
        track_skills = await self.repo.get_skills_by_track(track_id)
        if not track_skills:
            logger.warning("⚠️ No track skills, falling back to dynamic")
            return await self._analyze_dynamic(
                cv_text, cv_skills, "General technical position (fallback)"
            )

        required_names = [
            s['skill_name'] if isinstance(s, dict) else s
            for s in track_skills
        ]

        matched_names, missing_names, method = await self._match_with_llm_or_fallback(
            cv_skills=cv_skills,
            required_skills=required_names
        )

        matched_skills, missing_skills = self._build_skill_details(
            matched_names, missing_names, track_skills
        )

        total     = len(required_names)
        match_pct = (len(matched_names) / total * 100) if total else 0
        est_weeks = sum(s.get('duration_weeks', 4) for s in missing_skills)

        return HybridAnalysisResult(
            source='database',
            matching_method=method,
            cv_skills=cv_skills,
            required_skills=required_names,
            matched_skills=matched_skills,
            missing_skills=missing_skills,
            match_percentage=round(match_pct, 1),
            estimated_weeks=est_weeks
        )

    # =====================================================
    # التحليل الديناميكي
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
                source='dynamic', matching_method='failed',
                cv_skills=cv_skills, required_skills=[],
                matched_skills=[], missing_skills=[],
                match_percentage=0.0, estimated_weeks=0
            )

        matched_names, missing_names, method = await self._match_with_llm_or_fallback(
            cv_skills=cv_skills,
            required_skills=required_skills
        )

        matched_skills = [{'skill_name': s} for s in matched_names]
        missing_skills = [{'skill_name': s, 'duration_weeks': 4} for s in missing_names]
        total          = len(required_skills)

        return HybridAnalysisResult(
            source='dynamic',
            matching_method=method,
            cv_skills=cv_skills,
            required_skills=required_skills,
            matched_skills=matched_skills,
            missing_skills=missing_skills,
            match_percentage=round(len(matched_names) / total * 100, 1) if total else 0,
            estimated_weeks=len(missing_skills) * 4
        )

    # =====================================================
    # LLM-First مع Compound Fallback
    # =====================================================
    async def _match_with_llm_or_fallback(
        self,
        cv_skills: List[str],
        required_skills: List[str]
    ) -> Tuple[List[str], List[str], str]:
        try:
            matched, missing = await self._llm_match_skills(cv_skills, required_skills)

            if not matched and not missing:
                raise ValueError("LLM returned empty results")

            unknown = set(matched + missing) - set(required_skills)
            if unknown:
                logger.warning(f"⚠️ LLM hallucinated: {unknown}")
                raise ValueError("Hallucinated skills detected")

            returned              = set(matched + missing)
            expected              = set(required_skills)
            missing_from_response = expected - returned
            if missing_from_response:
                logger.warning(f"⚠️ LLM skipped {len(missing_from_response)} skills")
                missing = missing + list(missing_from_response)

            logger.info(f"✅ LLM matched: {len(matched)}, missing: {len(missing)}")
            return matched, missing, 'llm'

        except Exception as e:
            logger.warning(f"⚠️ LLM failed ({e}), using compound fallback")
            matched, missing = self._compound_skill_fallback(cv_skills, required_skills)
            return matched, missing, 'compound_fallback'

    async def _llm_match_skills(
        self,
        cv_skills: List[str],
        required_skills: List[str]
    ) -> Tuple[List[str], List[str]]:
        prompt = f"""
You are a technical skill matching expert.

The database stores skills as COMPOUND entries, for example:
- "JavaScript & Frameworks (React/Angular)" — covered if candidate knows React OR Angular OR JavaScript
- "Cloud Platforms (AWS/Azure/GCP)" — covered if candidate knows AWS OR Azure OR GCP
- "Backend Frameworks (Django/Express)" — covered if candidate knows Django OR Express
- "Containerization (Docker/Kubernetes)" — covered if candidate knows Docker OR Kubernetes

Your task: determine which REQUIRED skills are covered by the candidate's CV skills.

RULES:
1. A required skill is "matched" if ANY of the technologies it mentions appear in the CV skills
2. Consider reasonable synonyms (e.g. "Node.js" = "NodeJS", "Postgres" = "PostgreSQL")
3. Return ONLY skills from the Required list — never invent new skill names
4. Every required skill must appear in either "matched" or "missing"
5. Return pure JSON only — no explanation, no markdown

CV Skills:
{json.dumps(cv_skills, ensure_ascii=False)}

Required Skills:
{json.dumps(required_skills, ensure_ascii=False)}

Return exactly this JSON:
{{
  "matched": ["...skills from Required that CV covers..."],
  "missing": ["...skills from Required that CV does NOT cover..."]
}}
"""
        response = await self.llm.get_response(prompt, need_json_output=True)
        parsed   = self._safe_parse_llm_json(response)
        matched  = parsed.get('matched', [])
        missing  = parsed.get('missing', [])

        if not isinstance(matched, list) or not isinstance(missing, list):
            raise ValueError("LLM response has wrong structure")

        return matched, missing

    # =====================================================
    # Compound Skill Fallback
    # =====================================================
    def _compound_skill_fallback(
        self,
        cv_skills: List[str],
        required_skills: List[str]
    ) -> Tuple[List[str], List[str]]:
        matched        = []
        missing        = []
        cv_normalized  = [self._normalize(s) for s in cv_skills]

        for req_skill in required_skills:
            req_norm   = self._normalize(req_skill)
            is_matched = any(
                self._word_boundary_match(cv_norm, req_norm)
                for cv_norm in cv_normalized
            )
            if is_matched:
                matched.append(req_skill)
            else:
                missing.append(req_skill)

        logger.debug(f"🔍 Compound fallback: {len(matched)} matched, {len(missing)} missing")
        return matched, missing

    def _word_boundary_match(self, cv_norm: str, db_skill_norm: str) -> bool:
        if not cv_norm:
            return False
        pattern = r'\b' + re.escape(cv_norm) + r'\b'
        return bool(re.search(pattern, db_skill_norm))

    # =====================================================
    # استخراج المهارات من JD
    # =====================================================
    async def _extract_required_skills_from_jd(
        self, job_description: str
    ) -> List[str]:
        prompt = f"""
Extract all technical and soft skills from this job description.
Return ONLY a JSON array of skill name strings.
No explanation, no markdown — pure JSON only.

Job Description:
{job_description}

Example: ["Python", "SQL", "Docker", "Teamwork"]
"""
        try:
            response = await self.llm.get_response(prompt, need_json_output=True)
            parsed   = self._safe_parse_llm_json(response)
            if isinstance(parsed, list):
                return [s for s in parsed if isinstance(s, str)]
            if isinstance(parsed, dict):
                return [s for s in parsed.get('skills', []) if isinstance(s, str)]
            return []
        except Exception as e:
            logger.error(f"❌ JD skill extraction failed: {e}")
            return []

    # =====================================================
    # Helpers
    # =====================================================
    def _normalize(self, skill: str) -> str:
        if not isinstance(skill, str):
            skill = str(skill)
        normalized = skill.lower().strip()
        special_cases = [
            (r'\bc\+\+',       'cpp'),
            (r'\bc#',          'csharp'),
            (r'\basp\.net\b',  'aspnet'),
            (r'\.net\b',       'dotnet'),
            (r'\bnode\.js\b',  'nodejs'),
            (r'\breact\.js\b', 'reactjs'),
            (r'\bvue\.js\b',   'vuejs'),
            (r'\bnext\.js\b',  'nextjs'),
            (r'\bnuxt\.js\b',  'nuxtjs'),
        ]
        for pattern, replacement in special_cases:
            normalized = re.sub(pattern, replacement, normalized)
        normalized = re.sub(r'[^a-z0-9\s]', ' ', normalized)
        normalized = ' '.join(normalized.split())
        return normalized

    def _safe_parse_llm_json(self, response: Any) -> Any:
        if isinstance(response, (dict, list)):
            return response
        if isinstance(response, str):
            cleaned = re.sub(r'```(?:json)?', '', response).strip()
            match   = re.search(r'(\{.*\}|\[.*\])', cleaned, re.DOTALL)
            if match:
                return json.loads(match.group())
        raise ValueError(f"Cannot parse LLM response: {type(response)}")

    def _build_skill_details(
        self,
        matched_names: List[str],
        missing_names: List[str],
        track_skills:  List[Any]
    ) -> Tuple[List[Dict], List[Dict]]:
        matched_skills = []
        for name in matched_names:
            db = self._find_skill_in_list(name, track_skills)
            matched_skills.append({
                'skill_name': name,
                'skill_id':   db.get('skill_id')          if db else None,
                'category':   db.get('category', 'General') if db else 'General',
                'importance': db.get('importance', 3)      if db else 3,
            })

        missing_skills = []
        for name in missing_names:
            db = self._find_skill_in_list(name, track_skills)
            missing_skills.append({
                'skill_name':     name,
                'skill_id':       db.get('skill_id')            if db else None,
                'category':       db.get('category', 'General') if db else 'General',
                'importance':     db.get('importance', 3)       if db else 3,
                'duration_weeks': db.get('duration_weeks', 4)   if db else 4,
            })

        return matched_skills, missing_skills

    def _find_skill_in_list(
        self, skill_name: str, skill_list: List[Any]
    ) -> Optional[Dict]:
        norm = self._normalize(skill_name)
        for s in skill_list:
            if isinstance(s, dict):
                if self._normalize(s.get('skill_name', '')) == norm:
                    return s
        return None

    # =====================================================
    # Endpoint للاختبار
    # =====================================================
    async def match_skills(
        self, cv_skills: List[str], track_id: int
    ) -> Dict[str, Any]:
        track_skills = await self.repo.get_skills_by_track(track_id)
        if not track_skills:
            return {"status": "error", "message": f"No skills for track {track_id}"}

        required_names = [
            s['skill_name'] if isinstance(s, dict) else s
            for s in track_skills
        ]

        matched, missing, method = await self._match_with_llm_or_fallback(
            cv_skills, required_names
        )

        matched_details = []
        for name in matched:
            skill = self._find_skill_in_list(name, track_skills)
            matched_details.append({
                'skill_name': name,
                'skill_id':   skill.get('skill_id')            if skill else None,
                'category':   skill.get('category', 'General') if skill else 'General',
                'confidence': 1.0 if method == 'llm' else 0.75,
            })

        total = len(required_names)
        return {
            "status":          "success",
            "matching_method": method,
            "cv_skills":       cv_skills,
            "track_id":        track_id,
            "matched_count":   len(matched),
            "missing_count":   len(missing),
            "match_percentage": round(len(matched) / total * 100, 1) if total else 0,
            "matched_skills":  matched_details,
            "missing_skills":  missing,
        }


SkillMatcher = HybridCareerAnalyzer