"""
Plan Regeneration Service - two-stage LLM, cumulative, personalized, resilient version
"""

import json
import logging
import re
from typing import Dict, Any, List, Optional

from shared.providers.llm_models.llm_provider import create_llm_provider
from features.career_builder.services.resource_search_service import ResourceSearchService
from features.career_builder.services.plan_feedback_mapper import PlanFeedbackMapper

logger = logging.getLogger(__name__)


PLAN_REGENERATION_STRUCTURE_PROMPT = """
You are a senior software engineering mentor revising a personalized learning plan.

Apply the user feedback meaningfully.
This is NOT a cosmetic change.

You must generate ONLY the revised weekly structure.
DO NOT generate study_guide.
DO NOT generate resource_queries.
DO NOT include URLs.

==============================================================
FEEDBACK TO APPLY
==============================================================
{feedback_instructions}

==============================================================
REGENERATION MODE
==============================================================
{regeneration_mode}

==============================================================
MANDATORY CONSTRAINTS
==============================================================
1. Return VALID JSON only
2. Keep EXACT same number of weeks: {duration_weeks}
3. Keep EXACT same skills (only from used_learning_targets)
4. Keep week numbering sequential from 1 to {duration_weeks}
5. Output JSON only
6. No markdown
7. Do NOT add extra braces or brackets
8. Final character must be }}

==============================================================
FOR EACH WEEK ADD:
==============================================================
- guide_style
- resource_focus
- avoid_topics

==============================================================
ORIGINAL PLAN REFERENCE
==============================================================
{previous_plan_json}

==============================================================
OUTPUT JSON
==============================================================
{{
  "plan_summary": "Updated summary reflecting feedback changes",
  "improvement_summary": "Specific description of how feedback was applied",
  "weekly_breakdown": [
    {{
      "week_number": 1,
      "focus_skills": ["SkillName"],
      "topic": "Updated topic title",
      "description": "Concrete description",
      "learning_outcomes": ["Outcome 1", "Outcome 2"],
      "expected_level_after_week": "beginner",
      "guide_style": "hands_on",
      "resource_focus": ["phrase 1", "phrase 2"],
      "avoid_topics": ["phrase 1"]
    }}
  ]
}}
"""


STUDY_GUIDE_REGEN_PROMPT = """
You are a senior software engineering mentor.

Generate ONLY a personalized study_guide JSON object for ONE regenerated week.

==============================================================
CONTEXT
==============================================================
Track: __TRACK_NAME__
Week Number: __WEEK_NUMBER__
Focus Skill: __FOCUS_SKILL__
Week Topic: __WEEK_TOPIC__
Week Description: __WEEK_DESCRIPTION__
Current Skill Level: __CURRENT_LEVEL__
Target Skill Level: __TARGET_LEVEL__
Expected Level After This Week: __EXPECTED_LEVEL_AFTER_WEEK__
Available Hours This Week: __AVAILABLE_HOURS__
Guide Style: __GUIDE_STYLE__
Resource Focus: __RESOURCE_FOCUS__
Avoid Topics: __AVOID_TOPICS__
Feedback Intents: __FEEDBACK_INTENTS__

==============================================================
RULES
==============================================================
1. Return VALID JSON only
2. No markdown
3. No comments
4. Apply the feedback meaningfully in how the user studies
5. Keep the guide realistic for the user's level
6. Final character must be }

==============================================================
OUTPUT JSON
==============================================================
{
  "study_guide": {
    "what_to_study": ["item 1", "item 2", "item 3"],
    "how_to_study": [
      "1. ...",
      "2. ...",
      "3. ..."
    ],
    "time_split": {
      "reading_study": "25%",
      "hands_on_coding": "50%",
      "project_integration": "25%"
    }
  }
}
"""


