"""
Backend 1 - Analysis Service ✅
"""
from typing import Dict, List, Any, Optional
from uuid import UUID
from dataclasses import dataclass
import logging
import json

from features.career_builder.ml_models.skill_matcher import HybridCareerAnalyzer
from features.career_builder.ml_models.level_detector import LevelDetector
from features.career_builder.ml_models.realism_checker import RealismChecker, RealismResult
from features.career_builder.repositories.career_repository import CareerRepository

logger = logging.getLogger(__name__)


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

    requested_weeks: int
    safe_min_weeks: int
    recommended_weeks: int
    is_below_safe: bool
    realism_warning: str

    analysis_quality: float


class CareerAnalysisService:

    def __init__(self, repository: CareerRepository):
        self.repo            = repository
        # ✅ بنبعت نفس الـ repository للـ HybridCareerAnalyzer
        self.hybrid_analyzer = HybridCareerAnalyzer(repository=repository)
        self.level_detector  = LevelDetector()
        self.realism_checker = RealismChecker()

    async def analyze_cv_for_track(
        self,
        cv_id: UUID,
        track_id: int,
        requested_weeks: int,
        user_level: Optional[str] = None
    ) -> AnalysisResult:

        # ─── Step 1: CV + Track ───────────────────────────
        cv_data = await self.repo.get_cv_by_id(cv_id)
        if not cv_data:
            raise ValueError(f"CV not found: {cv_id}")

        track_data = await self.repo.get_track_by_id(track_id)
        if not track_data:
            raise ValueError(f"Track not found: {track_id}")

        cv_text        = cv_data.get('text_content', '')
        parsed_content = cv_data.get('parsed_content', {})
        if isinstance(parsed_content, str):
            try:
                parsed_content = json.loads(parsed_content)
            except Exception:
                parsed_content = {}

        # ─── Phase 1+2: Extraction + Matching ────────────
        logger.info("📋 PHASE 1+2: Skill extraction & matching...")
        analysis = await self.hybrid_analyzer.analyze(
            cv_id=cv_id,
            track_id=track_id
        )
        logger.info(
            f"✅ {len(analysis.matched_skills)} matched, "
            f"{len(analysis.missing_skills)} missing "
            f"via {analysis.matching_method}"
        )

        # ─── Phase 3: Level Detection ─────────────────────
        logger.info("🎓 PHASE 3: Detecting level...")
        if user_level and user_level in ('beginner', 'intermediate', 'advanced'):
            detected_level   = user_level
            level_confidence = 1.0
            level_reasoning  = "User-selected level"
        else:
            level_result = await self.level_detector.detect_skill_levels(
                cv_text=cv_text,
                parsed_cv_data=parsed_content,
                required_skills=[s['skill_name'] for s in analysis.matched_skills]
            )
            detected_level   = level_result.get('overall_level', 'beginner')
            level_confidence = level_result.get('overall_confidence', 0.5)
            level_reasoning  = level_result.get('summary', '')

        logger.info(f"✅ Level: {detected_level} ({level_confidence:.0%})")

        # ─── Phase 4: Realism ─────────────────────────────
        if requested_weeks > 0:
            logger.info("⏱️ PHASE 4: Checking time realism...")
            realism = self.realism_checker.check_realism(
                requested_weeks=requested_weeks,
                missing_skills=analysis.missing_skills,
                level=detected_level
            )
            if realism.is_below_safe:
                logger.warning(f"⚠️ {realism.warning}")
        else:
            logger.info("⏱️ PHASE 4: Skipped (pending /confirm)")
            realism = RealismResult(
                requested_weeks=0,
                safe_min_weeks=0,
                recommended_weeks=0,
                is_below_safe=False,
                adjustment='pending',
                warning=""
            )

        # ─── Quality ──────────────────────────────────────
        analysis_quality = self._calc_quality(
            match_percentage=analysis.match_percentage,
            level_confidence=level_confidence,
            method=analysis.matching_method
        )
        logger.info(f"✅ Done (quality: {analysis_quality:.0%})")

        return AnalysisResult(
            cv_id=cv_id,
            track_id=track_id,
            track_name=track_data['track_name'],
            cv_skills=analysis.cv_skills,
            matched_skills=analysis.matched_skills,
            missing_skills=analysis.missing_skills,
            match_percentage=analysis.match_percentage,
            matching_method=analysis.matching_method,
            detected_level=detected_level,
            level_confidence=level_confidence,
            level_reasoning=level_reasoning,
            requested_weeks=requested_weeks,
            safe_min_weeks=realism.safe_min_weeks,
            recommended_weeks=realism.recommended_weeks,
            is_below_safe=realism.is_below_safe,
            realism_warning=realism.warning,
            analysis_quality=analysis_quality
        )

    def _calc_quality(
        self,
        match_percentage: float,
        level_confidence: float,
        method: str
    ) -> float:
        method_score = 1.0 if method == 'llm' else 0.75
        quality = (
            (match_percentage / 100) * 0.4 +
            level_confidence          * 0.4 +
            method_score              * 0.2
        )
        return round(min(quality, 0.95), 3)

    def to_output_contract(self, result: AnalysisResult) -> Dict[str, Any]:
        return {
            "detected_level":   result.detected_level,
            "level_confidence": round(result.level_confidence, 3),
            "match_percentage": result.match_percentage,
            "matching_method":  result.matching_method,
            "realism": {
                "requested_weeks":   result.requested_weeks,
                "safe_min_weeks":    result.safe_min_weeks,
                "recommended_weeks": result.recommended_weeks,
                "is_below_safe":     result.is_below_safe,
                "adjustment":        result.realism_warning,
                "warning":           result.realism_warning,
            },
            "matched_skills": result.matched_skills,
            "missing_skills": result.missing_skills,
            "metadata": {
                "cv_skills_count":  len(result.cv_skills),
                "analysis_quality": result.analysis_quality,
                "level_reasoning":  result.level_reasoning,
            }
        }