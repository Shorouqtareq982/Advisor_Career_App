"""
Plan Generation Service
Generates a progressive learning plan based on:
1) confirmed missing-skill targets
2) existing owned skills that can be leveled up
And fetches real learning resources via YouTube API + SerpApi.
"""

import json
import logging
from typing import Dict, Any, List, Optional
from uuid import UUID

from features.career_builder.repositories.career_repository import CareerRepository
from features.career_builder.services.career_analysis_service import CareerAnalysisService
from features.career_builder.services.resource_search_service import ResourceSearchService
from shared.providers.llm_models.llm_provider import create_llm_provider

logger = logging.getLogger(__name__)


PLAN_GENERATION_PROMPT = """
You are an expert career mentor and learning path designer.

Create a practical, realistic, progressive weekly learning plan.

VERY IMPORTANT:
- The plan MUST be progressive.
- DO NOT repeat the same weekly topic.
- Break learning into stages:
  1. Foundations
  2. Guided Practice
  3. Applied Improvement
  4. Mini Project / Real-world integration
- Weeks must build on each other.
- Mix multiple skills together when useful.
- The goal is NOT isolated skill repetition.
- The goal is to improve the user's capability across the selected learning targets.

Each learning target includes:
- current_level
- target_level
- learning_mode

Rules:
1. If learning_mode = "learn_from_scratch", teach from zero to target level
2. If learning_mode = "level_up":
   - You MUST move the skill to a higher level
   - Example:
     beginner -> intermediate
     intermediate -> advanced
3. Respect the requested duration exactly
4. Keep the plan realistic and progressive
5. The user should clearly understand current level and achievable level after this plan
6. Return VALID JSON only
7. DO NOT return direct links
8. Return resource_queries only
9. If the available duration is short, prioritize the most important learning targets first
10. Combine related skills in the same week when useful
11. DO NOT produce a plan that stays beginner-only if the user already has intermediate track skills
12. Existing owned skills should be strengthened, not ignored

CRITICAL CONSTRAINT:
- NEVER downgrade the user level.
- If the user's current average level is intermediate, the plan result MUST be intermediate or advanced.
- If the user's current average level is beginner, the plan result MUST be beginner or intermediate.
- It is STRICTLY FORBIDDEN to generate a plan that results in a lower overall level.

Allowed resource types:
- docs
- youtube
- course
- article
- practice
- project

CRITICAL RESOURCE RULE:
- Every week MUST include:
  1) one YouTube resource query
  2) one non-YouTube resource query
  3) one practice or project query
- Resources must match the user's current level and target level.
- Early weeks should use easier resources and simpler projects.
- Later weeks can use harder resources and more advanced projects.
- Weekly resource difficulty must consider available_hours_per_week.

Each week must include:
- week_number
- focus_skills
- topic
- description
- learning_outcomes
- expected_level_after_week
- resource_queries

Input:
Track Name: {track_name}
User Level: {user_level}
Current Average Level In Track: {current_average_level}
Current Track Score: {current_track_score}
Minimum Allowed Final Level: {minimum_allowed_final_level}
Duration Weeks: {duration_weeks}
Available Hours Per Week: {available_hours_per_week}
Study Intensity: {study_intensity}

Learning Targets:
{learning_targets_json}

Analysis Snapshot:
{analysis_snapshot_json}

Return JSON:
{{
  "plan_summary": "short summary describing current level and expected improvement by the end",
  "improvement_summary": "clear sentence saying what will improve after completing this plan",
  "weekly_breakdown": [
    {{
      "week_number": 1,
      "focus_skills": ["Skill A", "Skill B"],
      "topic": "Topic title",
      "description": "What to do this week",
      "learning_outcomes": [
        "Outcome 1",
        "Outcome 2"
      ],
      "expected_level_after_week": "beginner",
      "resource_queries": [
        {{
          "title": "resource title",
          "query": "search query",
          "type": "docs"
        }},
        {{
          "title": "video resource",
          "query": "youtube tutorial query",
          "type": "youtube"
        }},
        {{
          "title": "practice resource",
          "query": "practice exercises or mini project",
          "type": "practice"
        }}
      ]
    }}
  ]
}}
"""


