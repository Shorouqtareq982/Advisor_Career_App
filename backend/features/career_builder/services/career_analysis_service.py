"""
Backend 1 - Analysis Service (Enhanced Version)
"""

from typing import Dict, List, Any, Optional
from uuid import UUID
from dataclasses import dataclass
import logging
import json

from features.career_builder.ml_models.skill_matcher import HybridCareerAnalyzer
from features.career_builder.ml_models.level_detector import LevelDetector
from features.career_builder.ml_models.realism_checker import RealismChecker, RealismResult
from features.career_builder.ml_models.gap_analyzer import SkillGapAnalyzer
from features.career_builder.services.fit_evaluator import FitEvaluator
from features.career_builder.repositories.career_repository import CareerRepository

logger = logging.getLogger(__name__)


# =====================================================
# RESULT MODEL
# =====================================================

@dataclass
class AnalysisResult:
    cv_id: UUID
    track_id: int
    track_name: str

    cv_skills: List[str]
    matched_skills: List[Dict]
    missing_skills: List[Dict]
    match_percentage: float
    matching_method: str

    detected_level: str
    level_confidence: float
    level_reasoning: str

    detected_skill_levels: Dict[str, str]
    required_level: str
    skill_gaps: List[Dict]
    fit_analysis: Dict[str, Any]
    reviewable_skills: List[Dict]

    requested_weeks: int
    safe_min_weeks: int
    recommended_weeks: int
    is_below_safe: bool
    realism_warning: str

    analysis_quality: float


# =====================================================
# SERVICE
# =====================================================

