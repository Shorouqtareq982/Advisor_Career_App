import json
import logging
from typing import Dict, Any, List

from shared.providers.llm_models.llm_provider import create_llm_provider
from features.career_builder.services.resource_search_service import ResourceSearchService

logger = logging.getLogger(__name__)


PLAN_REGENERATION_PROMPT = """
You are an expert career mentor and learning path designer.

You are given:
1) a previously generated career plan
2) user feedback
3) the original plan metadata

Your job is to regenerate the plan while preserving the new planning system structure.

IMPORTANT RULES:
1. Return VALID JSON only
2. Keep the same duration unless the feedback explicitly asks to change it
3. Preserve the same track and general learning direction
4. Keep the plan realistic and progressive
5. Respect the user's available_hours_per_week and study_intensity if present
6. Respect the same planning_mode if present unless feedback explicitly asks otherwise
7. Do NOT downgrade the final expected level
8. Do NOT remove important skills unless feedback asks to narrow the focus
9. Keep week numbering sequential starting from 1
10. Avoid repeating identical weekly topics
11. Each week must include:
   - week_number
   - focus_skills
   - topic
   - description
   - learning_outcomes
   - expected_level_after_week
   - resources
12. Each week should focus on 1 to 3 skills maximum
13. Keep the plan aligned with:
   - current_average_level
   - final_expected_level
   - used_learning_targets
   - deferred_learning_targets
14. If the previous plan is adaptive_compressed_plan, keep the same spirit unless the feedback asks otherwise
15. Do NOT invent unrelated skills outside the existing plan scope
16. You may change the weekly topics and descriptions, but the output must stay realistic and progressive
17. Do NOT return fake links
18. resources can be empty in the LLM output because the backend will rebuild them

User Feedback:
{feedback}

Regeneration Mode:
{regeneration_mode}

Previous Plan JSON:
{previous_plan_json}

Return JSON:
{{
  "plan_summary": "updated summary",
  "improvement_summary": "updated improvement summary",
  "weekly_breakdown": [
    {{
      "week_number": 1,
      "focus_skills": ["Skill A"],
      "topic": "Topic",
      "description": "Description",
      "learning_outcomes": ["Outcome 1"],
      "expected_level_after_week": "beginner",
      "resources": []
    }}
  ]
}}
"""


