"""
Unified Time Calculation Service
Single source of truth for all time calculations across the app.

This service is used by:
- TimeGuidanceService (for /confirm-time-preview)
- AdvancedRealismChecker (for /confirm-time)
- Any other feature needing time estimates

Ensures consistent calculations across all endpoints.
"""

from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


# =====================================================
# LEVEL PROGRESSION MULTIPLIERS (Shared)
# =====================================================

LEVEL_PROGRESS_MULTIPLIER = {
    ("none", "beginner"): 0.4,
    ("none", "intermediate"): 1.0,
    ("none", "advanced"): 1.6,
    ("beginner", "intermediate"): 0.6,
    ("beginner", "advanced"): 1.2,
    ("intermediate", "advanced"): 0.7,
}

LEVEL_VALUES = {
    "none": 0,
    "beginner": 1,
    "intermediate": 2,
    "advanced": 3,
}


# =====================================================
# DATA MODELS
# =====================================================

@dataclass
class TimeCalculationScope:
    """
    Defines what skills and levels to include in calculations.
    Used to maintain consistency between different contexts.
    """
    name: str  # 'minimum', 'suitable', 'maximum', 'custom'
    include_selected: bool = True
    include_owned: bool = False
    selected_target_level: str = "beginner"
    owned_target_level: str = "beginner"


@dataclass
class SkillTimeEstimate:
    """Estimated time for a single skill"""
    skill_name: str
    skill_id: int
    current_level: str
    target_level: str
    baseline_required_weeks: int
    progression_multiplier: float
    importance_adjustment: float
    hours_adjustment: float
    calculated_weeks: int
    display_label: str


@dataclass
class TimeCalculationResult:
    """Complete time calculation for a scope"""
    scope_name: str
    total_weeks: int
    skill_details: List[SkillTimeEstimate]
    breakdown: Dict[str, int]


