"""
Time Realism Checker ✅
"""
from dataclasses import dataclass
from typing import List, Dict, Any


@dataclass
class RealismResult:
    requested_weeks: int
    safe_min_weeks: int
    recommended_weeks: int
    is_below_safe: bool
    adjustment: str        # 'ok' | 'too_short' | 'too_long'
    warning: str           # empty if no issue


LEVEL_MULTIPLIER = {
    'beginner':     1.3,
    'intermediate': 1.0,
    'advanced':     0.75,
}

MAX_WEEKS_MULTIPLIER = 2.5


class RealismChecker:

    def check_realism(
        self,
        requested_weeks: int,
        missing_skills: List[Dict],
        level: str
    ) -> RealismResult:
        """
        Calculates safe minimum and recommended duration from missing skills.
        The user is free to choose — but if they go below the safe minimum,
        we show a warning.

        Examples:
            >>> missing = [{"duration_weeks": 4}, {"duration_weeks": 6}, {"duration_weeks": 3}]
            >>> checker.check_realism(8, missing, 'beginner')
            # min=13, safe_min=17 (13*1.3), is_below_safe=True

            >>> checker.check_realism(20, missing, 'beginner')
            # min=13, safe_min=17, is_below_safe=False
        """
        min_weeks         = self._calc_min_weeks(missing_skills)
        multiplier        = LEVEL_MULTIPLIER.get(level, 1.0)
        safe_min_weeks    = max(1, round(min_weeks * multiplier))
        recommended_weeks = safe_min_weeks
        max_weeks         = round(min_weeks * MAX_WEEKS_MULTIPLIER)

        if requested_weeks < safe_min_weeks:
            return RealismResult(
                requested_weeks=requested_weeks,
                safe_min_weeks=safe_min_weeks,
                recommended_weeks=recommended_weeks,
                is_below_safe=True,
                adjustment='too_short',
                warning=(
                    f"The chosen duration ({requested_weeks} weeks) is below the safe minimum "
                    f"({safe_min_weeks} weeks for {level} level). "
                    f"It might be difficult to cover all required skills."
                )
            )

        if requested_weeks > max_weeks:
            return RealismResult(
                requested_weeks=requested_weeks,
                safe_min_weeks=safe_min_weeks,
                recommended_weeks=recommended_weeks,
                is_below_safe=False,
                adjustment='too_long',
                warning=(
                    f"The chosen duration ({requested_weeks} weeks) exceeds the reasonable maximum "
                    f"({max_weeks} weeks)."
                )
            )

        return RealismResult(
            requested_weeks=requested_weeks,
            safe_min_weeks=safe_min_weeks,
            recommended_weeks=recommended_weeks,
            is_below_safe=False,
            adjustment='ok',
            warning=""
        )

    def _calc_min_weeks(self, missing_skills: List[Dict]) -> int:
        if not missing_skills:
            return 0
        return sum(
            skill.get('duration_weeks', 4)
            for skill in missing_skills
        )