class CareerAnalysisService:

    def __init__(self, repository: CareerRepository):
        self.repo = repository
        self.hybrid_analyzer = HybridCareerAnalyzer(repository=repository)
        self.level_detector = LevelDetector()
        self.realism_checker = RealismChecker()
        self.gap_analyzer = SkillGapAnalyzer()
        self.fit_evaluator = FitEvaluator()

    async def analyze_cv_for_track(
        self,
        cv_id: UUID,
        track_id: int,
        requested_weeks: int,
        user_level: Optional[str] = None
    ) -> AnalysisResult:

        # =====================================================
        # Step 1: Load CV + Track
        # =====================================================
        cv_data = await self.repo.get_cv_by_id(cv_id)
        if not cv_data:
            raise ValueError(f"CV not found: {cv_id}")

        track_data = await self.repo.get_track_by_id(track_id)
        if not track_data:
            raise ValueError(f"Track not found: {track_id}")

        cv_text = cv_data.get("text_content", "")
        parsed_content = cv_data.get("parsed_content", {})

        if isinstance(parsed_content, str):
            try:
                parsed_content = json.loads(parsed_content)
            except Exception:
                parsed_content = {}

        # =====================================================
        # Step 2: Extraction + Matching
        # =====================================================
        logger.info("PHASE 1+2: Skill extraction & matching...")

        analysis = await self.hybrid_analyzer.analyze(
            cv_id=cv_id,
            track_id=track_id
        )

        logger.info(
            f"Matched={len(analysis.matched_skills)}, "
            f"Missing={len(analysis.missing_skills)}, "
            f"Method={analysis.matching_method}"
        )

        # =====================================================
        # Step 3: Load all track skills
        # =====================================================
        track_skills = await self.repo.get_skills_by_track(
            track_id,
            level=user_level or "beginner"
        )

        required_skill_names = [skill["skill_name"] for skill in track_skills]

        # =====================================================
        # Step 4: Level Detection
        # =====================================================
        logger.info("PHASE 4: Detecting levels per skill...")

        if user_level and user_level in ("beginner", "intermediate", "advanced"):
            detected_level = user_level
            level_confidence = 1.0
            level_reasoning = "User-selected level"

            level_result = {
                "skill_levels": [
                    {
                        "skill": skill_name,
                        "level": user_level,
                        "confidence": 1.0
                    }
                    for skill_name in required_skill_names
                ],
                "overall_level": user_level,
                "overall_confidence": 1.0,
                "summary": "User-selected level"
            }

        else:
            level_result = await self.level_detector.detect_skill_levels(
                cv_text=cv_text,
                parsed_cv_data=parsed_content,
                required_skills=required_skill_names
            )

            detected_level = level_result.get("overall_level", "beginner")
            level_confidence = level_result.get("overall_confidence", 0.5)
            level_reasoning = level_result.get("summary", "")

        logger.info(f"Detected overall level: {detected_level} ({level_confidence:.0%})")

        # =====================================================
        # Step 4.5: Build reliable detected skill levels
        # IMPORTANT:
        # - unmatched skills must stay "none"
        # - matched skills with very low confidence become "beginner"
        #   for GAP CALCULATION only
        # - medium confidence matched skills can still be treated as beginner
        #   for user-friendly logic
        # =====================================================
        detected_levels = self._build_detected_levels(
            required_skill_names=required_skill_names,
            matched_skills=analysis.matched_skills,
            level_result=level_result,
            forced_level=user_level if user_level in ("beginner", "intermediate", "advanced") else None
        )

        # =====================================================
        # Step 5: Gap Analysis
        # =====================================================
        required_level = detected_level

        skill_gaps = self.gap_analyzer.analyze_gaps(
            track_skills=track_skills,
            detected_levels=detected_levels,
            required_level=required_level
        )

        # =====================================================
        # Step 6: Fit Evaluation
        # =====================================================
        fit_analysis = self.fit_evaluator.evaluate(
            match_percentage=analysis.match_percentage,
            skill_gaps=skill_gaps
        )

        # =====================================================
        # Step 7: Reviewable Skills for UI
        # =====================================================
        reviewable_skills = self._build_reviewable_skills(
            skill_gaps=skill_gaps,
            level_result=level_result
        )

        # =====================================================
        # Step 8: Realism
        # =====================================================
        if requested_weeks > 0:
            logger.info("PHASE 8: Checking time realism...")

            missing_for_realism = [
                gap for gap in skill_gaps
                if gap["status"] in ("missing", "partial")
            ]

            realism = self.realism_checker.check_realism(
                requested_weeks=requested_weeks,
                missing_skills=missing_for_realism,
                level=required_level
            )

            if realism.is_below_safe:
                logger.warning(f"Realism warning: {realism.warning}")

        else:
            realism = RealismResult(
                requested_weeks=0,
                safe_min_weeks=0,
                recommended_weeks=0,
                is_below_safe=False,
                adjustment="pending",
                warning=""
            )

        # =====================================================
        # Step 9: Quality score
        # =====================================================
        analysis_quality = self._calc_quality(
            match_percentage=analysis.match_percentage,
            level_confidence=level_confidence,
            method=analysis.matching_method
        )

        logger.info(f"Analysis completed (quality={analysis_quality:.0%})")

        return AnalysisResult(
            cv_id=cv_id,
            track_id=track_id,
            track_name=track_data["track_name"],

            cv_skills=analysis.cv_skills,
            matched_skills=analysis.matched_skills,
            missing_skills=analysis.missing_skills,
            match_percentage=analysis.match_percentage,
            matching_method=analysis.matching_method,

            detected_level=detected_level,
            level_confidence=level_confidence,
            level_reasoning=level_reasoning,

            detected_skill_levels=detected_levels,
            required_level=required_level,
            skill_gaps=skill_gaps,
            fit_analysis=fit_analysis,
            reviewable_skills=reviewable_skills,

            requested_weeks=requested_weeks,
            safe_min_weeks=realism.safe_min_weeks,
            recommended_weeks=realism.recommended_weeks,
            is_below_safe=realism.is_below_safe,
            realism_warning=realism.warning,

            analysis_quality=analysis_quality
        )

    # =====================================================
    # BUILD RELIABLE DETECTED LEVELS
    # =====================================================

    def _build_detected_levels(
        self,
        required_skill_names: List[str],
        matched_skills: List[Dict[str, Any]],
        level_result: Dict[str, Any],
        forced_level: Optional[str] = None
    ) -> Dict[str, str]:
        """
        Build skill levels safely.

        Rules:
        - default every required skill to "none"
        - if user explicitly selected a level, matched skills get that level
        - if a skill was NOT matched, it must remain "none"
        - if confidence < 0.35 and skill is matched:
            use "beginner" for GAP CALCULATION
        - if confidence >= 0.35:
            trust the raw level more
        """

        matched_skill_names = {
            self._normalize_skill_name(item.get("skill_name", ""))
            for item in (matched_skills or [])
            if item.get("skill_name")
        }

        detected_levels = {
            skill_name: "none"
            for skill_name in required_skill_names
        }

        # user forced level: only matched skills get it
        if forced_level:
            for skill_name in required_skill_names:
                if self._normalize_skill_name(skill_name) in matched_skill_names:
                    detected_levels[skill_name] = forced_level
            return detected_levels

        skill_levels_list = level_result.get("skill_levels") or level_result.get("skills") or []

        for item in skill_levels_list:
            skill_name = item.get("skill") or item.get("skill_name")
            raw_level = item.get("level") or item.get("detected_level") or "none"
            confidence = item.get("confidence", 0.0)

            if not skill_name:
                continue

            normalized_skill_name = self._normalize_skill_name(skill_name)

            # unmatched skills must stay none
            if normalized_skill_name not in matched_skill_names:
                continue

            canonical_name = self._find_canonical_skill_name(skill_name, required_skill_names)
            if not canonical_name:
                continue

            # very low confidence => keep as beginner for logic only
            if confidence < 0.35:
                detected_levels[canonical_name] = "beginner"
                continue

            normalized_level = str(raw_level).lower().strip()
            if normalized_level not in ("none", "beginner", "intermediate", "advanced"):
                normalized_level = "beginner"

            detected_levels[canonical_name] = normalized_level

        return detected_levels

    def _find_canonical_skill_name(
        self,
        candidate_name: str,
        required_skill_names: List[str]
    ) -> Optional[str]:
        normalized_candidate = self._normalize_skill_name(candidate_name)
        for skill_name in required_skill_names:
            if self._normalize_skill_name(skill_name) == normalized_candidate:
                return skill_name
        return None

    def _normalize_skill_name(self, skill_name: str) -> str:
        return " ".join((skill_name or "").strip().lower().split())

    # =====================================================
    # BUILD REVIEWABLE SKILLS
    # =====================================================

    def _build_reviewable_skills(
        self,
        skill_gaps: List[Dict[str, Any]],
        level_result: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        Build UI-friendly reviewable skills.

        Rules:
        - confidence >= 0.5  => trust detected level directly
        - 0.35 <= confidence < 0.5 => accept as beginner-ish signal, no manual input
        - confidence < 0.35 => detected_level = None, user must choose
        """

        skill_levels_map = {}

        for item in level_result.get("skill_levels", []):
            skill_name = item.get("skill") or item.get("skill_name")
            if not skill_name:
                continue

            confidence = item.get("confidence", 0.0)
            raw_level = item.get("level") or item.get("detected_level")

            if confidence >= 0.5:
                detected_level = raw_level or "beginner"
                needs_user_input = False
            elif confidence >= 0.35:
                detected_level = raw_level or "beginner"
                needs_user_input = False
            else:
                detected_level = None
                needs_user_input = True

            if detected_level is not None:
                detected_level = str(detected_level).lower().strip()
                if detected_level not in ("none", "beginner", "intermediate", "advanced"):
                    detected_level = "beginner"

            skill_levels_map[self._normalize_skill_name(skill_name)] = {
                "detected_level": detected_level,
                "confidence": confidence,
                "needs_user_input": needs_user_input
            }

        reviewable_skills = []

        for gap in skill_gaps:
            skill_name = gap.get("skill_name", "")
            info = skill_levels_map.get(self._normalize_skill_name(skill_name))

            if info:
                detected_level = info["detected_level"]
                confidence = info["confidence"]
                needs_user_input = info["needs_user_input"]
            else:
                # fallback for matched beginner-like logic
                if gap.get("status") == "has" and gap.get("current_level") in ("beginner", "intermediate", "advanced"):
                    detected_level = gap.get("current_level")
                    confidence = 0.35
                    needs_user_input = False
                else:
                    detected_level = None
                    confidence = 0.0
                    needs_user_input = True

            selected_by_default = gap.get("status") in ("missing", "partial")

            reviewable_skills.append({
                "skill_id": gap.get("skill_id"),
                "skill_name": skill_name,
                "status": gap.get("status"),
                "detected_level": detected_level,
                "confidence": round(confidence, 3),
                "needs_user_input": needs_user_input,
                "required_level": gap.get("required_level"),
                "selected_by_default": selected_by_default
            })

        return reviewable_skills

    # =====================================================
    # QUALITY SCORE
    # =====================================================

    def _calc_quality(
        self,
        match_percentage: float,
        level_confidence: float,
        method: str
    ) -> float:
        method_score = 1.0 if method == "llm" else 0.75

        quality = (
            (match_percentage / 100) * 0.4 +
            level_confidence * 0.4 +
            method_score * 0.2
        )

        return round(min(quality, 0.95), 3)

    # =====================================================
    # OUTPUT CONTRACT
    # =====================================================

    def to_output_contract(self, result: AnalysisResult) -> Dict[str, Any]:
        return {
            "detected_level": result.detected_level,
            "required_level": result.required_level,
            "level_confidence": round(result.level_confidence, 3),

            "match_percentage": result.match_percentage,
            "matching_method": result.matching_method,

            "fit_analysis": result.fit_analysis,

            "skill_gaps": result.skill_gaps,
            "reviewable_skills": result.reviewable_skills,
            "detected_skill_levels": result.detected_skill_levels,

            "realism": {
                "requested_weeks": result.requested_weeks,
                "safe_min_weeks": result.safe_min_weeks,
                "recommended_weeks": result.recommended_weeks,
                "is_below_safe": result.is_below_safe,
                "warning": result.realism_warning,
            },

            "matched_skills": result.matched_skills,
            "missing_skills": result.missing_skills,

            "metadata": {
                "cv_skills_count": len(result.cv_skills),
                "analysis_quality": result.analysis_quality,
                "level_reasoning": result.level_reasoning,
            }
        }