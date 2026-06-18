import logging
from uuid import UUID
from typing import Dict, Any, List, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class PlanPersistenceService:
    def __init__(self, repository):
        self.repo = repository

    def _build_skill_id_map(
        self,
        used_learning_targets: List[Dict[str, Any]],
    ) -> Dict[str, int]:
        skill_map = {}

        for target in used_learning_targets or []:
            skill_name = target.get("skill_name")
            skill_id = target.get("skill_id")

            if skill_name and skill_id is not None:
                skill_map[str(skill_name).strip().lower()] = int(skill_id)

        return skill_map

    def _resolve_week_skill_id(
        self,
        week: Dict[str, Any],
        skill_id_map: Dict[str, int],
    ) -> Optional[int]:
        focus_skills = week.get("focus_skills", []) or []

        for skill_name in focus_skills:
            key = str(skill_name).strip().lower()
            if key in skill_id_map:
                return skill_id_map[key]

        return None

    async def save_plan(
        self,
        user_id: UUID,
        cv_id: UUID,
        track_id: int,
        duration_weeks: int,
        plan_data: Dict[str, Any],
    ) -> Dict[str, Any]:
        if not plan_data:
            raise ValueError("plan_data is required")

        weekly_breakdown = plan_data.get("weekly_breakdown", []) or []
        if not weekly_breakdown:
            raise ValueError("No weekly_breakdown found in plan_data")

        used_learning_targets = plan_data.get("used_learning_targets", []) or []
        skill_id_map = self._build_skill_id_map(used_learning_targets)

        if not skill_id_map:
            raise ValueError(
                "Cannot save plan because used_learning_targets is missing or has no skill_id values."
            )

        available_hours_per_week = plan_data.get("available_hours_per_week")

        plan_id = await self.repo.create_plan(
            user_id=user_id,
            cv_id=cv_id,
            track_id=track_id,
            detected_level="beginner",
            confirmed_level="beginner",
            duration_weeks=duration_weeks,
            realism_flag=False,
            suggested_min_weeks=None,
        )

        if not plan_id:
            raise ValueError("Failed to create plan")

        weekly_rows = []

        for week in weekly_breakdown:
            skill_id = self._resolve_week_skill_id(
                week=week,
                skill_id_map=skill_id_map,
            )

            if skill_id is None:
                raise ValueError(
                    f"Cannot resolve skill_id for week {week.get('week_number')} "
                    f"with focus_skills={week.get('focus_skills')}"
                )

            weekly_rows.append({
                "plan_id": plan_id,
                "week_number": week.get("week_number"),
                "skill_id": skill_id,
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
        }