class UnifiedTimeCalculator:
    """
    Centralized time calculation engine.
    All time estimates go through this service to ensure consistency.

    AGREED METHODOLOGY:
    - minimum:
        selected skills only
        none -> beginner
        beginner -> intermediate
        intermediate+ -> skip
    - suitable:
        selected skills + current core skills
        target = intermediate
    - maximum:
        selected skills + current skills
        target = advanced
    """

    def calculate_all_ranges(
        self,
        selected_skills: List[Dict[str, Any]],
        current_core_skills: Optional[List[Dict[str, Any]]] = None,
        current_all_skills: Optional[List[Dict[str, Any]]] = None,
        available_hours_per_week: int = 6,
    ) -> Dict[str, TimeCalculationResult]:
        """
        Calculate minimum/suitable/maximum in one call.

        Args:
            selected_skills: Skills selected by user (missing/partial typically)
            current_core_skills: Current core skills user already has
            current_all_skills: All current skills user already has
            available_hours_per_week: User's study capacity
        """
        if not selected_skills:
            raise ValueError("At least one selected skill is required")

        current_core_skills = current_core_skills or []
        current_all_skills = current_all_skills or []

        minimum = self._calculate_minimum_range(
            selected_skills=selected_skills,
            available_hours_per_week=available_hours_per_week,
        )
        suitable = self._calculate_targeted_range(
            scope_name="suitable",
            selected_skills=selected_skills,
            owned_skills=current_core_skills,
            selected_target_level="intermediate",
            owned_target_level="intermediate",
            available_hours_per_week=available_hours_per_week,
        )
        maximum = self._calculate_targeted_range(
            scope_name="maximum",
            selected_skills=selected_skills,
            owned_skills=current_all_skills,
            selected_target_level="advanced",
            owned_target_level="advanced",
            available_hours_per_week=available_hours_per_week,
        )

        return {
            "minimum": minimum,
            "suitable": suitable,
            "maximum": maximum,
        }

    def _calculate_minimum_range(
        self,
        selected_skills: List[Dict[str, Any]],
        available_hours_per_week: int,
    ) -> TimeCalculationResult:
        """
        Minimum logic:
        - selected skills only
        - if current=none       => none -> beginner
        - if current=beginner   => beginner -> intermediate
        - if current>=intermediate => no extra minimum time needed
        """
        skill_details: List[SkillTimeEstimate] = []
        breakdown: Dict[str, int] = {}
        total_weeks = 0

        for skill in selected_skills:
            current_level = self._normalize_level(skill.get("detected_level") or skill.get("current_level") or "none")

            if current_level == "none":
                target_level = "beginner"
                display_context = "learn"
            elif current_level == "beginner":
                target_level = "intermediate"
                display_context = "level-up"
            else:
                continue

            estimate = self._estimate_skill_time(
                skill=skill,
                current_level=current_level,
                target_level=target_level,
                available_hours_per_week=available_hours_per_week,
                display_context=display_context,
            )
            skill_details.append(estimate)
            breakdown[estimate.display_label] = estimate.calculated_weeks
            total_weeks += estimate.calculated_weeks

        return TimeCalculationResult(
            scope_name="minimum",
            total_weeks=max(1, total_weeks),
            skill_details=skill_details,
            breakdown=breakdown,
        )

    def _calculate_targeted_range(
        self,
        scope_name: str,
        selected_skills: List[Dict[str, Any]],
        owned_skills: List[Dict[str, Any]],
        selected_target_level: str,
        owned_target_level: str,
        available_hours_per_week: int,
    ) -> TimeCalculationResult:
        """
        Generic calculator for suitable / maximum after the minimum special-case logic.
        """
        skill_details: List[SkillTimeEstimate] = []
        breakdown: Dict[str, int] = {}
        total_weeks = 0

        # Selected skills
        for skill in selected_skills:
            current_level = self._normalize_level(skill.get("detected_level") or skill.get("current_level") or "none")
            target_level = self._normalize_level(selected_target_level)

            if LEVEL_VALUES.get(current_level, 0) >= LEVEL_VALUES.get(target_level, 0):
                continue

            display_context = "learn" if current_level == "none" else "level-up"

            estimate = self._estimate_skill_time(
                skill=skill,
                current_level=current_level,
                target_level=target_level,
                available_hours_per_week=available_hours_per_week,
                display_context=display_context,
            )
            skill_details.append(estimate)
            breakdown[estimate.display_label] = estimate.calculated_weeks
            total_weeks += estimate.calculated_weeks

        # Current owned skills
        for skill in owned_skills:
            current_level = self._normalize_level(skill.get("detected_level") or skill.get("current_level") or "none")
            target_level = self._normalize_level(owned_target_level)

            if LEVEL_VALUES.get(current_level, 0) >= LEVEL_VALUES.get(target_level, 0):
                continue

            estimate = self._estimate_skill_time(
                skill=skill,
                current_level=current_level,
                target_level=target_level,
                available_hours_per_week=available_hours_per_week,
                display_context="level-up",
            )
            skill_details.append(estimate)
            breakdown[estimate.display_label] = estimate.calculated_weeks
            total_weeks += estimate.calculated_weeks

        return TimeCalculationResult(
            scope_name=scope_name,
            total_weeks=max(1, total_weeks),
            skill_details=skill_details,
            breakdown=breakdown,
        )

    def _estimate_skill_time(
        self,
        skill: Dict[str, Any],
        current_level: str,
        target_level: str,
        available_hours_per_week: int,
        display_context: str = "learn",
    ) -> SkillTimeEstimate:
        """
        Estimate time for a single skill progression.
        """
        skill_name = skill.get("skill_name", "unknown")
        skill_id = int(skill.get("skill_id", 0) or 0)
        baseline_required_weeks = int(
            skill.get("required_weeks")
            or skill.get("duration_weeks")
            or 4
        )
        importance_weight = int(skill.get("importance_weight", skill.get("importance", 3)) or 3)

        current_level = self._normalize_level(current_level)
        target_level = self._normalize_level(target_level)

        # Get adjustments first (need them for all cases)
        importance_adjustment = self._get_importance_adjustment(importance_weight)
        hours_adjustment = self._get_hours_adjustment(available_hours_per_week)

        if LEVEL_VALUES.get(current_level, 0) >= LEVEL_VALUES.get(target_level, 0):
            progression_multiplier = 0.0
            calculated_weeks = 0
        else:
            progression_multiplier = LEVEL_PROGRESS_MULTIPLIER.get(
                (current_level, target_level),
                1.0
            )
            calculated = baseline_required_weeks * progression_multiplier * importance_adjustment * hours_adjustment
            calculated_weeks = max(1, round(calculated))

        return SkillTimeEstimate(
            skill_name=skill_name,
            skill_id=skill_id,
            current_level=current_level,
            target_level=target_level,
            baseline_required_weeks=baseline_required_weeks,
            progression_multiplier=progression_multiplier,
            importance_adjustment=importance_adjustment,
            hours_adjustment=hours_adjustment,
            calculated_weeks=calculated_weeks,
            display_label=self._build_display_label(
                skill_name=skill_name,
                current_level=current_level,
                target_level=target_level,
                display_context=display_context,
            ),
        )

    def _build_display_label(
        self,
        skill_name: str,
        current_level: str,
        target_level: str,
        display_context: str,
    ) -> str:
        if display_context == "level-up":
            if target_level == "advanced":
                return f"{skill_name} (level-up to advanced)"
            if current_level == "beginner" and target_level == "intermediate":
                return f"{skill_name} (level-up)"
            return f"{skill_name} (level-up)"
        if current_level == "none" and target_level == "advanced":
            return f"{skill_name} (learn to advanced)"
        return f"{skill_name} (learn)"

    def _normalize_level(self, level: Optional[str], default: str = "none") -> str:
        normalized = (level or default).strip().lower()
        return normalized if normalized in LEVEL_VALUES else default

    def _get_importance_adjustment(self, importance_weight: int) -> float:
        """
        Keep impact mild and stable.
        """
        if importance_weight >= 5:
            return 1.15
        if importance_weight == 4:
            return 1.05
        if importance_weight == 2:
            return 0.95
        if importance_weight <= 1:
            return 0.9
        return 1.0

    def _get_hours_adjustment(self, available_hours_per_week: int) -> float:
        """
        Inverse relationship: fewer hours per week => more calendar weeks needed.
        Formula: baseline_hours (6) / available_hours_per_week
        
        Examples:
        - 3 hours/week:  6/3 = 2.0 (need 2x as long)
        - 6 hours/week:  6/6 = 1.0 (baseline)
        - 12 hours/week: 6/12 = 0.5 (half as long)
        - 20 hours/week: 6/20 = 0.3 (very quick)
        """
        baseline_hours = 6
        if available_hours_per_week <= 0:
            return 1.0
        multiplier = baseline_hours / available_hours_per_week
        # Cap extreme values
        return min(3.0, max(0.2, multiplier))

    def _classify_study_intensity(self, available_hours_per_week: int) -> str:
        if available_hours_per_week <= 5:
            return "light"
        if available_hours_per_week <= 10:
            return "moderate"
        return "intensive"