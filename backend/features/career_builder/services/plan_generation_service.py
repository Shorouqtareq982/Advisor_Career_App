"""
Plan Generation Service
Two-stage LLM + compressed personalized resource queries + resilient fallbacks
"""

import json
import logging
import math
import re
from typing import Dict, Any, List, Optional
from uuid import UUID

from features.career_builder.repositories.career_repository import CareerRepository
from features.career_builder.services.career_analysis_service import CareerAnalysisService
from features.career_builder.services.resource_search_service import ResourceSearchService
from features.career_builder.services.weekly_resource_orchestrator import WeeklyResourceOrchestrator
from shared.providers.llm_models.llm_provider import create_llm_provider

logger = logging.getLogger(__name__)


PLAN_STRUCTURE_PROMPT = """
You are a senior software engineering mentor designing a highly personalized weekly learning plan.

Generate ONLY the weekly plan structure.
DO NOT generate study_guide.
DO NOT generate resource_queries.
DO NOT include URLs.

==============================================================
CRITICAL: USER'S CONFIRMED SKILL LEVELS
==============================================================
The "current_level" in each skill entry is the USER'S CONFIRMED level.
Use it to:
1. Avoid redundant basics if the user already knows the skill
2. Keep weekly progression realistic
3. Match difficulty to the user's real level
4. Respect learning_mode and target_level exactly

==============================================================
RULES
==============================================================
1. Follow the SKILL SCHEDULE exactly
2. Keep exact same week numbers
3. Keep exact same focus skill for each allocated week
4. Topics must be specific, not generic
5. Descriptions must be concrete and action-oriented
6. learning_outcomes must contain exactly 2 items
7. Output VALID JSON only
8. No markdown, no comments, no explanations
9. Do NOT add extra braces or brackets
10. Final character must be }

==============================================================
WEEK 1 RULE FOR MISSED SKILLS
==============================================================
If learning_mode = "learn_from_scratch":
- Week 1 must stay beginner-level
- Week 1 must focus on fundamentals, mental model, basic setup
- No advanced or production-level content in week 1

==============================================================
PERSONALIZATION HINTS
==============================================================
For each week add:
- "guide_style": one of ["hands_on", "conceptual", "debugging", "architecture", "project_based"]
- "resource_focus": array of 2 to 4 short phrases describing what the resources should focus on
- "avoid_topics": array of 0 to 3 short phrases that should be avoided for this week/user

==============================================================
USER CONTEXT
==============================================================
Track: __TRACK_NAME__
Hours Available Per Week: __AVAILABLE_HOURS_PER_WEEK__ (__STUDY_INTENSITY__)
Total Plan Duration: __DURATION_WEEKS__ weeks
Planning Mode: __PLANNING_MODE__
User's Overall Confirmed Level: __CURRENT_AVERAGE_LEVEL__
Expected Final Level After Plan: __FINAL_EXPECTED_LEVEL__

==============================================================
SKILL SCHEDULE — FOLLOW EXACTLY
==============================================================
__SKILL_SCHEDULE_JSON__

==============================================================
OUTPUT JSON
==============================================================
{
  "plan_summary": "Short personalized summary",
  "improvement_summary": "Short explanation of expected growth",
  "weekly_breakdown": [
    {
      "week_number": 1,
      "focus_skills": ["SkillName"],
      "topic": "Specific topic title",
      "description": "Concrete description of what the user does this week",
      "learning_outcomes": ["Outcome 1", "Outcome 2"],
      "expected_level_after_week": "beginner",
      "guide_style": "hands_on",
      "resource_focus": ["phrase 1", "phrase 2"],
      "avoid_topics": ["phrase 1"]
    }
  ]
}
"""


