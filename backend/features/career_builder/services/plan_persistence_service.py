import logging
from uuid import UUID
from typing import Dict, Any, List
from datetime import datetime

logger = logging.getLogger(__name__)


class PlanPersistenceService:
    def __init__(self, repository):
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
    ) -> Dict[str, Any]:
        if not plan_data:
            raise ValueError("plan_data is required")

        weekly_breakdown = plan_data.get("weekly_breakdown", []) or []
        if not weekly_breakdown:
            raise ValueError("No weekly_breakdown found in plan_data")

        available_hours_per_week = plan_data.get("available_hours_per_week")

        plan_id = await self.repo.create_plan(
            user_id=user_id,
            cv_id=cv_id,
            track_id=track_id,
            detected_level=detected_level,
            confirmed_level=confirmed_level,
            duration_weeks=duration_weeks,
            realism_flag=False,
            suggested_min_weeks=None
        )

        if not plan_id:
            raise ValueError("Failed to create plan")

        skill_rows = []
        for gap in skill_gaps or []:
            skill_id = gap.get("skill_id")
            if skill_id is None:
                continue

            skill_rows.append({
                "plan_id": plan_id,
                "skill_id": skill_id,
                "status": gap.get("status", "missing"),
                "current_level": gap.get("current_level", "none"),
                "required_level": gap.get("required_level", "beginner"),
                "gap_score": gap.get("gap_score", 1.0),
            })

        await self.repo.insert_user_skills(skill_rows)

        weekly_rows = []
        for week in weekly_breakdown:
            focus_skills = week.get("focus_skills", []) or []
            matched_skill_id = None

            for gap in skill_gaps or []:
                if gap.get("skill_name") in focus_skills:
                    matched_skill_id = gap.get("skill_id")
                    break

            if matched_skill_id is None:
                continue

            weekly_rows.append({
                "plan_id": plan_id,
                "week_number": week.get("week_number"),
                "skill_id": matched_skill_id,
                "topic": week.get("topic"),
                "description": week.get("description"),
                "resources": week.get("resources", []),
            })

        await self.repo.insert_plan_content(weekly_rows)

        return {
            "plan_id": plan_id,
            "message": "Plan saved successfully",
            "created_at": datetime.utcnow().isoformat(),
            "available_hours_per_week": available_hours_per_week,
            "weeks_saved": len(weekly_rows),
            "skills_saved": len(skill_rows),
        }