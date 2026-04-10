"""
Skill Extractor - Robust Version
Uses parsed CV data + CV text + keyword fallback to extract technical skills
"""

import json
import re
import logging
from typing import List, Dict, Any, Set, Optional

from pydantic import BaseModel, Field
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider

logger = logging.getLogger(__name__)


# =====================================================
# PYDANTIC SCHEMA
# =====================================================

class ExtractedSkills(BaseModel):
    technical_skills: List[str] = Field(default_factory=list)
    soft_skills: List[str] = Field(default_factory=list)
    certifications: List[str] = Field(default_factory=list)


# =====================================================
# PROMPT
# =====================================================

SKILL_EXTRACTION_PROMPT = """
You are an expert CV analyzer. Extract ALL technical skills from this CV text.

Instructions:
1. Extract programming languages, frameworks, libraries, tools, databases, cloud platforms, DevOps tools
2. Include both explicit mentions and implicit technical skills from project descriptions
3. Normalize obvious aliases (e.g. JS -> JavaScript, Postgres -> PostgreSQL)
4. Remove duplicates
5. Only include technical/professional skills, NOT soft skills
6. Return ONLY valid JSON

CV Text:
{cv_text}

Return JSON:
{{
  "technical_skills": ["Python", "JavaScript", "Docker"],
  "soft_skills": [],
  "certifications": []
}}
"""


# =====================================================
# SKILL EXTRACTOR
# =====================================================

