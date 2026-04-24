"""
Advanced Realism Checker
Validates if user's requested timeframe is realistic for their learning goals.

Uses UnifiedTimeCalculator for all calculations to ensure consistency
with TimeGuidanceService and other features.
"""

from dataclasses import dataclass
from typing import List, Dict, Any, Optional
import logging

from features.career_builder.services.unified_time_calculator import UnifiedTimeCalculator

logger = logging.getLogger(__name__)


@dataclass
class RealismCheckResult:
    is_realistic: bool
    adjustment: str
    zone: str

    requested_weeks: int
    available_hours_per_week: int
    study_intensity: str

    calculated_minimum_weeks: int
    calculated_suitable_weeks: int
    calculated_maximum_weeks: int

    warnings: List[str]
    suggestions: List[str]
    fit_percentage: float
    per_skill_analysis: Dict[str, Dict[str, Any]]


class AdvancedRealismChecker:
    """
    Realism checker using the SAME calculator and SAME methodology as preview.

    - minimum  => selected only
    - suitable => selected + current core
    - maximum  => selected + current all
    """

    def __init__(self):
        self.calculator = UnifiedTimeCalculator()

    def check_realism(
        self,
        requested_weeks: int,
        available_hours_per_week: int,
        selected_skills: List[Dict[str, Any]],
        current_core_skills: Optional[List[Dict[str, Any]]] = None,
        current_all_skills: Optional[List[Dict[str, Any]]] = None,
    ) -> RealismCheckResult:
        if requested_weeks <= 0:
            raise ValueError("requested_weeks must be > 0")
        if available_hours_per_week <= 0:
            raise ValueError("available_hours_per_week must be > 0")
        if not selected_skills:
            raise ValueError("selected_skills cannot be empty")

        current_core_skills = current_core_skills or []
        current_all_skills = current_all_skills or []

        study_intensity = self.calculator._classify_study_intensity(available_hours_per_week)

        time_ranges = self.calculator.calculate_all_ranges(
            selected_skills=selected_skills,
            current_core_skills=current_core_skills,
            current_all_skills=current_all_skills,
            available_hours_per_week=available_hours_per_week,
        )

        minimum_result = time_ranges["minimum"]
        suitable_result = time_ranges["suitable"]
        maximum_result = time_ranges["maximum"]

        calculated_minimum_weeks = minimum_result.total_weeks
        calculated_suitable_weeks = suitable_result.total_weeks
        calculated_maximum_weeks = maximum_result.total_weeks

        per_skill_analysis: Dict[str, Dict[str, Any]] = {}
        for result in (minimum_result, suitable_result, maximum_result):
            for detail in result.skill_details:
                key = f"{result.scope_name}:{detail.skill_id}"
                per_skill_analysis[key] = {
                    "scope": result.scope_name,
                    "skill_name": detail.skill_name,
                    "skill_id": detail.skill_id,
                    "current_level": detail.current_level,
                    "target_level": detail.target_level,
                    "base_required_weeks": detail.baseline_required_weeks,
                    "progression_multiplier": round(detail.progression_multiplier, 2),
                    "importance_adjustment": round(detail.importance_adjustment, 2),
                    "hours_adjustment": round(detail.hours_adjustment, 2),
                    "calculated_weeks_for_this_skill": detail.calculated_weeks,
                }

        warnings: List[str] = []
        suggestions: List[str] = []
        is_realistic = True
        adjustment = "ok"
        zone = "suitable"
        fit_percentage = 100.0

        if requested_weeks < calculated_minimum_weeks:
            is_realistic = False
            adjustment = "unrealistic_too_short"
            zone = "below_minimum"
            fit_percentage = (requested_weeks / calculated_minimum_weeks) * 100 if calculated_minimum_weeks else 0.0
            warnings.append(
                f"Your requested {requested_weeks} weeks is below the minimum required "
                f"{calculated_minimum_weeks} weeks."
            )
            suggestions.append(
                f"Increase to at least {calculated_minimum_weeks} weeks, or accept a lighter target scope."
            )

        elif requested_weeks < calculated_suitable_weeks:
            adjustment = "very_tight"
            zone = "minimum"
            fit_percentage = (requested_weeks / calculated_suitable_weeks) * 100 if calculated_suitable_weeks else 100.0
            warnings.append(
                f"🟡 Tight Timeline\nYour {requested_weeks} weeks is possible, but it may feel intensive."
            )
            suggestions.append(
                "💡 You can continue, but the plan may focus on essentials first. Consider the selected skills as priority."
            )

        elif requested_weeks <= calculated_maximum_weeks:
            adjustment = "ok"
            zone = "suitable"
            fit_percentage = 100.0
            suggestions.append(
                "🟢 Good Time Range\nYour selected duration of {requested_weeks} weeks looks reasonable and should support a balanced study plan."
            )

        else:
            adjustment = "excessive"
            zone = "above_maximum"
            fit_percentage = min(
                100.0,
                (calculated_maximum_weeks / requested_weeks) * 100 if requested_weeks else 100.0
            )
            suggestions.append(
                f"🔵 Flexible Timeline\nYou've selected {requested_weeks} weeks (more than the {calculated_maximum_weeks} weeks guidance). This gives more room for deeper learning and practice."
            )

        if available_hours_per_week <= 5:
            warnings.append(
                f"⚠️ Limited Weekly Time\nYour {available_hours_per_week} hours/week study time is quite limited. Make sure your sessions are focused and consistent to make progress."
            )
        elif available_hours_per_week >= 20:
            suggestions.append(
                f"💪 Strong Weekly Availability\nWith {available_hours_per_week} hours/week, you have enough time for steady progress and deeper learning. This can support faster growth."
            )

        return RealismCheckResult(
            is_realistic=is_realistic,
            adjustment=adjustment,
            zone=zone,
            requested_weeks=requested_weeks,
            available_hours_per_week=available_hours_per_week,
            study_intensity=study_intensity,
            calculated_minimum_weeks=calculated_minimum_weeks,
            calculated_suitable_weeks=calculated_suitable_weeks,
            calculated_maximum_weeks=calculated_maximum_weeks,
            warnings=warnings,
            suggestions=suggestions,
            fit_percentage=round(fit_percentage, 1),
            per_skill_analysis=per_skill_analysis,
        )