class PlanGenerationService:
    LEVEL_VALUES = {
        "none": 0,
        "beginner": 1,
        "intermediate": 2,
        "advanced": 3,
    }

    def __init__(
        self,
        repository: CareerRepository,
        analysis_service: CareerAnalysisService
    ):
        self.repo = repository
        self.analysis_service = analysis_service
        self.resource_search_service = ResourceSearchService()
        self.llm = create_llm_provider()

    async def generate_plan(
        self,
        cv_id: UUID,
        track_id: int,
        duration_weeks: int,
        available_hours_per_week: Optional[int],
        user_level: Optional[str],
        requested_weeks: Optional[int] = None,
        selected_skill_ids: Optional[List[int]] = None,
        skill_targets: Optional[List[Any]] = None
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

        available_hours_per_week = (
            available_hours_per_week
            or cached.get("available_hours_per_week")
            or 6
        )

        study_intensity = self._classify_study_intensity(available_hours_per_week)

        effective_user_level = (
            user_level
            or cached.get("level_used")
            or cached.get("detected_level")
            or "beginner"
        )

        realism = cached.get("realism", {}) or {}
        safe_min_weeks = int(realism.get("safe_min_weeks", duration_weeks) or duration_weeks)
        requested_weeks = requested_weeks or duration_weeks

        skill_gaps = cached.get("skill_gaps", []) or []

        current_level_info = self._calculate_current_track_level(skill_gaps)

        merged_learning_targets = self._build_merged_learning_targets(
            skill_gaps=skill_gaps,
            confirmed_learning_targets=confirmed_learning_targets
        )

        planning_mode = "full_plan"
        used_learning_targets = merged_learning_targets
        deferred_learning_targets: List[Dict[str, Any]] = []

        if requested_weeks < safe_min_weeks:
            planning_mode = "adaptive_compressed_plan"
            used_learning_targets, deferred_learning_targets = self._select_targets_for_available_time(
                learning_targets=merged_learning_targets,
                requested_weeks=requested_weeks,
                available_hours_per_week=available_hours_per_week
            )

        raw_final_level_info = self._calculate_final_track_level(
            all_skill_gaps=skill_gaps,
            used_learning_targets=used_learning_targets
        )

        final_level_info = self._apply_no_downgrade_guard(
            current_level_info=current_level_info,
            final_level_info=raw_final_level_info
        )

        analysis_snapshot = {
            "detected_level": cached.get("detected_level"),
            "required_level": cached.get("required_level"),
            "level_confidence": cached.get("level_confidence"),
            "match_percentage": cached.get("match_percentage"),
            "matching_method": cached.get("matching_method"),
            "fit_analysis": cached.get("fit_analysis"),
            "realism": realism,
            "planning_mode": planning_mode,
            "available_hours_per_week": available_hours_per_week,
            "study_intensity": study_intensity,
            "current_average_level": current_level_info["current_average_level"],
            "current_track_score": current_level_info["current_track_score"],
            "final_expected_level": final_level_info["final_expected_level"],
            "final_track_score": final_level_info["final_track_score"],
            "used_learning_targets": used_learning_targets,
            "deferred_learning_targets": deferred_learning_targets,
        }

        prompt = PLAN_GENERATION_PROMPT.format(
            track_name=track.get("track_name", "Unknown Track"),
            user_level=effective_user_level,
            current_average_level=current_level_info["current_average_level"],
            current_track_score=current_level_info["current_track_score"],
            minimum_allowed_final_level=current_level_info["current_average_level"],
            duration_weeks=duration_weeks,
            available_hours_per_week=available_hours_per_week,
            study_intensity=study_intensity,
            learning_targets_json=json.dumps(used_learning_targets, ensure_ascii=False, indent=2),
            analysis_snapshot_json=json.dumps(analysis_snapshot, ensure_ascii=False, indent=2)
        )

        logger.info(
            "Generating plan... mode=%s used_targets=%s deferred=%s current=%s final=%s hours=%s intensity=%s",
            planning_mode,
            len(used_learning_targets),
            len(deferred_learning_targets),
            current_level_info["current_average_level"],
            final_level_info["final_expected_level"],
            available_hours_per_week,
            study_intensity,
        )

        try:
            response = await self.llm.get_response(
                prompt=prompt,
                need_json_output=True,
                temperature=0.3
            )

            if not response:
                raise ValueError("LLM returned empty response")

            plan_data = response if isinstance(response, dict) else self._safe_parse_json(response)
            self._validate_generated_plan(plan_data, duration_weeks)

        except Exception as e:
            logger.warning(f"LLM plan generation failed, using fallback plan. Reason: {e}")
            plan_data = self._build_fallback_plan(
                track_name=track.get("track_name", "Unknown Track"),
                duration_weeks=duration_weeks,
                learning_targets=used_learning_targets,
                planning_mode=planning_mode,
                final_expected_level=final_level_info["final_expected_level"]
            )

        weekly_breakdown = plan_data.get("weekly_breakdown", [])

        for week in weekly_breakdown:
            resource_queries = week.pop("resource_queries", []) or []

            resource_queries = self._ensure_minimum_resource_mix(
                week=week,
                resource_queries=resource_queries,
                available_hours_per_week=available_hours_per_week,
                duration_weeks=duration_weeks
            )

            level_info = self._infer_week_levels_from_topic(
                week=week,
                used_learning_targets=used_learning_targets
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

        improvement_summary = self._build_improvement_summary(
            track_name=track.get("track_name", "this track"),
            current_level=current_level_info["current_average_level"],
            final_level=final_level_info["final_expected_level"],
            planning_mode=planning_mode
        )

        return {
            "track_id": track_id,
            "track_name": track.get("track_name"),
            "required_level": effective_user_level,
            "duration_weeks": duration_weeks,
            "available_hours_per_week": available_hours_per_week,
            "study_intensity": study_intensity,
            "planning_mode": planning_mode,
            "plan_summary": plan_data.get("plan_summary", ""),
            "current_average_level": current_level_info["current_average_level"],
            "current_track_score": current_level_info["current_track_score"],
            "final_expected_level": final_level_info["final_expected_level"],
            "final_track_score": final_level_info["final_track_score"],
            "final_skill_levels_after_plan": final_level_info["final_skill_levels"],
            "improvement_summary": improvement_summary,
            "weekly_breakdown": weekly_breakdown,
            "learning_targets": confirmed_learning_targets,
            "merged_learning_targets": merged_learning_targets,
            "used_learning_targets": used_learning_targets,
            "deferred_learning_targets": deferred_learning_targets,
            "analysis_snapshot": {
                "detected_level": cached.get("detected_level"),
                "required_level": cached.get("required_level"),
                "level_confidence": cached.get("level_confidence"),
                "match_percentage": cached.get("match_percentage"),
                "matching_method": cached.get("matching_method"),
                "fit_analysis": cached.get("fit_analysis"),
                "skill_gaps": skill_gaps,
                "reviewable_skills": cached.get("reviewable_skills", []),
                "detected_skill_levels": cached.get("detected_skill_levels", {}),
                "realism": realism,
                "matched_skills": cached.get("matched_skills", []),
                "missing_skills": cached.get("missing_skills", []),
                "metadata": {
                    "cv_skills_count": len(cached.get("cv_skills", [])),
                    "analysis_quality": cached.get("analysis_quality"),
                    "level_reasoning": cached.get("level_reasoning"),
                }
            }
        }

    # =====================================================
    # TARGET BUILDING
    # =====================================================

    def _build_merged_learning_targets(
        self,
        skill_gaps: List[Dict[str, Any]],
        confirmed_learning_targets: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        merged: List[Dict[str, Any]] = []
        seen_ids = set()

        for item in confirmed_learning_targets or []:
            skill_id = item.get("skill_id")
            if skill_id is None or skill_id in seen_ids:
                continue
            merged.append({
                "skill_id": skill_id,
                "skill_name": item.get("skill_name"),
                "current_level": self._normalize_level(item.get("current_level")),
                "target_level": self._normalize_level(item.get("target_level")),
                "learning_mode": item.get("learning_mode", "learn_from_scratch"),
                "required_level": self._normalize_level(item.get("required_level")),
                "required_weeks": int(item.get("required_weeks", 4) or 4),
                "importance_weight": int(item.get("importance_weight", 3) or 3),
            })
            seen_ids.add(skill_id)

        for gap in skill_gaps or []:
            if gap.get("status") != "has":
                continue

            skill_id = gap.get("skill_id")
            if skill_id is None or skill_id in seen_ids:
                continue

            current_level = self._normalize_level(gap.get("current_level"))
            if current_level not in ("beginner", "intermediate"):
                continue

            target_level = self._suggest_level_up_target(current_level)

            if target_level == current_level:
                continue

            merged.append({
                "skill_id": skill_id,
                "skill_name": gap.get("skill_name"),
                "current_level": current_level,
                "target_level": target_level,
                "learning_mode": "level_up",
                "required_level": self._normalize_level(gap.get("required_level")),
                "required_weeks": self._estimate_level_up_weeks(current_level, target_level),
                "importance_weight": int(gap.get("importance_weight", 3) or 3),
            })
            seen_ids.add(skill_id)

        return merged

    def _suggest_level_up_target(self, current_level: str) -> str:
        current_level = self._normalize_level(current_level)
        if current_level == "beginner":
            return "intermediate"
        if current_level == "intermediate":
            return "advanced"
        return current_level

    def _estimate_level_up_weeks(self, current_level: str, target_level: str) -> int:
        pair = (self._normalize_level(current_level), self._normalize_level(target_level))
        estimates = {
            ("beginner", "intermediate"): 6,
            ("intermediate", "advanced"): 8,
        }
        return estimates.get(pair, 4)

    def _classify_study_intensity(self, hours: int) -> str:
        if hours <= 5:
            return "light"
        elif hours <= 10:
            return "moderate"
        return "intensive"

    def _select_targets_for_available_time(
        self,
        learning_targets: List[Dict[str, Any]],
        requested_weeks: int,
        available_hours_per_week: int
    ) -> tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        if not learning_targets:
            return [], []

        def sort_key(item: Dict[str, Any]) -> tuple:
            importance = int(item.get("importance_weight", 0) or 0)
            required_weeks = int(item.get("required_weeks", 4) or 4)
            learning_mode = item.get("learning_mode", "learn_from_scratch")
            current_level = self._normalize_level(item.get("current_level"))

            if learning_mode == "level_up" and current_level == "intermediate":
                mode_priority = 3
            elif learning_mode == "level_up" and current_level == "beginner":
                mode_priority = 2
            else:
                mode_priority = 1

            return (
                importance,
                mode_priority,
                -required_weeks
            )

        skills_sorted = sorted(learning_targets, key=sort_key, reverse=True)

        selected: List[Dict[str, Any]] = []
        deferred: List[Dict[str, Any]] = []

        weekly_capacity_units = max(1, available_hours_per_week // 2)
        total_capacity_units = requested_weeks * weekly_capacity_units
        used_units = 0

        priority_levelup = [
            s for s in skills_sorted
            if s.get("learning_mode") == "level_up"
        ]

        for skill in priority_levelup:
            skill_units = int(skill.get("required_weeks", 4) or 4)
            if used_units + skill_units <= total_capacity_units:
                selected.append(skill)
                used_units += skill_units

            if len(selected) >= 2:
                break

        selected_ids = {item.get("skill_id") for item in selected}

        for skill in skills_sorted:
            skill_id = skill.get("skill_id")
            if skill_id in selected_ids:
                continue

            skill_units = int(skill.get("required_weeks", 4) or 4)

            if used_units + skill_units <= total_capacity_units:
                selected.append(skill)
                used_units += skill_units
            else:
                deferred.append(skill)

        if not selected and skills_sorted:
            selected = [skills_sorted[0]]
            deferred = skills_sorted[1:]

        return selected, deferred

    # =====================================================
    # RESOURCE HELPERS
    # =====================================================

    def _ensure_minimum_resource_mix(
        self,
        week: Dict[str, Any],
        resource_queries: List[Dict[str, Any]],
        available_hours_per_week: int,
        duration_weeks: int
    ) -> List[Dict[str, Any]]:
        queries = list(resource_queries or [])

        focus_skills = week.get("focus_skills", []) or []
        primary_skill = focus_skills[0] if focus_skills else (week.get("topic") or "skill")
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

        has_youtube = any((q.get("type") or "").lower() == "youtube" for q in queries)
        has_non_youtube = any((q.get("type") or "").lower() != "youtube" for q in queries)
        has_practice = any((q.get("type") or "").lower() in ("practice", "project") for q in queries)

        if not has_youtube:
            queries.append({
                "title": f"{primary_skill} video tutorial",
                "query": f"{primary_skill} {difficulty_hint}",
                "type": "youtube"
            })

        if not has_non_youtube:
            queries.append({
                "title": f"{primary_skill} official guide",
                "query": f"{primary_skill} official documentation",
                "type": "docs"
            })

        if not has_practice:
            queries.append({
                "title": f"{primary_skill} hands-on practice",
                "query": f"{primary_skill} {project_hint}",
                "type": "practice"
            })

        return queries

    def _infer_week_levels_from_topic(
        self,
        week: Dict[str, Any],
        used_learning_targets: List[Dict[str, Any]]
    ) -> Dict[str, str]:
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
            "target_level": "intermediate",
        }

    # =====================================================
    # LEVEL CALCULATION
    # =====================================================

    def _normalize_level(self, level: Optional[str]) -> str:
        value = (level or "none").strip().lower()
        return value if value in self.LEVEL_VALUES else "none"

    def _score_to_level(self, score: float, included_skills_count: int) -> str:
        if included_skills_count < 3 and score < 1.5:
            return "beginner"
        if score >= 2.5:
            return "advanced"
        if score >= 1.5:
            return "intermediate"
        return "beginner"

    def _calculate_current_track_level(
        self,
        all_skill_gaps: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        current_skill_levels: Dict[str, str] = {}
        total_weight = 0
        weighted_sum = 0.0

        for gap in all_skill_gaps or []:
            current_level = self._normalize_level(gap.get("current_level"))
            if current_level == "none":
                continue

            skill_name = gap.get("skill_name", "Unknown Skill")
            importance = int(gap.get("importance_weight", 3) or 3)
            level_value = self.LEVEL_VALUES.get(current_level, 0)

            current_skill_levels[skill_name] = current_level
            total_weight += importance
            weighted_sum += level_value * importance

        if total_weight == 0:
            return {
                "current_average_level": "beginner",
                "current_track_score": 1.0,
                "current_skill_levels": {},
            }

        avg_score = weighted_sum / total_weight
        current_level = self._score_to_level(avg_score, len(current_skill_levels))

        return {
            "current_average_level": current_level,
            "current_track_score": round(avg_score, 2),
            "current_skill_levels": current_skill_levels,
        }

    def _calculate_final_track_level(
        self,
        all_skill_gaps: List[Dict[str, Any]],
        used_learning_targets: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        final_skill_levels: Dict[int, str] = {}
        skill_meta: Dict[int, Dict[str, Any]] = {}

        for gap in all_skill_gaps or []:
            skill_id = gap.get("skill_id")
            if skill_id is None:
                continue

            current_level = self._normalize_level(gap.get("current_level"))
            if current_level == "none":
                continue

            final_skill_levels[skill_id] = current_level
            skill_meta[skill_id] = {
                "skill_name": gap.get("skill_name"),
                "importance_weight": int(gap.get("importance_weight", 3) or 3),
            }

        for target in used_learning_targets or []:
            skill_id = target.get("skill_id")
            if skill_id is None:
                continue

            target_level = self._normalize_level(target.get("target_level"))
            final_skill_levels[skill_id] = target_level

            if skill_id not in skill_meta:
                skill_meta[skill_id] = {
                    "skill_name": target.get("skill_name"),
                    "importance_weight": int(target.get("importance_weight", 3) or 3),
                }

        total_weight = 0
        weighted_sum = 0.0

        for skill_id, level_name in final_skill_levels.items():
            importance = int(skill_meta.get(skill_id, {}).get("importance_weight", 3) or 3)
            level_value = self.LEVEL_VALUES.get(level_name, 0)
            total_weight += importance
            weighted_sum += level_value * importance

        if total_weight == 0:
            return {
                "final_expected_level": "beginner",
                "final_track_score": 1.0,
                "final_skill_levels": {},
            }

        avg_score = weighted_sum / total_weight
        final_level = self._score_to_level(avg_score, len(final_skill_levels))

        human_readable_skill_levels = {}
        for skill_id, level_name in final_skill_levels.items():
            skill_name = skill_meta.get(skill_id, {}).get("skill_name", str(skill_id))
            human_readable_skill_levels[skill_name] = level_name

        return {
            "final_expected_level": final_level,
            "final_track_score": round(avg_score, 2),
            "final_skill_levels": human_readable_skill_levels,
        }

    def _apply_no_downgrade_guard(
        self,
        current_level_info: Dict[str, Any],
        final_level_info: Dict[str, Any]
    ) -> Dict[str, Any]:
        current_score = float(current_level_info.get("current_track_score", 1.0) or 1.0)
        final_score = float(final_level_info.get("final_track_score", 1.0) or 1.0)

        current_level = self._normalize_level(current_level_info.get("current_average_level"))
        final_level = self._normalize_level(final_level_info.get("final_expected_level"))

        if (
            self.LEVEL_VALUES.get(final_level, 0) < self.LEVEL_VALUES.get(current_level, 0)
            or final_score < current_score
        ):
            final_level_info["final_expected_level"] = current_level
            final_level_info["final_track_score"] = round(max(final_score, current_score), 2)

        return final_level_info

    # =====================================================
    # SUMMARY
    # =====================================================

    def _build_improvement_summary(
        self,
        track_name: str,
        current_level: str,
        final_level: str,
        planning_mode: str
    ) -> str:
        if final_level == current_level:
            message = (
                f"After finishing this plan, your overall expected level in {track_name} "
                f"remains {final_level}, with stronger practical depth across the track."
            )
        else:
            message = (
                f"After finishing this plan, your overall expected level in {track_name} "
                f"improves from {current_level} to {final_level}."
            )

        if planning_mode == "adaptive_compressed_plan":
            message += " This compressed plan focuses on the highest-priority skills first."

        return message

    # =====================================================
    # PARSING / VALIDATION
    # =====================================================

    def _safe_parse_json(self, raw_response: Any) -> Dict[str, Any]:
        if isinstance(raw_response, dict):
            return raw_response

        try:
            return json.loads(raw_response)
        except Exception as e:
            raise ValueError(f"Failed to parse generated plan JSON: {e}")

    def _validate_generated_plan(self, plan_data: Dict[str, Any], duration_weeks: int) -> None:
        if not isinstance(plan_data, dict):
            raise ValueError("Generated plan must be a JSON object")

        weekly_breakdown = plan_data.get("weekly_breakdown")
        if not isinstance(weekly_breakdown, list) or not weekly_breakdown:
            raise ValueError("Generated plan is missing weekly_breakdown")

        if len(weekly_breakdown) != duration_weeks:
            raise ValueError(
                f"Generated plan weeks mismatch. Expected {duration_weeks}, got {len(weekly_breakdown)}"
            )

        seen_topics = set()

        for i, week in enumerate(weekly_breakdown, start=1):
            if not isinstance(week, dict):
                raise ValueError(f"Week {i} must be an object")

            if week.get("week_number") != i:
                raise ValueError(f"Invalid week numbering at week {i}")

            required_fields = [
                "focus_skills",
                "topic",
                "description",
                "learning_outcomes",
                "expected_level_after_week"
            ]
            for field in required_fields:
                if field not in week:
                    raise ValueError(f"Week {i} missing field: {field}")

            topic_key = str(week.get("topic", "")).strip().lower()
            if topic_key in seen_topics:
                raise ValueError(f"Repeated topic detected in generated plan: {week.get('topic')}")
            seen_topics.add(topic_key)

    # =====================================================
    # FALLBACK PLAN
    # =====================================================

    def _build_fallback_plan(
        self,
        track_name: str,
        duration_weeks: int,
        learning_targets: List[Dict[str, Any]],
        planning_mode: str = "full_plan",
        final_expected_level: str = "beginner"
    ) -> Dict[str, Any]:
        if not learning_targets:
            raise ValueError("Cannot build fallback plan without learning targets")

        stages = [
            "Foundations",
            "Guided Practice",
            "Applied Improvement",
            "Mini Project"
        ]

        weeks = []
        targets_count = len(learning_targets)

        for i in range(duration_weeks):
            target = learning_targets[i % targets_count]
            skill_name = target.get("skill_name", "Skill")
            current_level = target.get("current_level", "none")
            target_level = target.get("target_level", "beginner")
            learning_mode = target.get("learning_mode", "learn_from_scratch")

            stage_name = stages[min(len(stages) - 1, (i * len(stages)) // max(duration_weeks, 1))]

            if learning_mode == "level_up":
                topic = f"{stage_name}: Improve {skill_name} from {current_level} to {target_level}"
                description = (
                    f"This week focuses on strengthening {skill_name} from {current_level} "
                    f"toward {target_level} through structured practice and applied tasks."
                )
                tutorial_query = f"{skill_name} {target_level} tutorial"
            else:
                topic = f"{stage_name}: Build {skill_name} from scratch"
                description = (
                    f"This week focuses on learning {skill_name} from scratch and building "
                    f"toward {target_level} using guided study and practical work."
                )
                tutorial_query = f"{skill_name} tutorial for beginners"

            weeks.append({
                "week_number": i + 1,
                "focus_skills": [skill_name],
                "topic": topic,
                "description": description,
                "learning_outcomes": [
                    f"Improve {skill_name} from {current_level} toward {target_level}",
                    f"Gain practical confidence in {skill_name} through structured work"
                ],
                "expected_level_after_week": target_level,
                "resource_queries": [
                    {
                        "title": f"{skill_name} official documentation",
                        "query": f"{skill_name} official documentation",
                        "type": "docs"
                    },
                    {
                        "title": f"{skill_name} video tutorial",
                        "query": tutorial_query,
                        "type": "youtube"
                    },
                    {
                        "title": f"{skill_name} practice",
                        "query": f"{skill_name} beginner mini project",
                        "type": "practice"
                    }
                ]
            })

        if planning_mode == "adaptive_compressed_plan":
            plan_summary = (
                f"This is a compressed {duration_weeks}-week progressive learning plan for the {track_name} track. "
                f"It focuses on the highest-priority learning targets first because the available time is limited."
            )
            improvement_summary = (
                f"By completing this compressed plan, you should make meaningful progress "
                f"and maintain at least {final_expected_level} readiness in the track."
            )
        else:
            plan_summary = (
                f"This is a {duration_weeks}-week progressive learning plan for the {track_name} track. "
                f"It combines missing skills and skill improvement into one guided roadmap."
            )
            improvement_summary = (
                f"By completing this plan, you should build stronger practical readiness "
                f"and maintain or improve toward {final_expected_level} level in the track."
            )

        return {
            "plan_summary": plan_summary,
            "improvement_summary": improvement_summary,
            "weekly_breakdown": weeks
        }