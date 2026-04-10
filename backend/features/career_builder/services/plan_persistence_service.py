import logging
from typing import Dict, Any, List
from uuid import UUID

from features.career_builder.repositories.career_repository import CareerRepository

logger = logging.getLogger(__name__)


class PlanPersistenceService:
    """
    Saves generated career plans into:
    1) career_plan_info
    2) career_plan_content
    3) career_user_skills

    Updated to support the newer planning structure:
    - available_hours_per_week
    - planning_mode
    - study_intensity
    - modern weekly breakdown
    """

    def __init__(self, repository: CareerRepository):
        self.repo = repository

    async def save_plan(
        self,
        user_id: UUID,
        cv_id: UUID,
        track_id: int,
        detected_level: str,
        confirmed_level: str,
        duration_weeks: int,
        plan_data: Dict[str, Any],
        skill_gaps: List[Dict[str, Any]],
        realism_flag: bool = False,
        suggested_min_weeks: int = None
    ) -> Dict[str, Any]:
        """
        Saves the full plan and its related skill snapshot.
        """

        if not plan_data:
            raise ValueError("plan_data is required")

        weekly_breakdown = plan_data.get("weekly_breakdown", [])
        if not isinstance(weekly_breakdown, list) or not weekly_breakdown:
            raise ValueError("plan_data must contain weekly_breakdown")

        # =====================================================
        # 1) Create main plan record
        # =====================================================
        plan_id = await self.repo.create_plan(
            user_id=user_id,
            cv_id=cv_id,
            track_id=track_id,
            detected_level=detected_level,
            confirmed_level=confirmed_level,
            duration_weeks=duration_weeks,
            realism_flag=realism_flag,
            suggested_min_weeks=suggested_min_weeks
        )

        if not plan_id:
            raise ValueError("Failed to create plan record")

        # =====================================================
        # 2) Build skill lookup from analysis gaps
        # =====================================================
        skill_lookup = {}
        for gap in skill_gaps:
            skill_name = (gap.get("skill_name") or "").strip().lower()
            if skill_name:
                skill_lookup[skill_name] = gap

        # =====================================================
        # 3) Save weekly content
        # =====================================================
        weekly_rows = []

        for week in weekly_breakdown:
            week_number = week.get("week_number")
            topic = week.get("topic")
            description = week.get("description")
            resources = week.get("resources", [])
            focus_skills = week.get("focus_skills", []) or []

            matched_skill_id = None

            # A) try exact focus skill lookup
            for skill_name in focus_skills:
                normalized = (skill_name or "").strip().lower()
                gap = skill_lookup.get(normalized)
                if gap and gap.get("skill_id"):
                    matched_skill_id = gap["skill_id"]
                    break

            # B) fallback to partial topic matching
            if matched_skill_id is None and topic:
                topic_lower = topic.lower()
                for lookup_name, gap in skill_lookup.items():
                    if lookup_name in topic_lower and gap.get("skill_id"):
                        matched_skill_id = gap["skill_id"]
                        break

            # C) if still not found, try first focus skill partial containment
            if matched_skill_id is None and focus_skills:
                for focus_skill in focus_skills:
                    normalized_focus = (focus_skill or "").strip().lower()
                    for lookup_name, gap in skill_lookup.items():
                        if normalized_focus in lookup_name or lookup_name in normalized_focus:
                            if gap.get("skill_id"):
                                matched_skill_id = gap["skill_id"]
                                break
                    if matched_skill_id is not None:
                        break

            if matched_skill_id is None:
                raise ValueError(
                    f"Could not map a skill_id for week {week_number}. "
                    f"Focus skills were: {focus_skills}"
                )

            weekly_rows.append({
                "plan_id": plan_id,
                "week_number": week_number,
                "skill_id": matched_skill_id,
                "topic": topic,
                "description": description,
                "resources": resources
            })

        await self.repo.insert_plan_content(weekly_rows)

        # =====================================================
        # 4) Save user skills snapshot
        # =====================================================
        user_skills_rows = []

        for gap in skill_gaps:
            if not gap.get("skill_id"):
                continue

            user_skills_rows.append({
                "plan_id": plan_id,
                "skill_id": gap.get("skill_id"),
                "status": gap.get("status", "missing"),
                "current_level": gap.get("current_level", "none"),
                "required_level": gap.get("required_level", confirmed_level),
                "gap_score": gap.get("gap_score", 1.0)
            })

        await self.repo.insert_user_skills(user_skills_rows)

        logger.info(f"✅ Plan saved successfully: plan_id={plan_id}")

        return {
            "plan_id": plan_id,
            "message": "Plan saved successfully",
            "saved_weeks": len(weekly_rows),
            "saved_skill_snapshots": len(user_skills_rows),
            "metadata": {
                "available_hours_per_week": plan_data.get("available_hours_per_week"),
                "study_intensity": plan_data.get("study_intensity"),
                "planning_mode": plan_data.get("planning_mode"),
                "current_average_level": plan_data.get("current_average_level"),
                "final_expected_level": plan_data.get("final_expected_level"),
            }
        }