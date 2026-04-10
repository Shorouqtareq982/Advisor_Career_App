"""
Skill Gap Analyzer
Calculates real skill gaps between detected current level and required level
"""

from typing import Dict, List, Any


class SkillGapAnalyzer:
    """Analyzes skill gaps between current and required levels"""

    LEVEL_VALUES = {
        "none": 0,
        "beginner": 1,
        "intermediate": 2,
        "advanced": 3,
    }

    def _normalize_skill_name(self, skill_name: str) -> str:
        """Normalize skill names for reliable matching"""
        return " ".join((skill_name or "").strip().lower().split())

    def _normalize_level(self, level: str, default: str = "none") -> str:
        """Normalize level string and fallback safely"""
        normalized = (level or default).strip().lower()
        return normalized if normalized in self.LEVEL_VALUES else default

    def calculate_gap_score(
        self,
        current_level: str,
        required_level: str
    ) -> float:
        """
        Calculate normalized gap score between current and required level.

        Returns:
            0.0 => no gap
            1.0 => maximum gap
        """
        current_level = self._normalize_level(current_level, "none")
        required_level = self._normalize_level(required_level, "beginner")

        current = self.LEVEL_VALUES[current_level]
        required = self.LEVEL_VALUES[required_level]

        if current >= required:
            return 0.0

        gap = required - current
        max_gap = required

        return gap / max_gap if max_gap > 0 else 1.0

    def analyze_gaps(
        self,
        track_skills: List[Dict[str, Any]],
        detected_levels: Dict[str, str],
        required_level: str
    ) -> List[Dict[str, Any]]:
        """
        Analyze skill gaps for all required track skills.

        Args:
            track_skills:
                Full track skills from repository, including:
                skill_id, skill_name, importance/is_core/duration_weeks
            detected_levels:
                Dict like {"Python": "intermediate", "SQL": "beginner"}
            required_level:
                Target level for this learning plan

        Returns:
            Sorted list of gap dictionaries
        """
        gaps = []

        required_level = self._normalize_level(required_level, "beginner")

        # normalize detected levels map once
        normalized_detected_levels = {
            self._normalize_skill_name(skill_name): self._normalize_level(level, "none")
            for skill_name, level in (detected_levels or {}).items()
        }

        for track_skill in track_skills:
            skill_name = track_skill.get("skill_name", "")
            normalized_skill_name = self._normalize_skill_name(skill_name)

            current_level = normalized_detected_levels.get(normalized_skill_name, "none")

            current_value = self.LEVEL_VALUES.get(current_level, 0)
            required_value = self.LEVEL_VALUES.get(required_level, 1)

            if current_value == 0:
                status = "missing"
            elif current_value < required_value:
                status = "partial"
            else:
                status = "has"

            gap_score = self.calculate_gap_score(current_level, required_level)

            gaps.append({
                "skill_id": track_skill.get("skill_id"),
                "skill_name": skill_name,
                "status": status,
                "current_level": current_level,
                "required_level": required_level,
                "gap_score": round(gap_score, 3),
                "importance_weight": track_skill.get(
                    "importance_weight",
                    track_skill.get("importance", 3)
                ),
                "required_weeks": track_skill.get("duration_weeks", 4),
                "is_core": track_skill.get("is_core", True),
            })

        # higher gap first, then higher importance first
        gaps.sort(
            key=lambda x: (x["gap_score"], x["importance_weight"]),
            reverse=True
        )

        return gaps