class PlanRegenerationService:
    def __init__(self):
        self.llm = create_llm_provider()
        self.resource_search_service = ResourceSearchService()

    async def regenerate_plan(
        self,
        previous_plan: Dict[str, Any],
        feedback: str,
        regeneration_mode: str = "full"
    ) -> Dict[str, Any]:
        """
        Regenerate an existing plan based on user feedback
        while preserving the modern plan structure.
        Also rebuilds weekly resources from real search APIs.
        """

        if not previous_plan:
            raise ValueError("previous_plan is required")

        duration_weeks = previous_plan.get("duration_weeks", 0)
        if not isinstance(duration_weeks, int) or duration_weeks <= 0:
            raise ValueError("previous_plan must contain a valid duration_weeks")

        if not feedback or not str(feedback).strip():
            raise ValueError("feedback is required")

        prompt = PLAN_REGENERATION_PROMPT.format(
            regeneration_mode=regeneration_mode,
            feedback=feedback,
            previous_plan_json=json.dumps(previous_plan, ensure_ascii=False, indent=2)
        )

        logger.info("Regenerating plan with updated structure...")

        response = await self.llm.get_response(
            prompt=prompt,
            need_json_output=True,
            temperature=0.35
        )

        if not response:
            raise ValueError("LLM returned empty regeneration response")

        plan_data = response if isinstance(response, dict) else self._safe_parse_json(response)

        weekly_breakdown = plan_data.get("weekly_breakdown", [])
        plan_summary = plan_data.get("plan_summary", previous_plan.get("plan_summary", ""))
        improvement_summary = plan_data.get(
            "improvement_summary",
            previous_plan.get("improvement_summary", "")
        )

        self._validate_weekly_plan(
            weekly_breakdown=weekly_breakdown,
            duration_weeks=duration_weeks
        )

        # =====================================================
        # Rebuild resources from backend search services
        # =====================================================
        used_learning_targets = previous_plan.get("used_learning_targets", []) or []
        available_hours_per_week = previous_plan.get("available_hours_per_week", 6)
        final_expected_level = previous_plan.get("final_expected_level", "intermediate")

        for week in weekly_breakdown:
            resource_queries = self._build_resource_queries_for_week(
                week=week,
                duration_weeks=duration_weeks,
                available_hours_per_week=available_hours_per_week
            )

            level_info = self._infer_week_levels_from_targets(
                week=week,
                used_learning_targets=used_learning_targets,
                fallback_target_level=final_expected_level
            )

            week["resources"] = await self.resource_search_service.search_resources(
                resource_queries=resource_queries,
                max_per_week=4,
                current_level=level_info["current_level"],
                target_level=level_info["target_level"],
                available_hours_per_week=available_hours_per_week,
                week_number=week.get("week_number"),
                duration_weeks=duration_weeks
            )

        regenerated_plan = {
            **previous_plan,
            "plan_summary": plan_summary,
            "improvement_summary": improvement_summary,
            "weekly_breakdown": weekly_breakdown,
            "regenerated": True,
            "regeneration_mode": regeneration_mode,
            "feedback": feedback
        }

        # keep modern metadata intact if already present
        for field in [
            "available_hours_per_week",
            "study_intensity",
            "planning_mode",
            "current_average_level",
            "current_track_score",
            "final_expected_level",
            "final_track_score",
            "final_skill_levels_after_plan",
            "learning_targets",
            "merged_learning_targets",
            "used_learning_targets",
            "deferred_learning_targets",
            "analysis_snapshot",
        ]:
            if field in previous_plan:
                regenerated_plan[field] = previous_plan[field]

        return regenerated_plan

    def _build_resource_queries_for_week(
        self,
        week: Dict[str, Any],
        duration_weeks: int,
        available_hours_per_week: int
    ) -> List[Dict[str, Any]]:
        """
        Force a useful resource mix for every regenerated week:
        - 1 YouTube
        - 1 Docs
        - 1 Practice / Project
        """
        topic = (week.get("topic") or "learning topic").strip()
        focus_skills = week.get("focus_skills", []) or []
        primary_skill = focus_skills[0] if focus_skills else topic
        week_number = int(week.get("week_number", 1) or 1)

        stage_ratio = week_number / max(duration_weeks, 1)

        if stage_ratio <= 0.33:
            difficulty_hint = "beginner tutorial"
            project_hint = "beginner mini project"
        elif stage_ratio <= 0.75:
            difficulty_hint = "intermediate tutorial"
            project_hint = "intermediate project"
        else:
            difficulty_hint = "advanced tutorial"
            project_hint = "real world project"

        if available_hours_per_week <= 5:
            project_hint = "small practice project"
        elif available_hours_per_week >= 10 and stage_ratio >= 0.75:
            project_hint = "capstone style project"

        return [
            {
                "title": f"{primary_skill} video tutorial",
                "query": f"{primary_skill} {difficulty_hint}",
                "type": "youtube"
            },
            {
                "title": f"{primary_skill} official documentation",
                "query": f"{primary_skill} official documentation",
                "type": "docs"
            },
            {
                "title": f"{primary_skill} hands-on practice",
                "query": f"{primary_skill} {project_hint}",
                "type": "practice"
            }
        ]

    def _infer_week_levels_from_targets(
        self,
        week: Dict[str, Any],
        used_learning_targets: List[Dict[str, Any]],
        fallback_target_level: str = "intermediate"
    ) -> Dict[str, str]:
        """
        Infer current_level and target_level for the week's primary skill.
        """
        focus_skills = week.get("focus_skills", []) or []
        primary_skill = focus_skills[0].strip().lower() if focus_skills else ""

        for target in used_learning_targets or []:
            skill_name = (target.get("skill_name") or "").strip().lower()
            if skill_name == primary_skill:
                return {
                    "current_level": self._normalize_level(target.get("current_level")),
                    "target_level": self._normalize_level(target.get("target_level")),
                }

        return {
            "current_level": "beginner",
            "target_level": self._normalize_level(fallback_target_level),
        }

    def _normalize_level(self, level: Any) -> str:
        value = str(level or "beginner").strip().lower()
        if value not in ("none", "beginner", "intermediate", "advanced"):
            return "beginner"
        return value

    def _safe_parse_json(self, raw_response: Any) -> Dict[str, Any]:
        """
        Safely parse LLM JSON output, including markdown-wrapped JSON.
        """
        if isinstance(raw_response, dict):
            return raw_response

        if not raw_response:
            return {}

        cleaned = str(raw_response).strip()
        cleaned = cleaned.replace("```json", "").replace("```", "").strip()

        try:
            return json.loads(cleaned)
        except Exception:
            start = cleaned.find("{")
            end = cleaned.rfind("}")
            if start != -1 and end != -1 and end > start:
                try:
                    return json.loads(cleaned[start:end + 1])
                except Exception:
                    pass

        raise ValueError("Failed to parse regenerated plan JSON")

    def _validate_weekly_plan(
        self,
        weekly_breakdown: List[Dict[str, Any]],
        duration_weeks: int
    ) -> None:
        """
        Validate regenerated weekly plan structure.
        """
        if not isinstance(weekly_breakdown, list) or not weekly_breakdown:
            raise ValueError("Regenerated plan is missing weekly breakdown")

        if len(weekly_breakdown) != duration_weeks:
            raise ValueError(
                f"Regenerated plan weeks mismatch. Expected {duration_weeks}, got {len(weekly_breakdown)}"
            )

        seen_weeks = set()
        seen_topics = set()

        for i, week in enumerate(weekly_breakdown, start=1):
            week_number = week.get("week_number")

            if week_number != i:
                raise ValueError(f"Invalid week numbering at week {i}")

            if week_number in seen_weeks:
                raise ValueError(f"Duplicate week number detected: {week_number}")
            seen_weeks.add(week_number)

            if not week.get("topic"):
                raise ValueError(f"Week {i} is missing topic")

            if not week.get("description"):
                raise ValueError(f"Week {i} is missing description")

            topic_key = str(week.get("topic", "")).strip().lower()
            if topic_key in seen_topics:
                raise ValueError(f"Repeated topic detected: {week.get('topic')}")
            seen_topics.add(topic_key)

            if not isinstance(week.get("focus_skills", []), list):
                raise ValueError(f"Week {i} focus_skills must be a list")

            if len(week.get("focus_skills", [])) > 3:
                raise ValueError(f"Week {i} has more than 3 focus skills")

            if not isinstance(week.get("learning_outcomes", []), list):
                raise ValueError(f"Week {i} learning_outcomes must be a list")

            if "expected_level_after_week" not in week:
                raise ValueError(f"Week {i} is missing expected_level_after_week")

            if not isinstance(week.get("resources", []), list):
                raise ValueError(f"Week {i} resources must be a list")