class PlanRegenerationService:
    LEVEL_VALUES = {
        "none": 0,
        "beginner": 1,
        "intermediate": 2,
        "advanced": 3,
    }

    TRACK_KEYWORDS = {
        "frontend": ["ui", "browser", "component", "state management", "responsive"],
        "backend": ["api", "database", "authentication", "server", "deployment"],
        "full stack": ["frontend", "backend", "api", "database", "architecture"],
        "data science": ["data analysis", "machine learning", "statistics", "model evaluation", "notebook"],
        "data analyst": ["sql", "dashboard", "reporting", "visualization", "analytics"],
        "devops": ["docker", "kubernetes", "ci/cd", "deployment", "observability"],
        "mobile": ["android", "ios", "ui", "state", "performance"],
    }

    def __init__(self):
        try:
            self.llm = create_llm_provider()
        except Exception as e:
            logger.error("Failed to initialize LLM provider in regeneration: %s", e, exc_info=True)
            self.llm = None

        try:
            self.resource_search_service = ResourceSearchService()
        except Exception as e:
            logger.error("Failed to initialize ResourceSearchService in regeneration: %s", e, exc_info=True)
            self.resource_search_service = None

    async def regenerate_plan(
        self,
        previous_plan: Dict[str, Any],
        feedback_intents: List[str],
        regeneration_mode: str = "full",
    ) -> Dict[str, Any]:
        if not previous_plan:
            raise ValueError("previous_plan is required")

        duration_weeks = previous_plan.get("duration_weeks", 0)
        if not isinstance(duration_weeks, int) or duration_weeks <= 0:
            raise ValueError("previous_plan must contain a valid duration_weeks")

        if not feedback_intents or not isinstance(feedback_intents, list):
            raise ValueError("feedback_intents must be a non-empty list")

        feedback_intents_str = [self._normalize_intent(intent) for intent in feedback_intents]

        try:
            validated_intents = PlanFeedbackMapper.validate_intents(feedback_intents_str)
        except ValueError as e:
            raise ValueError(f"Invalid feedback intents: {e}")

        feedback_instruction = PlanFeedbackMapper.map_intents_to_instruction(validated_intents)
        compact_context = self._build_compact_context(previous_plan)

        prompt = PLAN_REGENERATION_STRUCTURE_PROMPT.format(
            feedback_instructions=feedback_instruction,
            regeneration_mode=regeneration_mode,
            duration_weeks=duration_weeks,
            previous_plan_json=json.dumps(compact_context, ensure_ascii=False, indent=2),
        )

        logger.info(
            "Regenerating plan structure. mode=%s intents=%s duration=%s weeks",
            regeneration_mode,
            feedback_intents_str,
            duration_weeks,
        )

        used_learning_targets = previous_plan.get("used_learning_targets", []) or []
        available_hours_per_week = previous_plan.get("available_hours_per_week", 6)
        track_name = previous_plan.get("track_name", "Unknown Track")
        current_average_level = previous_plan.get("current_average_level", "beginner")
        final_expected_level = previous_plan.get("final_expected_level", "intermediate")

        # ============================================================
        # LLM CALL #1 -> revised weekly structure
        # ============================================================
        try:
            if not self.llm:
                raise ValueError("LLM provider is unavailable")

            response = await self.llm.get_response(
                prompt=prompt,
                need_json_output=True,
                temperature=0.3,
            )

            if not response:
                raise ValueError("LLM returned empty response")

            structure_data = response if isinstance(response, dict) else self._safe_parse_json(response)
            weekly_breakdown = structure_data.get("weekly_breakdown", []) or []

            weekly_breakdown = self._soft_validate_and_fix(
                weekly_breakdown=weekly_breakdown,
                duration_weeks=duration_weeks,
                used_learning_targets=used_learning_targets,
                available_hours_per_week=available_hours_per_week,
            )

            weekly_breakdown = self._reduce_weekly_repetition(weekly_breakdown, duration_weeks)
            weekly_breakdown = self._enforce_weekly_expected_level_guard(
                weekly_breakdown,
                used_learning_targets,
                duration_weeks,
            )

            plan_data = {
                "plan_summary": structure_data.get("plan_summary") or "Updated plan generated from user feedback.",
                "improvement_summary": structure_data.get("improvement_summary") or (
                    f"Applied feedback intents: {', '.join(feedback_intents_str)}."
                ),
                "weekly_breakdown": weekly_breakdown,
            }

        except Exception as e:
            logger.warning("LLM regeneration failed, using fallback. Reason: %s", e)
            plan_data = self._build_fallback_regenerated_plan(
                previous_plan=previous_plan,
                feedback_intents=feedback_intents_str,
                duration_weeks=duration_weeks,
            )

        weekly_breakdown = plan_data.get("weekly_breakdown", []) or []

        # ============================================================
        # LLM CALL #2 -> personalized study guide per week
        # ============================================================
        for week in weekly_breakdown:
            level_info = self._infer_week_levels_from_topic(
                week=week,
                used_learning_targets=used_learning_targets,
            )

            try:
                study_guide = await self._generate_personalized_study_guide_for_week(
                    track_name=track_name,
                    week=week,
                    current_level=level_info.get("current_level", "beginner"),
                    target_level=level_info.get("target_level", "intermediate"),
                    available_hours_per_week=available_hours_per_week,
                    feedback_intents=feedback_intents_str,
                )
            except Exception as e:
                logger.warning(
                    "Study guide regeneration failed for week %s, using fallback. Reason: %s",
                    week.get("week_number"),
                    e,
                )
                study_guide = self._build_fallback_study_guide(
                    week=week,
                    current_level=level_info.get("current_level", "beginner"),
                    target_level=level_info.get("target_level", "intermediate"),
                    feedback_intents=feedback_intents_str,
                )

            week["study_guide"] = study_guide

        # ============================================================
        # Build personalized resource queries in code
        # ============================================================
        track_keywords = self._build_track_keywords(track_name)

        for week in weekly_breakdown:
            level_info = self._infer_week_levels_from_topic(
                week=week,
                used_learning_targets=used_learning_targets,
            )

            generated_queries = self._build_specific_resource_queries_for_week(
                week=week,
                duration_weeks=duration_weeks,
                available_hours_per_week=available_hours_per_week,
                feedback_intents=feedback_intents_str,
            )

            resource_queries = self._enrich_resource_queries(
                resource_queries=generated_queries,
                week_topic=week.get("topic", ""),
                focus_skills=week.get("focus_skills", []),
                current_level=level_info.get("current_level", "beginner"),
                target_level=level_info.get("target_level", "intermediate"),
                week_number=int(week.get("week_number", 1) or 1),
                duration_weeks=duration_weeks,
                available_hours_per_week=available_hours_per_week,
                feedback_intents=feedback_intents_str,
                resource_focus=week.get("resource_focus", []),
                avoid_topics=week.get("avoid_topics", []),
            )

            resources = []
            if self.resource_search_service:
                try:
                    resources = await self.resource_search_service.search_resources(
                        resource_queries=resource_queries,
                        max_per_week=4,
                        current_level=level_info.get("current_level"),
                        target_level=level_info.get("target_level"),
                        available_hours_per_week=available_hours_per_week,
                        week_number=week.get("week_number"),
                        duration_weeks=duration_weeks,
                        context_keywords=week.get("focus_skills", []) + track_keywords + week.get("resource_focus", []),
                        track_name=track_name,
                        week_topic=week.get("topic", ""),
                    )
                except Exception as e:
                    logger.warning(
                        "Resource fetching failed in regeneration for week %s: %s",
                        week.get("week_number"),
                        e,
                    )
                    resources = []

            if not resources:
                resources = self._build_fallback_resources_for_week(
                    week=week,
                    track_name=track_name,
                    current_level=level_info.get("current_level", "beginner"),
                    target_level=level_info.get("target_level", "intermediate"),
                )

            week["resources"] = resources
            week["resource_validation_report"] = {
                "track_name": track_name,
                "current_level": level_info.get("current_level"),
                "target_level": level_info.get("target_level"),
                "resource_count": len(resources),
                "regeneration_feedback": feedback_intents_str,
            }

            week.pop("resource_focus", None)
            week.pop("avoid_topics", None)
            week.pop("guide_style", None)

        plan_data["weekly_breakdown"] = weekly_breakdown

        return {
            "track_id": previous_plan.get("track_id"),
            "track_name": track_name,
            "duration_weeks": duration_weeks,
            "available_hours_per_week": available_hours_per_week,
            "planning_mode": previous_plan.get("planning_mode", "regenerated_plan"),
            "current_average_level": current_average_level,
            "final_expected_level": final_expected_level,
            "used_learning_targets": used_learning_targets,
            "generation_metadata": {
                "regenerated": True,
                "feedback_intents": feedback_intents_str,
                "regeneration_mode": regeneration_mode,
                "two_stage_llm": True,
            },
            **plan_data,
        }

    def _normalize_intent(self, intent: Any) -> str:
        if isinstance(intent, str):
            value = intent
        elif hasattr(intent, "value"):
            value = str(intent.value)
        else:
            value = str(intent)

        value = value.strip()

        if "." in value:
            value = value.split(".")[-1]

        return value.strip().lower()

    def _normalize_level(self, level: Optional[str]) -> str:
        normalized = (level or "").strip().lower()
        return normalized if normalized in self.LEVEL_VALUES else ""

    def _normalize_track_name(self, track_name: Optional[str]) -> str:
        return " ".join((track_name or "").strip().lower().split())

    def _build_track_keywords(self, track_name: Optional[str]) -> List[str]:
        normalized = self._normalize_track_name(track_name)
        for key, values in self.TRACK_KEYWORDS.items():
            if key in normalized:
                return values
        return []

    def _build_compact_context(self, previous_plan: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "track_name": previous_plan.get("track_name"),
            "duration_weeks": previous_plan.get("duration_weeks"),
            "available_hours_per_week": previous_plan.get("available_hours_per_week"),
            "planning_mode": previous_plan.get("planning_mode"),
            "current_average_level": previous_plan.get("current_average_level"),
            "final_expected_level": previous_plan.get("final_expected_level"),
            "used_learning_targets": previous_plan.get("used_learning_targets", []),
            "weekly_breakdown": [
                {
                    "week_number": week.get("week_number"),
                    "focus_skills": week.get("focus_skills", []),
                    "topic": week.get("topic"),
                    "description": week.get("description"),
                    "expected_level_after_week": week.get("expected_level_after_week"),
                }
                for week in (previous_plan.get("weekly_breakdown", []) or [])
            ],
        }

    def _build_study_guide_prompt(
        self,
        track_name: str,
        week: Dict[str, Any],
        current_level: str,
        target_level: str,
        available_hours_per_week: int,
        feedback_intents: List[str],
    ) -> str:
        prompt = STUDY_GUIDE_REGEN_PROMPT
        prompt = prompt.replace("__TRACK_NAME__", str(track_name))
        prompt = prompt.replace("__WEEK_NUMBER__", str(week.get("week_number", 1)))
        prompt = prompt.replace("__FOCUS_SKILL__", str((week.get("focus_skills") or ["General Skill"])[0]))
        prompt = prompt.replace("__WEEK_TOPIC__", str(week.get("topic", "")))
        prompt = prompt.replace("__WEEK_DESCRIPTION__", str(week.get("description", "")))
        prompt = prompt.replace("__CURRENT_LEVEL__", str(current_level))
        prompt = prompt.replace("__TARGET_LEVEL__", str(target_level))
        prompt = prompt.replace("__EXPECTED_LEVEL_AFTER_WEEK__", str(week.get("expected_level_after_week", "beginner")))
        prompt = prompt.replace("__AVAILABLE_HOURS__", str(available_hours_per_week))
        prompt = prompt.replace("__GUIDE_STYLE__", str(week.get("guide_style", "hands_on")))
        prompt = prompt.replace("__RESOURCE_FOCUS__", json.dumps(week.get("resource_focus", []), ensure_ascii=False))
        prompt = prompt.replace("__AVOID_TOPICS__", json.dumps(week.get("avoid_topics", []), ensure_ascii=False))
        prompt = prompt.replace("__FEEDBACK_INTENTS__", json.dumps(feedback_intents, ensure_ascii=False))
        return prompt

    async def _generate_personalized_study_guide_for_week(
        self,
        track_name: str,
        week: Dict[str, Any],
        current_level: str,
        target_level: str,
        available_hours_per_week: int,
        feedback_intents: List[str],
    ) -> Dict[str, Any]:
        if not self.llm:
            raise ValueError("LLM provider is unavailable")

        prompt = self._build_study_guide_prompt(
            track_name=track_name,
            week=week,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
            feedback_intents=feedback_intents,
        )

        response = await self.llm.get_response(
            prompt=prompt,
            need_json_output=True,
            temperature=0.25,
        )

        if not response:
            raise ValueError("LLM returned empty response for regenerated study guide")

        data = response if isinstance(response, dict) else self._safe_parse_json(response)
        study_guide = data.get("study_guide")
        if not isinstance(study_guide, dict):
            raise ValueError("Invalid regenerated study_guide response from LLM")
        return study_guide

    def _fix_common_json_issues(self, raw: str) -> str:
        text = (raw or "").strip()
        if text.endswith("}}]"):
            text = text[:-3] + "}]"
        text = re.sub(r",\s*([}\]])", r"\1", text)
        return text

    def _safe_parse_json(self, raw: str) -> Dict[str, Any]:
        if raw is None:
            raise ValueError("Cannot parse JSON from None response")

        raw = self._fix_common_json_issues(raw)

        try:
            return json.loads(raw)
        except Exception:
            pass

        fenced = re.search(r"```(?:json)?\s*(\{.*\})\s*```", raw, re.DOTALL)
        if fenced:
            candidate = self._fix_common_json_issues(fenced.group(1))
            return json.loads(candidate)

        brace_match = re.search(r"(\{.*\})", raw, re.DOTALL)
        if brace_match:
            candidate = self._fix_common_json_issues(brace_match.group(1))
            return json.loads(candidate)

        raise ValueError("Failed to parse regeneration JSON from model response")

    def _soft_validate_and_fix(
        self,
        weekly_breakdown: List[Dict[str, Any]],
        duration_weeks: int,
        used_learning_targets: List[Dict[str, Any]],
        available_hours_per_week: int,
    ) -> List[Dict[str, Any]]:
        if not weekly_breakdown:
            return self._build_fallback_regenerated_plan(
                previous_plan={
                    "duration_weeks": duration_weeks,
                    "used_learning_targets": used_learning_targets,
                },
                feedback_intents=[],
                duration_weeks=duration_weeks,
            )["weekly_breakdown"]

        skill_names = [t.get("skill_name") for t in used_learning_targets if t.get("skill_name")]
        if not skill_names:
            skill_names = ["General Skill"]

        fixed = []
        seen_week_numbers = set()

        for idx, week in enumerate(weekly_breakdown, start=1):
            week_number = int(week.get("week_number", idx) or idx)
            if week_number in seen_week_numbers or week_number < 1 or week_number > duration_weeks:
                continue
            seen_week_numbers.add(week_number)

            focus_skills = week.get("focus_skills") or [skill_names[(idx - 1) % len(skill_names)]]
            topic = (week.get("topic") or "").strip() or f"{focus_skills[0]} applied practice"
            description = (week.get("description") or "").strip() or (
                f"Practice and strengthen {focus_skills[0]} through structured exercises."
            )
            learning_outcomes = week.get("learning_outcomes") or [
                f"Understand the weekly concept in {focus_skills[0]}",
                f"Apply it in practice",
            ]
            expected = self._normalize_level(week.get("expected_level_after_week")) or "beginner"

            guide_style = (week.get("guide_style") or "").strip() or "hands_on"

            resource_focus = week.get("resource_focus")
            if not isinstance(resource_focus, list) or not resource_focus:
                resource_focus = [focus_skills[0], topic]

            avoid_topics = week.get("avoid_topics")
            if not isinstance(avoid_topics, list):
                avoid_topics = []

            fixed.append({
                "week_number": week_number,
                "focus_skills": focus_skills,
                "topic": topic,
                "description": description,
                "learning_outcomes": learning_outcomes[:2],
                "expected_level_after_week": expected,
                "guide_style": guide_style,
                "resource_focus": resource_focus[:4],
                "avoid_topics": avoid_topics[:3],
            })

        for week_number in range(1, duration_weeks + 1):
            if week_number not in seen_week_numbers:
                focus_skill = skill_names[(week_number - 1) % len(skill_names)]
                fixed.append({
                    "week_number": week_number,
                    "focus_skills": [focus_skill],
                    "topic": f"{focus_skill} applied progression",
                    "description": f"Continue improving {focus_skill} with targeted practice and implementation.",
                    "learning_outcomes": [
                        f"Understand a deeper part of {focus_skill}",
                        f"Apply it in a realistic task",
                    ],
                    "expected_level_after_week": "intermediate",
                    "guide_style": "project_based",
                    "resource_focus": [focus_skill, "real-world usage"],
                    "avoid_topics": [],
                })

        fixed.sort(key=lambda x: x["week_number"])
        return fixed

    def _reduce_weekly_repetition(
        self,
        weekly_breakdown: List[Dict[str, Any]],
        duration_weeks: int,
    ) -> List[Dict[str, Any]]:
        seen_topics = set()
        for idx, week in enumerate(weekly_breakdown, 1):
            topic = (week.get("topic") or "").strip()
            if topic.lower() in seen_topics:
                week["topic"] = f"{topic} — variation {idx}"
            seen_topics.add(week["topic"].strip().lower())
        return weekly_breakdown

    def _enforce_weekly_expected_level_guard(
        self,
        weekly_breakdown: List[Dict[str, Any]],
        used_learning_targets: List[Dict[str, Any]],
        duration_weeks: int,
    ) -> List[Dict[str, Any]]:
        target_map = {t.get("skill_name"): t for t in used_learning_targets}

        for week in weekly_breakdown:
            focus_skill = (week.get("focus_skills") or [None])[0]
            if not focus_skill or focus_skill not in target_map:
                continue

            target = target_map[focus_skill]
            current_value = self.LEVEL_VALUES.get(
                self._normalize_level(target.get("current_level")) or "none",
                0,
            )
            target_value = self.LEVEL_VALUES.get(
                self._normalize_level(target.get("target_level")) or "beginner",
                1,
            )
            week_value = self.LEVEL_VALUES.get(
                self._normalize_level(week.get("expected_level_after_week")) or "beginner",
                1,
            )

            if week_value < current_value:
                week["expected_level_after_week"] = target.get("current_level", "beginner")
            if week_value > target_value:
                week["expected_level_after_week"] = target.get("target_level", "intermediate")

        return weekly_breakdown

    def _build_specific_resource_queries_for_week(
        self,
        week: Dict[str, Any],
        duration_weeks: int,
        available_hours_per_week: int,
        feedback_intents: List[str],
    ) -> List[Dict[str, Any]]:
        focus_skill = (week.get("focus_skills") or ["General Skill"])[0]
        topic = week.get("topic", focus_skill)
        expected_level = self._normalize_level(week.get("expected_level_after_week")) or "intermediate"

        emphasis = []
        if "more_practical" in feedback_intents or "more_projects" in feedback_intents:
            emphasis.append("hands-on implementation")
        if "more_advanced" in feedback_intents:
            emphasis.append("advanced patterns")
        if "more_theory" in feedback_intents:
            emphasis.append("concepts architecture")
        if "simpler_basics" in feedback_intents:
            emphasis.append("fundamentals explained")
        if "faster_progress" in feedback_intents:
            emphasis.append("direct practical path")

        resource_focus = week.get("resource_focus", []) or []
        avoid_topics = week.get("avoid_topics", []) or []

        emphasis_text = " ".join(emphasis + resource_focus[:2]).strip()
        avoid_text = ""
        if avoid_topics:
            avoid_text = " avoid " + " ".join(avoid_topics[:2])

        return [
            {
                "title": f"{focus_skill} video",
                "query": f"{focus_skill} {topic} {expected_level} tutorial {emphasis_text}{avoid_text}".strip(),
                "type": "youtube",
            },
            {
                "title": f"{focus_skill} docs",
                "query": f"{focus_skill} {topic} documentation api reference {emphasis_text}{avoid_text}".strip(),
                "type": "docs",
            },
            {
                "title": f"{focus_skill} practice",
                "query": f"{focus_skill} {topic} hands-on exercises {emphasis_text}{avoid_text}".strip(),
                "type": "practice",
            },
            {
                "title": f"{focus_skill} project",
                "query": f"{focus_skill} {topic} real project case study {emphasis_text}{avoid_text}".strip(),
                "type": "project",
            },
        ]

    def _infer_week_levels_from_topic(
        self,
        week: Dict[str, Any],
        used_learning_targets: List[Dict[str, Any]],
    ) -> Dict[str, str]:
        focus_skill = (week.get("focus_skills") or [None])[0]
        target_map = {t.get("skill_name"): t for t in used_learning_targets}

        if focus_skill and focus_skill in target_map:
            target = target_map[focus_skill]
            return {
                "current_level": target.get("current_level", "none"),
                "target_level": target.get("target_level", "beginner"),
            }

        expected = self._normalize_level(week.get("expected_level_after_week")) or "beginner"
        fallback_current = "beginner" if expected in ("intermediate", "advanced") else "none"
        return {
            "current_level": fallback_current,
            "target_level": expected,
        }

    def _enrich_resource_queries(
        self,
        resource_queries: List[Dict[str, Any]],
        week_topic: str,
        focus_skills: List[str],
        current_level: str,
        target_level: str,
        week_number: int,
        duration_weeks: int,
        available_hours_per_week: int,
        feedback_intents: List[str],
        resource_focus: Optional[List[str]] = None,
        avoid_topics: Optional[List[str]] = None,
    ) -> List[Dict[str, Any]]:
        primary_skill = focus_skills[0] if focus_skills else ""
        level_desc = target_level or current_level or "beginner"

        emphasis = []
        if "more_practical" in feedback_intents or "more_projects" in feedback_intents:
            emphasis.append("hands-on implementation")
        if "more_advanced" in feedback_intents:
            emphasis.append("advanced patterns")
        if "more_theory" in feedback_intents:
            emphasis.append("concepts architecture")

        resource_focus = resource_focus or []
        avoid_topics = avoid_topics or []

        emphasis_text = " ".join(emphasis + resource_focus[:2]).strip()
        avoid_text = ""
        if avoid_topics:
            avoid_text = " avoid " + " ".join(avoid_topics[:2])

        enriched = []
        for item in resource_queries or []:
            item = dict(item)
            query = (item.get("query") or "").strip()
            q_type = (item.get("type") or "article").lower()

            if q_type == "youtube":
                item["query"] = f"{query} {week_topic} {level_desc} tutorial {emphasis_text}{avoid_text}".strip()
            elif q_type == "docs":
                item["query"] = f"{query} {week_topic} documentation api reference {emphasis_text}{avoid_text}".strip()
            elif q_type == "practice":
                item["query"] = f"{query} {week_topic} hands-on exercises {emphasis_text}{avoid_text}".strip()
            elif q_type == "project":
                item["query"] = f"{query} {week_topic} real project {emphasis_text}{avoid_text}".strip()
            else:
                item["query"] = f"{query} {week_topic} {emphasis_text}{avoid_text}".strip()

            enriched.append(item)

        return enriched[:4]

    def _build_fallback_resources_for_week(
        self,
        week: Dict[str, Any],
        track_name: str,
        current_level: str,
        target_level: str,
    ) -> List[Dict[str, Any]]:
        topic = week.get("topic", "Weekly Topic")
        skill = (week.get("focus_skills") or ["General Skill"])[0]

        return [
            {
                "title": f"{topic} official docs",
                "url": "https://docs.python.org/3/",
                "type": "docs",
                "snippet": f"Fallback official documentation for {skill}",
                "duration": "30 min",
            },
            {
                "title": f"{topic} practice",
                "url": "https://github.com/",
                "type": "practice",
                "snippet": f"Fallback practice resource for {skill}",
                "duration": "2 hours",
            },
            {
                "title": f"{topic} project example",
                "url": "https://github.com/",
                "type": "project",
                "snippet": f"Fallback project resource for {skill}",
                "duration": "full course",
            },
            {
                "title": f"{topic} article",
                "url": "https://realpython.com/",
                "type": "article",
                "snippet": f"Fallback article resource for {skill}",
                "duration": "30 min",
            },
        ]

    def _build_fallback_study_guide(
        self,
        week: Dict[str, Any],
        current_level: str,
        target_level: str,
        feedback_intents: List[str],
    ) -> Dict[str, Any]:
        focus_skill = (week.get("focus_skills") or ["General Skill"])[0]
        topic = week.get("topic", focus_skill)

        emphasis = []
        if "more_practical" in feedback_intents:
            emphasis.append("hands-on implementation")
        if "more_advanced" in feedback_intents:
            emphasis.append("deeper patterns")
        if "less_repetition" in feedback_intents:
            emphasis.append("fresh examples")

        return {
            "what_to_study": [
                topic,
                f"{focus_skill} practical usage",
                ", ".join(emphasis) if emphasis else f"{focus_skill} applied progression",
            ],
            "how_to_study": [
                f"1. Review the main idea behind {topic}",
                f"2. Practice one realistic task using {focus_skill}",
                f"3. Refine your solution and note what improved after feedback",
            ],
            "time_split": {
                "reading_study": "25%",
                "hands_on_coding": "50%",
                "project_integration": "25%",
            },
        }

    def _build_fallback_regenerated_plan(
        self,
        previous_plan: Dict[str, Any],
        feedback_intents: List[str],
        duration_weeks: int,
    ) -> Dict[str, Any]:
        old_weeks = previous_plan.get("weekly_breakdown", []) or []
        rebuilt_weeks = []

        for idx in range(1, duration_weeks + 1):
            source = old_weeks[idx - 1] if idx - 1 < len(old_weeks) else {}
            focus_skills = source.get("focus_skills", ["General Skill"])
            topic = source.get("topic", f"{focus_skills[0]} progression")

            if "more_practical" in feedback_intents:
                topic = f"{topic} — implementation focused"
            elif "more_advanced" in feedback_intents:
                topic = f"{topic} — deeper patterns"
            elif "less_repetition" in feedback_intents:
                topic = f"{topic} — fresh variation {idx}"

            rebuilt_weeks.append({
                "week_number": idx,
                "focus_skills": focus_skills,
                "topic": topic,
                "description": source.get("description") or f"Work on {topic} with concrete weekly exercises.",
                "learning_outcomes": source.get("learning_outcomes") or [
                    f"Understand the main concept in {topic}",
                    f"Apply it in a realistic task",
                ],
                "expected_level_after_week": source.get("expected_level_after_week", "intermediate"),
                "guide_style": "project_based" if "more_practical" in feedback_intents else "hands_on",
                "resource_focus": [focus_skills[0], topic],
                "avoid_topics": [],
            })

        return {
            "plan_summary": "This regenerated plan adapts the original plan based on the selected feedback.",
            "improvement_summary": (
                f"Applied feedback intents: {', '.join(feedback_intents) if feedback_intents else 'none'}."
            ),
            "weekly_breakdown": rebuilt_weeks,
        }