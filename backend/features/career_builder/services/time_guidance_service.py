"""
Time Guidance Service
Calculates min/suitable/max weeks based on dynamic skill progressions.

NOW UNIFIED: Uses UnifiedTimeCalculator as single source of truth for all
time calculations across the app.
"""

from typing import Dict, List, Any
from uuid import UUID
from dataclasses import dataclass, asdict
import logging

from features.career_builder.repositories.career_repository import CareerRepository
from features.career_builder.services.unified_time_calculator import UnifiedTimeCalculator

logger = logging.getLogger(__name__)

LEVEL_VALUES = {
    "none": 0,
    "beginner": 1,
    "intermediate": 2,
    "advanced": 3,
}


@dataclass
class TimeGuidance:
    """Time guidance for learning plan"""
    minimum_weeks: int
    suitable_weeks: int
    maximum_weeks: int
    study_intensity: str
    minimum_weeks_breakdown: Dict[str, int]
    suitable_weeks_breakdown: Dict[str, int]
    maximum_weeks_breakdown: Dict[str, int]


class TimeGuidanceService:
    """
    Calculate realistic time guidance for a learning plan.

    AGREED METHODOLOGY:
    - minimum  => selected skills only
    - suitable => selected skills + current core skills
    - maximum  => selected skills + current skills
    """

    def __init__(self, repository: CareerRepository):
        self.repo = repository
        self.calculator = UnifiedTimeCalculator()

    async def get_time_guidance(
        self,
        cv_id: UUID,
        track_id: int,
        selected_skill_ids: List[int],
        detected_skill_levels: Dict[str, str],
        available_hours_per_week: int,
    ) -> TimeGuidance:
        track = await self.repo.get_track_by_id(track_id)
        if not track:
            raise ValueError(f"Track {track_id} not found")

        all_track_skills = await self.repo.get_skills_by_track(track_id)
        if not all_track_skills:
            raise ValueError(f"No skills found for track {track_id}")

        selected_skills, current_core_skills, current_all_skills = self._build_time_skill_buckets(
            all_track_skills=all_track_skills,
            selected_skill_ids=selected_skill_ids,
            detected_skill_levels=detected_skill_levels,
        )

        if not selected_skills:
            raise ValueError("No valid selected skills")

        time_ranges = self.calculator.calculate_all_ranges(
            selected_skills=selected_skills,
            current_core_skills=current_core_skills,
            current_all_skills=current_all_skills,
            available_hours_per_week=available_hours_per_week,
        )

        minimum_result = time_ranges["minimum"]
        suitable_result = time_ranges["suitable"]
        maximum_result = time_ranges["maximum"]

        return TimeGuidance(
            minimum_weeks=minimum_result.total_weeks,
            suitable_weeks=suitable_result.total_weeks,
            maximum_weeks=maximum_result.total_weeks,
            study_intensity=self.calculator._classify_study_intensity(available_hours_per_week),
            minimum_weeks_breakdown=minimum_result.breakdown,
            suitable_weeks_breakdown=suitable_result.breakdown,
            maximum_weeks_breakdown=maximum_result.breakdown,
        )

    def _build_time_skill_buckets(
        self,
        all_track_skills: List[Dict[str, Any]],
        selected_skill_ids: List[int],
        detected_skill_levels: Dict[str, str],
    ) -> tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]]]:
        normalized_detected = self._normalize_detected_levels(detected_skill_levels)
        selected_ids_set = set(selected_skill_ids or [])

        selected_skills: List[Dict[str, Any]] = []
        current_core_skills: List[Dict[str, Any]] = []
        current_all_skills: List[Dict[str, Any]] = []

        for skill in all_track_skills:
            skill_name = skill.get("skill_name", "")
            normalized_skill_name = self._normalize_skill_name(skill_name)
            detected_level = normalized_detected.get(normalized_skill_name, "none")
            current_value = LEVEL_VALUES.get(detected_level, 0)

            enriched_skill = {
                **skill,
                "detected_level": detected_level,
                "current_level": detected_level,
            }

            if skill.get("skill_id") in selected_ids_set:
                selected_skills.append(enriched_skill)

            if current_value >= 1:
                current_all_skills.append(enriched_skill)
                if bool(skill.get("is_core", True)):
                    current_core_skills.append(enriched_skill)

        return selected_skills, current_core_skills, current_all_skills

    def _normalize_skill_name(self, skill_name: str) -> str:
        return " ".join((skill_name or "").strip().lower().split())

    def _normalize_detected_levels(self, detected_levels: Dict[str, str]) -> Dict[str, str]:
        normalized: Dict[str, str] = {}
        for skill_name, level in (detected_levels or {}).items():
            key = self._normalize_skill_name(skill_name)
            if key:
                normalized[key] = (level or "none").strip().lower()
        return normalized

    def to_dict(self, guidance: TimeGuidance) -> Dict[str, Any]:
        return asdict(guidance)