STUDY_GUIDE_PROMPT = """
You are a senior software engineering mentor.

Generate ONLY a personalized study_guide JSON object for ONE specific week.

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

==============================================================
RULES
==============================================================
1. Return VALID JSON only
2. No markdown, comments, or explanation
3. Make the guide personalized to the user's level
4. If current_level is none/beginner, simplify and start from fundamentals
5. If current_level is intermediate/advanced, skip redundant basics
6. "how_to_study" must contain exactly 3 concrete steps
7. Final character must be }

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


class PlanGenerationService:
    LEVEL_VALUES = {
        "none": 0,
        "beginner": 1,
        "intermediate": 2,
        "advanced": 3,
    }

    LEVEL_NAMES = {
        0: "none",
        1: "beginner",
        2: "intermediate",
        3: "advanced",
    }

    TRACK_KEYWORDS = {
        "frontend": ["frontend", "ui", "browser", "component", "state", "responsive"],
        "backend": ["backend", "api", "database", "authentication", "server"],
        "full stack": ["frontend", "backend", "api", "database", "architecture"],
        "data science": ["data analysis", "machine learning", "statistics", "model evaluation"],
        "data analyst": ["sql", "dashboard", "reporting", "visualization"],
        "devops": ["docker", "kubernetes", "ci/cd", "deployment"],
        "mobile": ["android", "ios", "mobile", "performance"],
    }

    FALLBACK_DOCS_BY_SKILL = {
        "HTTP & Web Protocols": "https://developer.mozilla.org/en-US/docs/Web/HTTP",
        "API Authentication & Security": "https://fastapi.tiangolo.com/tutorial/security/",
        "Full Stack Project Architecture": "https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Server-side",
        "RESTful APIs Development": "https://fastapi.tiangolo.com/tutorial/",
        "Database Design": "https://www.postgresql.org/docs/",
        "SQL": "https://www.postgresql.org/docs/",
        "Pandas": "https://pandas.pydata.org/docs/",
        "NumPy": "https://numpy.org/doc/",
        "Matplotlib": "https://matplotlib.org/stable/users/index.html",
        "Feature Engineering": "https://scikit-learn.org/stable/modules/preprocessing.html",
        "Model Evaluation & Metrics": "https://scikit-learn.org/stable/modules/model_evaluation.html",
        "Seaborn": "https://seaborn.pydata.org/tutorial.html",
    }

    FALLBACK_DOCS_BY_TRACK = {
        "frontend": "https://developer.mozilla.org/",
        "backend": "https://fastapi.tiangolo.com/tutorial/",
        "full stack": "https://developer.mozilla.org/",
        "data science": "https://scikit-learn.org/stable/user_guide.html",
        "data analyst": "https://pandas.pydata.org/docs/",
        "devops": "https://docs.docker.com/",
        "mobile": "https://developer.android.com/guide",
    }

    def __init__(
        self,
        repository: CareerRepository,
        analysis_service: CareerAnalysisService,
    ):
        self.repo = repository
        self.analysis_service = analysis_service

        try:
            self.resource_search_service = ResourceSearchService()
            logger.info("ResourceSearchService initialized successfully")
        except Exception as e:
            logger.error("Failed to initialize ResourceSearchService: %s", e, exc_info=True)
            self.resource_search_service = None

        try:
            self.weekly_resource_orchestrator = WeeklyResourceOrchestrator(
                repository=self.repo,
                resource_search_service=self.resource_search_service,
            )
            logger.info("WeeklyResourceOrchestrator initialized successfully")
        except Exception as e:
            logger.error("Failed to initialize WeeklyResourceOrchestrator: %s", e, exc_info=True)
            self.weekly_resource_orchestrator = None

        try:
            self.llm = create_llm_provider()
            logger.info("LLM provider initialized successfully")
        except Exception as e:
            logger.error("Failed to initialize LLM provider: %s", e, exc_info=True)
            self.llm = None

    async def generate_plan(
        self,
        cv_id: UUID,
        track_id: int,
        duration_weeks: int,
        available_hours_per_week: Optional[int],
        user_level: Optional[str],
        requested_weeks: Optional[int] = None,
    ) -> Dict[str, Any]:
        if duration_weeks <= 0:
            raise ValueError("duration_weeks must be greater than 0")

        track = await self.repo.get_track_by_id(track_id)
        if not track:
            raise ValueError(f"Track not found: {track_id}")

        cached = await self.repo.get_analysis_cache(cv_id=cv_id, track_id=track_id)
        if not cached:
            raise ValueError("No analysis found. Call /analyze then /confirm first.")

        confirmed_learning_targets = cached.get("confirmed_learning_targets", []) or []
        if not confirmed_learning_targets:
            raise ValueError("No confirmed learning targets found. Call /confirm first.")

        track_name = track.get("track_name", "Unknown Track")
        skill_gaps = cached.get("skill_gaps", []) or []
        fit_analysis = cached.get("fit_analysis", {}) or {}
        realism = cached.get("realism", {}) or {}

        available_hours_per_week = (
            available_hours_per_week
            or cached.get("available_hours_per_week")
            or 6
        )
        requested_weeks = requested_weeks or duration_weeks

        study_intensity = self._classify_study_intensity(available_hours_per_week)
        latest_detected_skill_levels = self._rebuild_latest_skill_snapshot(skill_gaps)
        effective_user_level = self._resolve_effective_user_level(cached, user_level)
        current_level_info = self._calculate_current_track_level(skill_gaps)

        confirmed_level_from_cache = self._normalize_level(cached.get("level_used"))
        if self.LEVEL_VALUES.get(confirmed_level_from_cache, 0) > self.LEVEL_VALUES.get(
            current_level_info["current_average_level"], 0
        ):
            current_level_info["current_average_level"] = confirmed_level_from_cache

        zone = realism.get("zone", "suitable")
        can_generate_plan = fit_analysis.get("can_generate_plan", True)

        if can_generate_plan is False:
            planning_mode = "foundation_recovery_plan"
            used_learning_targets = self._filter_targets_foundation_recovery_mode(
                confirmed_learning_targets=confirmed_learning_targets,
                skill_gaps=skill_gaps,
            )
        elif zone in ("below_minimum", "minimum"):
            planning_mode = "minimum_plan"
            used_learning_targets = self._filter_targets_minimum_mode(
                confirmed_learning_targets=confirmed_learning_targets,
                requested_weeks=requested_weeks,
            )
        elif zone == "suitable":
            planning_mode = "suitable_plan"
            used_learning_targets = self._filter_targets_suitable_mode(
                confirmed_learning_targets=confirmed_learning_targets,
            )
        else:
            planning_mode = "maximum_plan"
            used_learning_targets = self._filter_targets_maximum_mode(
                confirmed_learning_targets=confirmed_learning_targets,
            )

        if not used_learning_targets:
            used_learning_targets = confirmed_learning_targets

        used_learning_targets = self._normalize_targets(used_learning_targets)

        skill_schedule = self._allocate_weeks_per_skill(
            used_learning_targets=used_learning_targets,
            total_weeks=duration_weeks,
            available_hours_per_week=available_hours_per_week,
        )

        raw_final_level_info = self._calculate_final_track_level(
            all_skill_gaps=skill_gaps,
            used_learning_targets=used_learning_targets,
        )

        minimum_allowed_level = current_level_info["current_average_level"]
        if self.LEVEL_VALUES.get(effective_user_level, 0) > self.LEVEL_VALUES.get(minimum_allowed_level, 0):
            minimum_allowed_level = effective_user_level

        final_level_info = self._apply_no_downgrade_guard(
            current_level_info=current_level_info,
            final_level_info=raw_final_level_info,
            detected_level=effective_user_level,
        )
        final_level_info = self._apply_planning_mode_level_cap(
            final_level_info=final_level_info,
            used_learning_targets=used_learning_targets,
            minimum_allowed_level=minimum_allowed_level,
        )

        structure_prompt = self._build_plan_structure_prompt(
            track_name=track_name,
            skill_schedule=skill_schedule,
            duration_weeks=duration_weeks,
            available_hours_per_week=available_hours_per_week,
            study_intensity=study_intensity,
            planning_mode=planning_mode,
            current_average_level=current_level_info["current_average_level"],
            final_expected_level=final_level_info["final_expected_level"],
        )

        logger.info(
            "Generating plan structure. mode=%s targets=%s weeks=%s hours=%s intensity=%s effective_user_level=%s",
            planning_mode,
            len(used_learning_targets),
            duration_weeks,
            available_hours_per_week,
            study_intensity,
            effective_user_level,
        )

        try:
            structure_data = await self._call_llm_for_json(
                prompt=structure_prompt,
                temperature=0.1,
                expecting_longer_output=True,
                failure_message="LLM structure generation failed",
            )

            weekly_breakdown = structure_data.get("weekly_breakdown", []) or []
            weekly_breakdown = self._soft_validate_and_fix_structure(
                weekly_breakdown=weekly_breakdown,
                skill_schedule=skill_schedule,
                duration_weeks=duration_weeks,
            )
            weekly_breakdown = self._reduce_weekly_repetition(
                weekly_breakdown=weekly_breakdown,
            )
            weekly_breakdown = self._enforce_weekly_expected_level_guard(
                weekly_breakdown=weekly_breakdown,
                used_learning_targets=used_learning_targets,
                duration_weeks=duration_weeks,
            )

            plan_data = {
                "plan_summary": structure_data.get("plan_summary") or self._build_fallback_plan_summary(
                    track_name=track_name,
                    duration_weeks=duration_weeks,
                    planning_mode=planning_mode,
                    final_expected_level=final_level_info["final_expected_level"],
                ),
                "improvement_summary": structure_data.get("improvement_summary") or (
                    "The plan prioritizes confirmed skill gaps first, then builds practical competence progressively."
                ),
                "weekly_breakdown": weekly_breakdown,
            }

        except Exception as e:
            logger.warning("LLM plan structure generation failed, using fallback. Reason: %s", e)
            plan_data = self._build_fallback_plan(
                track_name=track_name,
                skill_schedule=skill_schedule,
                duration_weeks=duration_weeks,
                planning_mode=planning_mode,
                final_expected_level=final_level_info["final_expected_level"],
            )

        weekly_breakdown = plan_data.get("weekly_breakdown", []) or []

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
                )
            except Exception as e:
                logger.warning(
                    "Study guide generation failed for week %s, using fallback. Reason: %s",
                    week.get("week_number"),
                    e,
                )
                study_guide = self._build_study_guide(
                    skill_name=(week.get("focus_skills") or ["General Skill"])[0],
                    subtopic_terms=week.get("topic", "Weekly topic"),
                    current_level=level_info.get("current_level", "none"),
                    target_level=level_info.get("target_level", "beginner"),
                    available_hours=available_hours_per_week,
                    guide_style=week.get("guide_style", "hands_on"),
                    resource_focus=week.get("resource_focus", []),
                )

            week["study_guide"] = study_guide

        track_keywords = self._build_track_keywords(track_name)

        for week in weekly_breakdown:
            level_info = self._infer_week_levels_from_topic(
                week=week,
                used_learning_targets=used_learning_targets,
            )

            resource_queries = self._build_resource_queries_for_week(
                week=week,
                current_level=level_info.get("current_level", "beginner"),
                target_level=level_info.get("target_level", "intermediate"),
                duration_weeks=duration_weeks,
                week_number=int(week.get("week_number", 1) or 1),
                all_used_learning_targets=used_learning_targets,
            )

            focus_skill = (week.get("focus_skills") or [None])[0]
            skill_id = None
            for target in used_learning_targets:
                if target.get("skill_name") == focus_skill:
                    skill_id = target.get("skill_id")
                    break

            if self.weekly_resource_orchestrator:
                try:
                    week_result = await self.weekly_resource_orchestrator.build_week_resources(
                        plan_id=None,
                        track_id=track_id,
                        track_name=track_name,
                        week=week,
                        resource_queries=resource_queries,
                        current_level=level_info.get("current_level", "beginner"),
                        target_level=level_info.get("target_level", "intermediate"),
                        available_hours_per_week=available_hours_per_week,
                        context_keywords=week.get("focus_skills", []) + track_keywords + week.get("resource_focus", []),
                        week_number=week.get("week_number"),
                        duration_weeks=duration_weeks,
                        skill_id=skill_id,
                        skill_name=focus_skill,
                    )
                    week["resources"] = week_result["resources"]
                    week["resource_validation_report"] = week_result["validation_report"]
                except Exception as e:
                    logger.warning("Weekly resource orchestration failed for week %s: %s", week.get("week_number"), e, exc_info=True)
                    fallback_resources = self._build_fallback_resources_for_week(
                        week=week,
                        track_name=track_name,
                        current_level=level_info.get("current_level", "beginner"),
                        target_level=level_info.get("target_level", "intermediate"),
                        available_hours_per_week=available_hours_per_week,
                    )
                    week["resources"] = self._dedupe_resources(fallback_resources, set())
                    week["resource_validation_report"] = {
                        "source": "local_fallback",
                        "resource_count": len(week["resources"]),
                        "expected_resource_count": self._expected_week_resource_count(available_hours_per_week),
                        "youtube_expected": self._expected_youtube_count(available_hours_per_week),
                        "resource_type_counts": self._resource_type_counts(week["resources"]),
                        "contract_passed": self._week_resources_meet_contract(
                            resources=week["resources"],
                            available_hours_per_week=available_hours_per_week,
                        ),
                    }
            else:
                fallback_resources = self._build_fallback_resources_for_week(
                    week=week,
                    track_name=track_name,
                    current_level=level_info.get("current_level", "beginner"),
                    target_level=level_info.get("target_level", "intermediate"),
                    available_hours_per_week=available_hours_per_week,
                )
                week["resources"] = self._dedupe_resources(fallback_resources, set())
                week["resource_validation_report"] = {
                    "source": "local_fallback",
                    "resource_count": len(week["resources"]),
                    "expected_resource_count": self._expected_week_resource_count(available_hours_per_week),
                    "youtube_expected": self._expected_youtube_count(available_hours_per_week),
                    "resource_type_counts": self._resource_type_counts(week["resources"]),
                    "contract_passed": self._week_resources_meet_contract(
                        resources=week["resources"],
                        available_hours_per_week=available_hours_per_week,
                    ),
                }

            week.pop("resource_focus", None)
            week.pop("avoid_topics", None)
            week.pop("guide_style", None)

        plan_data["weekly_breakdown"] = weekly_breakdown

        return {
            "cv_id": str(cv_id),
            "track_id": track_id,
            "track_name": track_name,
            "duration_weeks": duration_weeks,
            "available_hours_per_week": available_hours_per_week,
            "planning_mode": planning_mode,
            "study_intensity": study_intensity,
            "current_average_level": current_level_info["current_average_level"],
            "final_expected_level": final_level_info["final_expected_level"],
            "latest_detected_skill_levels": latest_detected_skill_levels,
            "used_learning_targets": used_learning_targets,
            "deferred_learning_targets": [],
            "generation_metadata": {
                "zone": zone,
                "effective_user_level": effective_user_level,
                "can_generate_plan": can_generate_plan,
                "resource_personalization": True,
                "cumulative_mode": True,
                "smart_resource_sequencing": True,
                "global_resource_dedupe": False,
                "two_stage_llm": True,
                "weekly_resource_contract": True,
            },
            **plan_data,
        }

    # ============================================================
    # NEW weekly resource contract helpers
    # ============================================================

    def _expected_youtube_count(self, available_hours_per_week: int) -> int:
        return 1 if (available_hours_per_week or 6) <= 6 else 3

    def _expected_week_resource_count(self, available_hours_per_week: int) -> int:
        return 3 + self._expected_youtube_count(available_hours_per_week)

    def _resource_type_counts(self, resources: List[Dict[str, Any]]) -> Dict[str, int]:
        counts = {
            "docs": 0,
            "article": 0,
            "youtube": 0,
            "practice": 0,
            "project": 0,
        }

        for resource in resources or []:
            r_type = (resource.get("type") or "").strip().lower()
            if r_type in counts:
                counts[r_type] += 1

        return counts

    def _week_resources_meet_contract(
        self,
        resources: List[Dict[str, Any]],
        available_hours_per_week: int,
    ) -> bool:
        counts = self._resource_type_counts(resources)
        expected_youtube = self._expected_youtube_count(available_hours_per_week)

        has_docs = counts["docs"] >= 1 or counts["article"] >= 1
        has_practice = counts["practice"] >= 1
        has_project = counts["project"] >= 1
        has_youtube = counts["youtube"] >= expected_youtube

        return has_docs and has_practice and has_project and has_youtube

    def _merge_and_fill_week_resources(
        self,
        primary: List[Dict[str, Any]],
        fallback: List[Dict[str, Any]],
        available_hours_per_week: int,
    ) -> List[Dict[str, Any]]:
        expected_youtube = self._expected_youtube_count(available_hours_per_week)

        merged = []
        seen_urls = set()

        for group in [primary or [], fallback or []]:
            for item in group:
                url = (item.get("url") or "").strip().lower()
                if not url:
                    continue
                if url in seen_urls:
                    continue
                seen_urls.add(url)
                merged.append(item)

        def take_by_type(resource_type: str, count: int) -> List[Dict[str, Any]]:
            selected = []
            for item in merged:
                if (item.get("type") or "").strip().lower() == resource_type:
                    selected.append(item)
                if len(selected) >= count:
                    break
            return selected

        final = []

        docs_candidates = take_by_type("docs", 1)
        if not docs_candidates:
            docs_candidates = take_by_type("article", 1)
        final.extend(docs_candidates[:1])

        final.extend(take_by_type("practice", 1))
        final.extend(take_by_type("project", 1))
        final.extend(take_by_type("youtube", expected_youtube))

        expected_total = self._expected_week_resource_count(available_hours_per_week)
        for item in merged:
            if item in final:
                continue
            final.append(item)
            if len(final) >= expected_total:
                break

        return final[:expected_total]

    # ============================================================
    # LLM helpers
    # ============================================================

    async def _call_llm_for_json(
        self,
        prompt: str,
        temperature: float = 0.2,
        expecting_longer_output: bool = False,
        failure_message: str = "LLM call failed",
    ) -> Dict[str, Any]:
        if not self.llm:
            raise ValueError("LLM provider is unavailable")

        response = await self.llm.get_response(
            prompt=prompt,
            need_json_output=True,
            expecting_longer_output=expecting_longer_output,
            temperature=temperature,
        )

        if response is None:
            raise ValueError(f"{failure_message}: provider returned None")
        if response == "":
            raise ValueError(f"{failure_message}: provider returned empty string")

        return response if isinstance(response, dict) else self._safe_parse_json(response)

    async def _generate_personalized_study_guide_for_week(
        self,
        track_name: str,
        week: Dict[str, Any],
        current_level: str,
        target_level: str,
        available_hours_per_week: int,
    ) -> Dict[str, Any]:
        prompt = self._build_study_guide_prompt(
            track_name=track_name,
            week=week,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
        )

        data = await self._call_llm_for_json(
            prompt=prompt,
            temperature=0.2,
            expecting_longer_output=False,
            failure_message="LLM study guide generation failed",
        )

        study_guide = data.get("study_guide")
        if not isinstance(study_guide, dict):
            raise ValueError("Invalid study_guide JSON structure")
        return study_guide

    # ============================================================
    # normalization / state
    # ============================================================

    def _normalize_level(self, level: Optional[str]) -> str:
        normalized = (level or "").strip().lower()
        return normalized if normalized in self.LEVEL_VALUES else ""

    def _resolve_effective_user_level(self, cached: Dict[str, Any], user_level: Optional[str]) -> str:
        return (
            self._normalize_level(cached.get("level_used"))
            or self._normalize_level(user_level)
            or self._normalize_level(cached.get("detected_level"))
            or "beginner"
        )

    def _rebuild_latest_skill_snapshot(self, skill_gaps: List[Dict[str, Any]]) -> Dict[str, str]:
        return {
            gap.get("skill_name"): self._normalize_level(gap.get("current_level")) or "none"
            for gap in skill_gaps
            if gap.get("skill_name")
        }

    def _normalize_track_name(self, track_name: Optional[str]) -> str:
        return " ".join((track_name or "").strip().lower().split())

    def _build_track_keywords(self, track_name: Optional[str]) -> List[str]:
        normalized = self._normalize_track_name(track_name)
        for key, values in self.TRACK_KEYWORDS.items():
            if key in normalized:
                return values
        return []

    def _classify_study_intensity(self, hours: int) -> str:
        if hours <= 5:
            return "light"
        if hours <= 10:
            return "moderate"
        return "intensive"

    # ============================================================
    # target filtering
    # ============================================================

    def _normalize_targets(self, targets: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        normalized_targets = []

        for target in targets:
            current_level = self._normalize_level(target.get("current_level")) or "none"
            target_level = self._normalize_level(target.get("target_level")) or "beginner"

            normalized_targets.append({
                **target,
                "current_level": current_level,
                "target_level": target_level,
                "learning_mode": "learn_from_scratch" if current_level == "none" else target.get("learning_mode", "level_up"),
                "selected_by_user": bool(target.get("selected_by_user", False)),
                "is_core": bool(target.get("is_core", True)),
                "required_weeks": int(target.get("required_weeks", 4) or 4),
                "importance_weight": int(target.get("importance_weight", 3) or 3),
            })

        return normalized_targets

    def _filter_targets_foundation_recovery_mode(
        self,
        confirmed_learning_targets: List[Dict[str, Any]],
        skill_gaps: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        severe = []
        selected_map = {t.get("skill_id"): t for t in confirmed_learning_targets}

        for gap in skill_gaps:
            if gap.get("status") == "missing" or float(gap.get("gap_score", 0)) >= 0.75:
                skill_id = gap.get("skill_id")
                if skill_id in selected_map:
                    severe.append(selected_map[skill_id])

        return severe[:max(1, min(4, len(severe)))]

    def _filter_targets_minimum_mode(
        self,
        confirmed_learning_targets: List[Dict[str, Any]],
        requested_weeks: int,
    ) -> List[Dict[str, Any]]:
        selected_targets = [t for t in confirmed_learning_targets if t.get("selected_by_user") is True]
        if selected_targets:
            ranked = sorted(
                selected_targets,
                key=lambda t: (
                    -int(t.get("importance_weight", 3) or 3),
                    -float(self._estimate_gap_score_for_target(t)),
                    int(t.get("required_weeks", 4) or 4),
                ),
            )
            capacity = max(1, min(len(ranked), math.ceil(requested_weeks / 2)))
            return ranked[:capacity]

        ranked = sorted(
            confirmed_learning_targets,
            key=lambda t: (
                -int(t.get("importance_weight", 3) or 3),
                -float(self._estimate_gap_score_for_target(t)),
            ),
        )
        return ranked[:max(1, min(len(ranked), math.ceil(requested_weeks / 2)))]

    def _filter_targets_suitable_mode(
        self,
        confirmed_learning_targets: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        selected = [t for t in confirmed_learning_targets if t.get("selected_by_user") is True]
        owned_core = [
            t for t in confirmed_learning_targets
            if t.get("selected_by_user") is not True and t.get("is_core") is True
        ]
        return selected + owned_core

    def _filter_targets_maximum_mode(
        self,
        confirmed_learning_targets: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        return list(confirmed_learning_targets)

    def _estimate_gap_score_for_target(self, target: Dict[str, Any]) -> float:
        current = self.LEVEL_VALUES.get(self._normalize_level(target.get("current_level")) or "none", 0)
        target_value = self.LEVEL_VALUES.get(self._normalize_level(target.get("target_level")) or "beginner", 1)
        if current >= target_value:
            return 0.0
        return (target_value - current) / max(target_value, 1)

    # ============================================================
    # level summary / guards
    # ============================================================

    def _calculate_current_track_level(self, skill_gaps: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not skill_gaps:
            return {"current_average_level": "beginner", "avg_value": 1.0}

        values = []
        for gap in skill_gaps:
            lvl = self._normalize_level(gap.get("current_level")) or "none"
            values.append(self.LEVEL_VALUES.get(lvl, 0))

        avg = sum(values) / max(len(values), 1)
        if avg >= 2.5:
            name = "advanced"
        elif avg >= 1.5:
            name = "intermediate"
        elif avg > 0:
            name = "beginner"
        else:
            name = "none"

        return {"current_average_level": name, "avg_value": round(avg, 2)}

    def _calculate_final_track_level(
        self,
        all_skill_gaps: List[Dict[str, Any]],
        used_learning_targets: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        updated_values = []
        target_map = {t.get("skill_id"): t for t in used_learning_targets}

        for gap in all_skill_gaps:
            skill_id = gap.get("skill_id")
            current_level = self._normalize_level(gap.get("current_level")) or "none"

            if skill_id in target_map:
                updated_level = self._normalize_level(target_map[skill_id].get("target_level")) or current_level
            else:
                updated_level = current_level

            updated_values.append(self.LEVEL_VALUES.get(updated_level, 0))

        if not updated_values:
            return {"final_expected_level": "beginner", "avg_value": 1.0}

        avg = sum(updated_values) / len(updated_values)
        if avg >= 2.5:
            level = "advanced"
        elif avg >= 1.5:
            level = "intermediate"
        elif avg > 0:
            level = "beginner"
        else:
            level = "none"

        return {"final_expected_level": level, "avg_value": round(avg, 2)}

    def _apply_no_downgrade_guard(
        self,
        current_level_info: Dict[str, Any],
        final_level_info: Dict[str, Any],
        detected_level: str,
    ) -> Dict[str, Any]:
        current = self.LEVEL_VALUES.get(
            self._normalize_level(current_level_info.get("current_average_level")) or "none", 0
        )
        detected = self.LEVEL_VALUES.get(self._normalize_level(detected_level) or "none", 0)
        minimum = max(current, detected)

        final_value = self.LEVEL_VALUES.get(
            self._normalize_level(final_level_info.get("final_expected_level")) or "none", 0
        )
        if final_value < minimum:
            final_level_info["final_expected_level"] = self.LEVEL_NAMES[minimum]
            final_level_info["avg_value"] = max(final_level_info.get("avg_value", 0), float(minimum))
        return final_level_info

    def _apply_planning_mode_level_cap(
        self,
        final_level_info: Dict[str, Any],
        used_learning_targets: List[Dict[str, Any]],
        minimum_allowed_level: str,
    ) -> Dict[str, Any]:
        if not used_learning_targets:
            final_level_info["final_expected_level"] = minimum_allowed_level
            return final_level_info

        max_target = max(
            self.LEVEL_VALUES.get(self._normalize_level(t.get("target_level")) or "beginner", 1)
            for t in used_learning_targets
        )
        min_allowed = self.LEVEL_VALUES.get(self._normalize_level(minimum_allowed_level) or "beginner", 1)
        current = self.LEVEL_VALUES.get(
            self._normalize_level(final_level_info.get("final_expected_level")) or "beginner", 1
        )

        current = max(current, min_allowed)
        current = min(current, max_target)
        final_level_info["final_expected_level"] = self.LEVEL_NAMES[current]
        return final_level_info

    # ============================================================
    # scheduling
    # ============================================================

    def _allocate_weeks_per_skill(
        self,
        used_learning_targets: List[Dict[str, Any]],
        total_weeks: int,
        available_hours_per_week: int,
    ) -> List[Dict[str, Any]]:
        if not used_learning_targets:
            raise ValueError("used_learning_targets is empty")

        weighted_scores = []
        for target in used_learning_targets:
            current_value = self.LEVEL_VALUES.get(target["current_level"], 0)
            target_value = self.LEVEL_VALUES.get(target["target_level"], 1)
            gap_steps = max(1, target_value - current_value)
            importance = int(target.get("importance_weight", 3) or 3)
            required_weeks = int(target.get("required_weeks", 4) or 4)
            selected_bonus = 1.3 if target.get("selected_by_user") else 1.0
            core_bonus = 1.15 if target.get("is_core") else 1.0
            score = gap_steps * importance * required_weeks * selected_bonus * core_bonus
            weighted_scores.append(score)

        total_score = sum(weighted_scores) or 1.0

        allocations = []
        for idx, _target in enumerate(used_learning_targets):
            raw = (weighted_scores[idx] / total_score) * total_weeks
            allocated = max(1, int(round(raw)))
            allocations.append(allocated)

        while sum(allocations) > total_weeks:
            max_idx = max(range(len(allocations)), key=lambda i: allocations[i])
            if allocations[max_idx] > 1:
                allocations[max_idx] -= 1
            else:
                break

        while sum(allocations) < total_weeks:
            max_idx = max(range(len(allocations)), key=lambda i: weighted_scores[i])
            allocations[max_idx] += 1

        week_cursor = 1
        schedule = []
        for target, allocated_weeks in zip(used_learning_targets, allocations):
            week_numbers = list(range(week_cursor, week_cursor + allocated_weeks))
            subtopic_guide = self._build_subtopic_guide(
                skill_name=target["skill_name"],
                current_level=target["current_level"],
                target_level=target["target_level"],
                learning_mode=target["learning_mode"],
                allocated_weeks=allocated_weeks,
            )
            schedule.append({
                **target,
                "allocated_weeks": allocated_weeks,
                "week_numbers": week_numbers,
                "subtopic_guide": subtopic_guide,
            })
            week_cursor += allocated_weeks

        return schedule

    def _build_subtopic_guide(
        self,
        skill_name: str,
        current_level: str,
        target_level: str,
        learning_mode: str,
        allocated_weeks: int,
    ) -> List[Dict[str, Any]]:
        guides = []

        for week_offset in range(1, allocated_weeks + 1):
            stage_ratio = week_offset / max(allocated_weeks, 1)

            if learning_mode == "learn_from_scratch":
                if week_offset == 1:
                    expected_level = "beginner"
                    subtopic_focus = f"{skill_name} fundamentals"
                elif stage_ratio <= 0.35:
                    expected_level = "beginner"
                    subtopic_focus = f"{skill_name} core workflows"
                elif stage_ratio <= 0.70:
                    expected_level = "beginner" if target_level == "beginner" else "intermediate"
                    subtopic_focus = f"{skill_name} applied practice"
                else:
                    expected_level = "intermediate" if target_level in ("intermediate", "advanced") else "beginner"
                    subtopic_focus = f"{skill_name} mini case studies and implementation"
            else:
                current_value = self.LEVEL_VALUES.get(current_level, 0)
                target_value = self.LEVEL_VALUES.get(target_level, 1)

                if current_value >= target_value:
                    expected_level = current_level
                    subtopic_focus = f"{skill_name} reinforcement and best practices"
                elif current_level == "beginner" and target_level == "intermediate":
                    expected_level = "beginner" if week_offset == 1 else "intermediate"
                    subtopic_focus = (
                        f"{skill_name} transition beyond basics"
                        if week_offset == 1
                        else f"{skill_name} deeper workflows"
                    )
                elif current_level == "intermediate" and target_level == "advanced":
                    expected_level = "intermediate" if week_offset <= 2 else "advanced"
                    subtopic_focus = (
                        f"{skill_name} advanced concepts"
                        if stage_ratio <= 0.50
                        else f"{skill_name} production patterns"
                    )
                else:
                    expected_level = target_level
                    subtopic_focus = f"{skill_name} focused progression"

            guides.append({
                "week_offset": week_offset,
                "subtopic_focus": subtopic_focus,
                "expected_level": expected_level,
            })

        return guides

    # ============================================================
    # prompts
    # ============================================================

    def _build_plan_structure_prompt(
        self,
        track_name: str,
        skill_schedule: List[Dict[str, Any]],
        duration_weeks: int,
        available_hours_per_week: int,
        study_intensity: str,
        planning_mode: str,
        current_average_level: str,
        final_expected_level: str,
    ) -> str:
        compact_schedule = []

        for item in skill_schedule:
            compact_schedule.append({
                "skill_id": item.get("skill_id"),
                "skill_name": item.get("skill_name"),
                "current_level": item.get("current_level"),
                "target_level": item.get("target_level"),
                "learning_mode": item.get("learning_mode"),
                "selected_by_user": item.get("selected_by_user"),
                "allocated_weeks": item.get("allocated_weeks"),
                "week_numbers": item.get("week_numbers"),
                "subtopic_guide": item.get("subtopic_guide"),
            })

        prompt = PLAN_STRUCTURE_PROMPT
        prompt = prompt.replace("__TRACK_NAME__", str(track_name))
        prompt = prompt.replace("__AVAILABLE_HOURS_PER_WEEK__", str(available_hours_per_week))
        prompt = prompt.replace("__STUDY_INTENSITY__", str(study_intensity))
        prompt = prompt.replace("__DURATION_WEEKS__", str(duration_weeks))
        prompt = prompt.replace("__PLANNING_MODE__", str(planning_mode))
        prompt = prompt.replace("__CURRENT_AVERAGE_LEVEL__", str(current_average_level))
        prompt = prompt.replace("__FINAL_EXPECTED_LEVEL__", str(final_expected_level))
        prompt = prompt.replace(
            "__SKILL_SCHEDULE_JSON__",
            json.dumps(compact_schedule, ensure_ascii=False, indent=2),
        )
        return prompt

    def _build_study_guide_prompt(
        self,
        track_name: str,
        week: Dict[str, Any],
        current_level: str,
        target_level: str,
        available_hours_per_week: int,
    ) -> str:
        prompt = STUDY_GUIDE_PROMPT
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
        return prompt

    # ============================================================
    # validation / repair
    # ============================================================

    def _soft_validate_and_fix_structure(
        self,
        weekly_breakdown: List[Dict[str, Any]],
        skill_schedule: List[Dict[str, Any]],
        duration_weeks: int,
    ) -> List[Dict[str, Any]]:
        if not weekly_breakdown:
            return self._build_fallback_plan(
                track_name="Unknown Track",
                skill_schedule=skill_schedule,
                duration_weeks=duration_weeks,
            )["weekly_breakdown"]

        schedule_by_week = {}
        for entry in skill_schedule:
            for guide in entry.get("subtopic_guide", []):
                week_number = entry["week_numbers"][guide["week_offset"] - 1]
                schedule_by_week[week_number] = {
                    "skill_name": entry["skill_name"],
                    "expected_level": guide["expected_level"],
                    "subtopic_focus": guide["subtopic_focus"],
                    "current_level": entry["current_level"],
                    "target_level": entry["target_level"],
                }

        fixed = []
        seen_week_numbers = set()

        for week in weekly_breakdown:
            week_number = int(week.get("week_number", len(fixed) + 1) or len(fixed) + 1)
            if week_number in seen_week_numbers or week_number < 1 or week_number > duration_weeks:
                continue
            seen_week_numbers.add(week_number)

            ref = schedule_by_week.get(week_number, {})
            focus_skill = ref.get("skill_name") or (week.get("focus_skills") or ["General Skill"])[0]

            topic = (week.get("topic") or "").strip() or ref.get("subtopic_focus") or f"{focus_skill} applied implementation"
            description = (week.get("description") or "").strip() or (
                f"Build practical confidence in {focus_skill} through guided exercises and realistic implementation."
            )
            outcomes = week.get("learning_outcomes", []) or [
                f"Understand the weekly focus in {focus_skill}",
                f"Apply {focus_skill} in a practical task",
            ]
            expected = self._normalize_level(week.get("expected_level_after_week")) or ref.get("expected_level") or "beginner"
            guide_style = (week.get("guide_style") or "").strip() or self._infer_guide_style(
                current_level=ref.get("current_level", "none"),
                target_level=ref.get("target_level", "beginner"),
                topic=topic,
            )

            resource_focus = week.get("resource_focus")
            if not isinstance(resource_focus, list) or not resource_focus:
                resource_focus = self._infer_resource_focus(topic=topic, skill_name=focus_skill)

            avoid_topics = week.get("avoid_topics")
            if not isinstance(avoid_topics, list):
                avoid_topics = []

            fixed.append({
                "week_number": week_number,
                "focus_skills": week.get("focus_skills") or [focus_skill],
                "topic": topic,
                "description": description,
                "learning_outcomes": outcomes[:2],
                "expected_level_after_week": expected,
                "guide_style": guide_style,
                "resource_focus": resource_focus[:4],
                "avoid_topics": avoid_topics[:3],
            })

        for week_number in range(1, duration_weeks + 1):
            if week_number not in seen_week_numbers:
                ref = schedule_by_week.get(week_number, {})
                focus_skill = ref.get("skill_name", "General Skill")
                topic = ref.get("subtopic_focus", f"{focus_skill} applied implementation")

                fixed.append({
                    "week_number": week_number,
                    "focus_skills": [focus_skill],
                    "topic": topic,
                    "description": f"Progress in {focus_skill} with a realistic sequence of study and application.",
                    "learning_outcomes": [
                        f"Understand the main idea in {focus_skill}",
                        f"Apply it in a practical workflow",
                    ],
                    "expected_level_after_week": ref.get("expected_level", "beginner"),
                    "guide_style": self._infer_guide_style(
                        current_level=ref.get("current_level", "none"),
                        target_level=ref.get("target_level", "beginner"),
                        topic=topic,
                    ),
                    "resource_focus": self._infer_resource_focus(topic=topic, skill_name=focus_skill),
                    "avoid_topics": [],
                })

        fixed.sort(key=lambda x: x["week_number"])
        return fixed

    def _reduce_weekly_repetition(
        self,
        weekly_breakdown: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        seen_topics = set()
        for idx, week in enumerate(weekly_breakdown, 1):
            topic = (week.get("topic") or "").strip()
            if topic.lower() in seen_topics:
                week["topic"] = f"{topic} — applied progression variant {idx}"
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
            current_value = self.LEVEL_VALUES.get(target["current_level"], 0)
            target_value = self.LEVEL_VALUES.get(target["target_level"], 1)
            week_value = self.LEVEL_VALUES.get(
                self._normalize_level(week.get("expected_level_after_week")) or "beginner",
                1,
            )

            week_number = int(week.get("week_number", 1) or 1)
            stage_ratio = week_number / max(duration_weeks, 1)

            if target["learning_mode"] == "learn_from_scratch" and week_number == 1:
                week["expected_level_after_week"] = "beginner"
                continue

            if week_value < current_value:
                week["expected_level_after_week"] = target["current_level"]

            if week_value > target_value:
                week["expected_level_after_week"] = target["target_level"]

            if current_value == 0 and stage_ratio < 0.35 and week_value > 1:
                week["expected_level_after_week"] = "beginner"

        return weekly_breakdown

    # ============================================================
    # guide / resources
    # ============================================================

    def _infer_guide_style(
        self,
        current_level: str,
        target_level: str,
        topic: str,
    ) -> str:
        current_value = self.LEVEL_VALUES.get(current_level or "none", 0)
        target_value = self.LEVEL_VALUES.get(target_level or "beginner", 1)
        topic_lower = (topic or "").lower()

        if "architecture" in topic_lower or "system design" in topic_lower:
            return "architecture"
        if "debug" in topic_lower or "error" in topic_lower or "fix" in topic_lower:
            return "debugging"
        if current_value == 0:
            return "hands_on"
        if target_value > current_value:
            return "project_based"
        return "conceptual"

    def _infer_resource_focus(self, topic: str, skill_name: str) -> List[str]:
        words = re.findall(r"[A-Za-z0-9\-\+\/#\.]+", topic or "")
        blocked = {
            "week", "with", "from", "toward", "using", "through", "their", "this",
            "that", "real", "world", "problem", "solving", "fundamentals", "applied",
            "implementation", "challenges", "mini", "case", "studies", "core", "mental", "model"
        }
        result = []
        seen = set()

        for word in words:
            clean = word.strip().lower()
            if len(clean) < 4 or clean in blocked:
                continue
            if clean in seen:
                continue
            seen.add(clean)
            result.append(word)

        if not result:
            result = [skill_name]

        return result[:4]

    def _build_study_guide(
        self,
        skill_name: str,
        subtopic_terms: str,
        current_level: str,
        target_level: str,
        available_hours: int,
        guide_style: str = "hands_on",
        resource_focus: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        resource_focus = resource_focus or []

        current_value = self.LEVEL_VALUES.get(current_level, 0)
        target_value = self.LEVEL_VALUES.get(target_level, 1)

        if current_value == 0:
            time_split = {
                "reading_study": "35%",
                "hands_on_coding": "45%",
                "project_integration": "20%",
            }
        elif target_value > current_value:
            time_split = {
                "reading_study": "25%",
                "hands_on_coding": "50%",
                "project_integration": "25%",
            }
        else:
            time_split = {
                "reading_study": "20%",
                "hands_on_coding": "40%",
                "project_integration": "40%",
            }

        if guide_style == "architecture":
            how_to_study = [
                f"1. Review the system-level model behind {subtopic_terms}",
                f"2. Sketch components and trade-offs using {skill_name}",
                f"3. Implement or refactor one realistic architecture slice",
            ]
        elif guide_style == "debugging":
            how_to_study = [
                f"1. Review the main workflow in {subtopic_terms}",
                f"2. Reproduce one realistic failure case related to {skill_name}",
                f"3. Debug and fix the implementation",
            ]
        elif guide_style == "project_based":
            how_to_study = [
                f"1. Review the exact technique behind {subtopic_terms}",
                f"2. Build a small feature or workflow using {skill_name}",
                f"3. Integrate it into a mini-project and reflect on trade-offs",
            ]
        elif guide_style == "conceptual":
            how_to_study = [
                f"1. Build a clear conceptual model of {subtopic_terms}",
                f"2. Compare examples and counter-examples using {skill_name}",
                f"3. Apply the concept in a short practical task",
            ]
        else:
            how_to_study = [
                f"1. Learn the mental model and core concepts behind {subtopic_terms}",
                f"2. Recreate small examples using {skill_name}",
                f"3. Solve focused tasks that force you to use the core workflow",
            ]

        what_to_study = [
            f"Core technique: {subtopic_terms}",
            f"Target: {skill_name} at {target_level} level",
        ]
        if resource_focus:
            what_to_study.append(f"Emphasis: {', '.join(resource_focus[:3])}")

        return {
            "what_to_study": what_to_study,
            "how_to_study": how_to_study,
            "time_split": time_split,
        }

    def _week_resource_sequence_hint(
        self,
        week_number: int,
        duration_weeks: int,
        current_level: str,
        target_level: str,
    ) -> str:
        ratio = week_number / max(duration_weeks, 1)
        current_level = self._normalize_level(current_level) or "none"
        target_level = self._normalize_level(target_level) or current_level

        if current_level == "none":
            if ratio <= 0.25:
                return "beginner fundamentals"
            if ratio <= 0.55:
                return "practical workflow"
            if ratio <= 0.80:
                return "applied examples"
            return "mini project"

        if current_level == "beginner" and target_level in ("intermediate", "advanced"):
            if ratio <= 0.35:
                return "intermediate transition"
            if ratio <= 0.75:
                return "real-world examples"
            return "case studies"

        if current_level == "intermediate" and target_level == "advanced":
            if ratio <= 0.40:
                return "advanced concepts"
            if ratio <= 0.80:
                return "production patterns"
            return "architecture case study"

        return "practical examples"

    def _build_resource_queries_for_week(
        self,
        week: Dict[str, Any],
        current_level: str,
        target_level: str,
        duration_weeks: int,
        week_number: int,
        all_used_learning_targets: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        focus_skill = (week.get("focus_skills") or ["General Skill"])[0]
        topic = week.get("topic", focus_skill)
        resource_focus = week.get("resource_focus", []) or []
        expected_level = self._normalize_level(week.get("expected_level_after_week")) or target_level or "beginner"
        sequence_hint = self._week_resource_sequence_hint(
            week_number=week_number,
            duration_weeks=duration_weeks,
            current_level=current_level,
            target_level=target_level,
        )

        related_known_skills = []
        for target in all_used_learning_targets:
            if target.get("skill_name") == focus_skill:
                continue
            lvl = self._normalize_level(target.get("current_level")) or "none"
            if self.LEVEL_VALUES.get(lvl, 0) >= 1:
                related_known_skills.append(target.get("skill_name"))

        related_hint = related_known_skills[0] if related_known_skills else ""
        focus_hint = " ".join(resource_focus[:2]).strip()

        base_docs = self._compress_query(
            f"{focus_skill} {topic} {expected_level} {sequence_hint} {focus_hint}".strip()
        )
        base_video = self._compress_query(
            f"{focus_skill} {topic} {expected_level} tutorial {sequence_hint}".strip()
        )
        base_practice = self._compress_query(
            f"{focus_skill} {topic} hands-on exercises notebook practice {focus_hint} {related_hint}".strip()
        )
        base_project = self._compress_query(
            f"{focus_skill} {topic} project example github repo {related_hint}".strip()
        )

        return [
            {
                "title": f"{focus_skill} docs",
                "query": base_docs,
                "type": "docs",
            },
            {
                "title": f"{focus_skill} practice",
                "query": base_practice,
                "type": "practice",
            },
            {
                "title": f"{focus_skill} project",
                "query": base_project,
                "type": "project",
            },
            {
                "title": f"{focus_skill} video",
                "query": base_video,
                "type": "youtube",
            },
        ]

    def _compress_query(self, text: str, max_words: int = 16) -> str:
        words = []
        seen = set()

        for token in re.split(r"\s+", (text or "").strip()):
            clean = token.strip()
            if not clean:
                continue

            key = clean.lower()
            if key in seen:
                continue

            seen.add(key)
            words.append(clean)

            if len(words) >= max_words:
                break

        return " ".join(words)

    def _dedupe_resources(
        self,
        resources: List[Dict[str, Any]],
        global_seen_urls: set,
    ) -> List[Dict[str, Any]]:
        final = []
        for resource in resources or []:
            url = (resource.get("url") or "").strip().lower()
            if url and url in global_seen_urls:
                continue
            if url:
                global_seen_urls.add(url)
            final.append(resource)
        return final

    def _fallback_doc_url(self, skill_name: str, track_name: str) -> str:
        if skill_name in self.FALLBACK_DOCS_BY_SKILL:
            return self.FALLBACK_DOCS_BY_SKILL[skill_name]

        normalized = self._normalize_track_name(track_name)
        for key, url in self.FALLBACK_DOCS_BY_TRACK.items():
            if key in normalized:
                return url

        return "https://developer.mozilla.org/"

    def _build_fallback_resources_for_week(
        self,
        week: Dict[str, Any],
        track_name: str,
        current_level: str,
        target_level: str,
        available_hours_per_week: int,
    ) -> List[Dict[str, Any]]:
        topic = week.get("topic", "Weekly Topic")
        skill = (week.get("focus_skills") or ["General Skill"])[0]
        doc_url = self._fallback_doc_url(skill_name=skill, track_name=track_name)
        youtube_needed = self._expected_youtube_count(available_hours_per_week)

        resources = [
            {
                "title": f"{topic} official docs",
                "url": doc_url,
                "type": "docs",
                "snippet": f"Fallback official docs for {skill}",
                "duration": "30 min",
                "score": 9.0,
            },
            {
                "title": f"{topic} practice notebook",
                "url": "https://www.kaggle.com/learn",
                "type": "practice",
                "snippet": f"Fallback practice resource for {skill}",
                "duration": "2 hours",
                "score": 8.5,
            },
            {
                "title": f"{topic} project example",
                "url": "https://github.com/search?q=topic:programming&sort=stars&type=repositories",
                "type": "project",
                "snippet": f"Fallback project resource for {skill}",
                "duration": "full course",
                "score": 8.0,
            },
        ]

        for idx in range(1, youtube_needed + 1):
            resources.append({
                "title": f"{topic} tutorial video {idx}",
                "url": f"https://www.youtube.com/results?search_query={topic.replace(' ', '+')}&sp=CAI%253D",
                "type": "youtube",
                "snippet": f"Fallback tutorial search for {skill}",
                "duration": "10 min",
                "youtube_duration_minutes": 10,
                "score": 7.5,
            })

        return resources

    # ============================================================
    # fallback plan
    # ============================================================

    def _build_fallback_plan_summary(
        self,
        track_name: str,
        duration_weeks: int,
        planning_mode: str,
        final_expected_level: str,
    ) -> str:
        return (
            f"This {duration_weeks}-week {planning_mode.replace('_', ' ')} plan for {track_name} "
            f"focuses on the user's confirmed learning targets and progresses toward {final_expected_level}."
        )

    def _build_fallback_plan(
        self,
        track_name: str,
        skill_schedule: List[Dict[str, Any]],
        duration_weeks: int,
        planning_mode: str = "full_plan",
        final_expected_level: str = "beginner",
    ) -> Dict[str, Any]:
        if not skill_schedule:
            raise ValueError("Cannot build fallback plan without skill_schedule")

        weeks = []

        for entry in skill_schedule:
            skill_name = entry["skill_name"]
            current_level = entry["current_level"]
            target_level = entry["target_level"]

            for guide in entry["subtopic_guide"]:
                week_number = entry["week_numbers"][guide["week_offset"] - 1]
                subtopic = guide["subtopic_focus"]
                expected_level = guide["expected_level"]

                weeks.append({
                    "week_number": week_number,
                    "focus_skills": [skill_name],
                    "topic": subtopic,
                    "description": (
                        f"This week focuses on {subtopic}. "
                        f"You will move from {current_level} toward {target_level} "
                        f"through guided practice and implementation."
                    ),
                    "learning_outcomes": [
                        f"Understand the core ideas in {subtopic}",
                        f"Apply {skill_name} in a practical exercise",
                    ],
                    "expected_level_after_week": expected_level,
                    "guide_style": self._infer_guide_style(
                        current_level=current_level,
                        target_level=target_level,
                        topic=subtopic,
                    ),
                    "resource_focus": self._infer_resource_focus(topic=subtopic, skill_name=skill_name),
                    "avoid_topics": [],
                })

        weeks.sort(key=lambda x: x["week_number"])

        return {
            "plan_summary": self._build_fallback_plan_summary(
                track_name=track_name,
                duration_weeks=duration_weeks,
                planning_mode=planning_mode,
                final_expected_level=final_expected_level,
            ),
            "improvement_summary": (
                "The plan prioritizes confirmed skill gaps first, then builds practical competence "
                "through progressively harder weekly implementation."
            ),
            "weekly_breakdown": weeks,
        }

    # ============================================================
    # inference + json
    # ============================================================

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

    def _fix_common_json_issues(self, raw: str) -> str:
        text = (raw or "").strip()
        if text.endswith("}}]"):
            text = text[:-3] + "}]"
        text = re.sub(r",\s*([}\]])", r"\1", text)
        return text

    def _safe_parse_json(self, raw: str) -> Dict[str, Any]:
        if raw is None:
            raise ValueError("Cannot parse JSON from None response")

        if isinstance(raw, dict):
            return raw

        text = str(raw).strip()

        # remove markdown fences
        text = re.sub(r"^```json\s*", "", text, flags=re.IGNORECASE)
        text = re.sub(r"^```\s*", "", text)
        text = re.sub(r"\s*```$", "", text)

        # fix minor issues
        text = self._fix_common_json_issues(text)

        # 1) try direct parse
        try:
            return json.loads(text)
        except Exception:
            pass

        # 2) extract largest JSON object
        start = text.find("{")
        end = text.rfind("}")

        if start != -1 and end != -1 and end > start:
            candidate = text[start:end + 1]
            candidate = self._fix_common_json_issues(candidate)

            try:
                return json.loads(candidate)
            except Exception as e:
                logger.error(
                    "JSON parse failed after extraction | len=%s | preview=%s",
                    len(candidate),
                    candidate[:300],
                )
                raise ValueError("Failed to extract valid JSON from LLM response") from e

        logger.error(
            "JSON parse completely failed | len=%s | preview=%s",
            len(text),
            text[:300],
        )

        raise ValueError("Failed to parse plan JSON from model response")