class SkillExtractor:
    """
    Extracts technical skills from CV using:
    1) parsed CV data
    2) raw CV text
    3) LLM extraction if available
    4) keyword fallback
    """

    SKILL_NORMALIZATIONS = {
        "js": "javascript",
        "ts": "typescript",
        "py": "python",
        "cpp": "c++",
        "csharp": "c#",
        "reactjs": "react",
        "react.js": "react",
        "vuejs": "vue",
        "vue.js": "vue",
        "angularjs": "angular",
        "nodejs": "node.js",
        "node": "node.js",
        "expressjs": "express",
        "nextjs": "next.js",
        "next.js": "next.js",
        "nuxtjs": "nuxt.js",
        "nuxt.js": "nuxt.js",
        "postgres": "postgresql",
        "psql": "postgresql",
        "mongo": "mongodb",
        "mssql": "sql server",
        "k8s": "kubernetes",
        "kube": "kubernetes",
        "aws": "amazon web services",
        "gcp": "google cloud platform",
        "sklearn": "scikit-learn",
        "tf": "tensorflow",
    }

    KNOWN_TECH_KEYWORDS = {
        # Programming
        "python", "javascript", "typescript", "java", "c++", "c#", "php", "ruby", "go",
        "rust", "kotlin", "swift", "dart", "sql",

        # Web
        "html", "css", "react", "vue", "angular", "flask", "django", "fastapi",
        "spring", "express", "node.js", "laravel", "asp.net", ".net",

        # Data / AI
        "pandas", "numpy", "matplotlib", "seaborn", "scikit-learn", "tensorflow",
        "pytorch", "machine learning", "deep learning", "data science",

        # DB
        "mysql", "postgresql", "mongodb", "redis", "sqlite", "sql server", "oracle",

        # Tools / infra
        "docker", "kubernetes", "git", "github", "gitlab", "linux", "bash",
        "postman", "swagger", "graphql", "rest api", "web api",

        # Big data / analytics
        "spark", "hadoop", "data analysis", "data visualization", "statistics",
        "statistical analysis", "data cleaning", "data wrangling"
    }

    def __init__(self, llm: Optional[LLMProvider] = None):
        self.llm = llm or create_llm_provider()

    async def extract_skills_from_cv(
        self,
        cv_text: str,
        parsed_cv_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Main method:
        - parse safe dict
        - extract from structured data
        - extract directly from raw text
        - try LLM if available
        - merge, normalize, validate
        """
        logger.info("Starting skill extraction...")

        parsed_cv_data = self._ensure_dict(parsed_cv_data)

        explicit_skills = self._extract_from_parsed_data(parsed_cv_data)
        text_skills = self._extract_from_text(cv_text)

        # Try LLM, but never depend on it
        llm_result = await self._extract_with_llm(cv_text)

        all_skills = set()
        all_skills.update(explicit_skills)
        all_skills.update(text_skills)
        all_skills.update(llm_result.get("technical_skills", []))

        normalized_skills = self._normalize_skills(all_skills)
        validated_skills = self._validate_technical_skills(normalized_skills)

        confidence = self._calculate_extraction_confidence(
            validated_count=len(validated_skills),
            total_count=max(len(all_skills), 1)
        )

        logger.info(f"Extracted validated skills: {sorted(validated_skills)}")

        return {
            "extracted_skills": sorted(list(all_skills)),
            "normalized_skills": sorted(list(validated_skills)),
            "certifications": llm_result.get("certifications", []),
            "extraction_confidence": confidence
        }

    # =====================================================
    # SAFE INPUT HANDLING
    # =====================================================

    def _ensure_dict(self, parsed_data: Any) -> Dict[str, Any]:
        if parsed_data is None:
            return {}

        if isinstance(parsed_data, dict):
            return parsed_data

        if isinstance(parsed_data, str):
            try:
                loaded = json.loads(parsed_data)
                return loaded if isinstance(loaded, dict) else {}
            except Exception:
                logger.warning("parsed_cv_data is invalid JSON string; falling back to empty dict")
                return {}

        logger.warning(f"Unexpected parsed_cv_data type: {type(parsed_data)}")
        return {}

    # =====================================================
    # STRUCTURED EXTRACTION
    # =====================================================

    def _extract_from_parsed_data(self, parsed_data: Dict[str, Any]) -> Set[str]:
        skills = set()

        if not parsed_data:
            return skills

        # 1) skills field
        skill_data = parsed_data.get("skills")

        if isinstance(skill_data, list):
            for item in skill_data:
                if isinstance(item, str):
                    cleaned = item.strip()
                    if cleaned:
                        skills.add(cleaned)
                elif isinstance(item, dict):
                    skill_name = item.get("skill_name") or item.get("name") or item.get("skill")
                    if skill_name:
                        skills.add(str(skill_name).strip())

        elif isinstance(skill_data, dict):
            for _, skill_list in skill_data.items():
                if isinstance(skill_list, list):
                    for item in skill_list:
                        if isinstance(item, str):
                            cleaned = item.strip()
                            if cleaned:
                                skills.add(cleaned)
                        elif isinstance(item, dict):
                            skill_name = item.get("skill_name") or item.get("name") or item.get("skill")
                            if skill_name:
                                skills.add(str(skill_name).strip())

        # 2) experience descriptions
        experience = parsed_data.get("experience", [])
        if isinstance(experience, list):
            for job in experience:
                if isinstance(job, dict):
                    desc = str(job.get("description", "")).strip()
                    title = str(job.get("title", "")).strip()
                    combined = f"{title} {desc}".strip()
                    if combined:
                        skills.update(self._extract_tech_keywords(combined))

        # 3) projects
        projects = parsed_data.get("projects", [])
        if isinstance(projects, list):
            for project in projects:
                if isinstance(project, dict):
                    text = " ".join([
                        str(project.get("name", "")),
                        str(project.get("description", "")),
                        str(project.get("technologies", "")),
                    ]).strip()
                    if text:
                        skills.update(self._extract_tech_keywords(text))

        # 4) fallback: search inside raw parsed json text
        if not skills:
            raw_text = json.dumps(parsed_data, ensure_ascii=False)
            skills.update(self._extract_tech_keywords(raw_text))

        return skills

    # =====================================================
    # RAW TEXT EXTRACTION
    # =====================================================

    def _extract_from_text(self, cv_text: str) -> Set[str]:
        """
        Strong fallback directly from CV text.
        This is the key fix for your current issue.
        """
        if not cv_text:
            return set()

        found = set()
        text_lower = cv_text.lower()

        # direct keyword match
        found.update(self._extract_tech_keywords(text_lower))

        # special patterns
        pattern_map = {
            "python": [r"\bpython\b"],
            "sql": [r"\bsql\b"],
            "html": [r"\bhtml\b"],
            "css": [r"\bcss\b"],
            "javascript": [r"\bjavascript\b", r"\bjs\b"],
            "flask": [r"\bflask\b"],
            "django": [r"\bdjango\b"],
            "pandas": [r"\bpandas\b"],
            "numpy": [r"\bnumpy\b"],
            "matplotlib": [r"\bmatplotlib\b"],
            "seaborn": [r"\bseaborn\b"],
        }

        for skill_name, patterns in pattern_map.items():
            for pattern in patterns:
                if re.search(pattern, text_lower):
                    found.add(skill_name)
                    break

        return found

    # =====================================================
    # LLM EXTRACTION
    # =====================================================

    async def _extract_with_llm(self, cv_text: str) -> Dict[str, List[str]]:
        """
        Try LLM, but fail gracefully.
        """
        if not self.llm:
            return {"technical_skills": [], "certifications": []}

        try:
            response = await self.llm.get_response(
                prompt=SKILL_EXTRACTION_PROMPT.format(cv_text=cv_text[:4000]),
                need_json_output=True,
                schema=ExtractedSkills
            )

            if not response:
                logger.warning("LLM returned empty response for skill extraction")
                return {"technical_skills": [], "certifications": []}

            if isinstance(response, ExtractedSkills):
                return response.model_dump()

            if isinstance(response, dict):
                return {
                    "technical_skills": response.get("technical_skills", []),
                    "certifications": response.get("certifications", [])
                }

            logger.warning(f"Unexpected LLM response type for skill extraction: {type(response)}")
            return {"technical_skills": [], "certifications": []}

        except Exception as e:
            logger.warning(f"LLM skill extraction failed, using fallback only: {e}")
            return {"technical_skills": [], "certifications": []}

    # =====================================================
    # NORMALIZATION + VALIDATION
    # =====================================================

    def _extract_tech_keywords(self, text: str) -> Set[str]:
        found = set()
        text_lower = text.lower()

        for keyword in self.KNOWN_TECH_KEYWORDS:
            pattern = r"\b" + re.escape(keyword.lower()) + r"\b"
            if re.search(pattern, text_lower):
                found.add(keyword)

        return found

    def _normalize_skills(self, skills: Set[str]) -> Set[str]:
        normalized = set()

        for skill in skills:
            if not skill:
                continue

            skill_clean = str(skill).lower().strip()
            skill_clean = re.sub(r"\s+", " ", skill_clean)

            mapped = self.SKILL_NORMALIZATIONS.get(skill_clean, skill_clean)
            normalized.add(mapped)

        return normalized

    def _validate_technical_skills(self, skills: Set[str]) -> Set[str]:
        validated = set()

        for skill in skills:
            skill_lower = skill.lower()

            if skill_lower in self.KNOWN_TECH_KEYWORDS:
                validated.add(skill)
                continue

            if self._looks_like_tech_skill(skill_lower):
                validated.add(skill)

        return validated

    def _looks_like_tech_skill(self, skill: str) -> bool:
        if re.search(r"\d+\.\d+", skill):
            return True

        tech_suffixes = [
            "js", "py", "sql", "db", "web api", "css", "html",
            "framework", "library", "cloud", "server", "engine", "platform"
        ]
        if any(suffix in skill for suffix in tech_suffixes):
            return True

        tech_patterns = [
            "machine learning", "deep learning", "data science", "data analysis",
            "web development", "mobile development", "cloud computing",
            "database", "container", "backend", "frontend",
            "data wrangling", "data visualization", "statistical analysis"
        ]
        if any(pattern in skill for pattern in tech_patterns):
            return True

        return False

    def _calculate_extraction_confidence(self, validated_count: int, total_count: int) -> float:
        if total_count <= 0:
            return 0.0

        validation_rate = validated_count / total_count
        quantity_factor = min(validated_count / 10, 1.0)

        confidence = (validation_rate * 0.7) + (quantity_factor * 0.3)
        return round(min(confidence, 0.95), 3)