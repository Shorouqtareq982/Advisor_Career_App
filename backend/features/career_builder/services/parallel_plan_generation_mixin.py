import asyncio
import logging
import time
import json
from typing import Any, Dict, List

from features.career_builder.services.generation_runtime import GenerationRuntime

logger = logging.getLogger(__name__)


class ParallelPlanGenerationMixin:

    def __init__(self):
        self.plan_count = 0
        self.start_time = time.time()
        self.metrics_data = []

    def _ensure_metrics_state(self):
        if not hasattr(self, "plan_count"):
            self.plan_count = 0

        if not hasattr(self, "start_time"):
            self.start_time = time.time()

        if not hasattr(self, "metrics_data"):
            self.metrics_data = []

    def _calculate_throughput(self):
        self._ensure_metrics_state()

        elapsed_time = time.time() - self.start_time
        if elapsed_time > 0:
            return self.plan_count / elapsed_time
        return 0

    async def _measure_concurrency(self, runtime: GenerationRuntime):
        if runtime is None or runtime.llm_sem is None:
            logger.warning("runtime or runtime.llm_sem is not initialized.")
            return 0

        waiters = getattr(runtime.llm_sem, "_waiters", None)

        if waiters is None:
            logger.info("No semaphore waiters yet.")
            return 0

        try:
            active_tasks = len(waiters)
        except TypeError:
            active_tasks = 0

        logger.info(f"Active concurrent tasks: {active_tasks}")
        return active_tasks

    async def _attach_study_guides_parallel(
        self,
        *,
        weekly_breakdown: List[Dict[str, Any]],
        used_learning_targets: List[Dict[str, Any]],
        track_name: str,
        available_hours_per_week: int,
        runtime: GenerationRuntime,
    ) -> List[Dict[str, Any]]:

        self._ensure_metrics_state()

        concurrency = await self._measure_concurrency(runtime)
        self.plan_count += 1
        throughput = self._calculate_throughput()

        self.metrics_data.append({
            "timestamp": time.time(),
            "throughput": throughput,
            "concurrency": concurrency
        })

        try:
            with open("metrics_data.json", "w") as f:
                json.dump(self.metrics_data, f, indent=4)
            logger.info("Metrics saved to metrics_data.json")
        except Exception as e:
            logger.warning(f"Failed to save metrics_data.json: {e}")

        logger.info(f"Current throughput: {throughput:.2f} plans/second")

        async def build_one(week: Dict[str, Any]) -> Dict[str, Any]:
            level_info = self._infer_week_levels_from_topic(
                week=week,
                used_learning_targets=used_learning_targets,
            )

            def fallback():
                return self._build_study_guide(
                    skill_name=(week.get("focus_skills") or ["General Skill"])[0],
                    subtopic_terms=week.get("topic", "Weekly topic"),
                    current_level=level_info.get("current_level", "none"),
                    target_level=level_info.get("target_level", "beginner"),
                    available_hours=available_hours_per_week,
                    guide_style=week.get("guide_style", "hands_on"),
                    resource_focus=week.get("resource_focus", []),
                )

            study_guide = await runtime.run_limited(
                semaphore=runtime.llm_sem,
                provider="llm_study_guides",
                coro_factory=lambda: self._generate_personalized_study_guide_for_week(
                    track_name=track_name,
                    week=week,
                    current_level=level_info.get("current_level", "beginner"),
                    target_level=level_info.get("target_level", "intermediate"),
                    available_hours_per_week=available_hours_per_week,
                ),
                fallback_factory=fallback,
            )

            week["study_guide"] = study_guide
            return week

        return list(await asyncio.gather(*(build_one(w) for w in weekly_breakdown)))

    async def _attach_resources_parallel(
        self,
        *,
        weekly_breakdown: List[Dict[str, Any]],
        used_learning_targets: List[Dict[str, Any]],
        track_id: int,
        track_name: str,
        track_keywords: List[str],
        duration_weeks: int,
        available_hours_per_week: int,
        runtime: GenerationRuntime,
    ) -> List[Dict[str, Any]]:

        global_seen_urls = set()
        dedupe_lock = asyncio.Lock()

        async def build_one(week: Dict[str, Any]) -> Dict[str, Any]:
            level_info = self._infer_week_levels_from_topic(
                week=week,
                used_learning_targets=used_learning_targets,
            )

            focus_skill = (week.get("focus_skills") or [None])[0]

            skill_id = next(
                (
                    target.get("skill_id")
                    for target in used_learning_targets
                    if target.get("skill_name") == focus_skill
                ),
                None,
            )

            def fallback():
                return {
                    "resources": self._build_fallback_resources_for_week(
                        week=week,
                        track_name=track_name,
                        current_level=level_info.get("current_level", "beginner"),
                        target_level=level_info.get("target_level", "intermediate"),
                        available_hours_per_week=available_hours_per_week,
                    ),
                    "validation_report": {"source": "fallback"},
                }

            if self.weekly_resource_orchestrator:
                queries = self._build_resource_queries_for_week(
                    week=week,
                    current_level=level_info.get("current_level", "beginner"),
                    target_level=level_info.get("target_level", "intermediate"),
                    duration_weeks=duration_weeks,
                    week_number=int(week.get("week_number", 1) or 1),
                    all_used_learning_targets=used_learning_targets,
                )

                result = await runtime.run_limited(
                    semaphore=runtime.resource_sem,
                    provider="resource_search",
                    coro_factory=lambda: self.weekly_resource_orchestrator.build_week_resources(
                        plan_id=None,
                        track_id=track_id,
                        track_name=track_name,
                        week=week,
                        resource_queries=queries,
                        current_level=level_info.get("current_level", "beginner"),
                        target_level=level_info.get("target_level", "intermediate"),
                        available_hours_per_week=available_hours_per_week,
                        context_keywords=week.get("focus_skills", []) + track_keywords,
                        week_number=week.get("week_number"),
                        duration_weeks=duration_weeks,
                        skill_id=skill_id,
                        skill_name=focus_skill,
                    ),
                    fallback_factory=fallback,
                )
            else:
                result = fallback()

            raw_resources = result.get("resources", []) or []

            final_resources = []

            for resource in raw_resources:
                url = (resource.get("url") or "").strip().lower().rstrip("/")
                if not url:
                    continue

                async with dedupe_lock:
                    if url in global_seen_urls:
                        continue

                    global_seen_urls.add(url)
                    final_resources.append(resource)

            expected = self._expected_week_resource_count(available_hours_per_week)

            if len(final_resources) < expected:
                fallback_extra = self._build_fallback_resources_for_week(
                    week=week,
                    track_name=track_name,
                    current_level=level_info.get("current_level", "beginner"),
                    target_level=level_info.get("target_level", "intermediate"),
                    available_hours_per_week=available_hours_per_week,
                )

                for resource in fallback_extra:
                    url = (resource.get("url") or "").strip().lower().rstrip("/")
                    if not url:
                        continue

                    async with dedupe_lock:
                        if url in global_seen_urls:
                            continue

                        global_seen_urls.add(url)
                        final_resources.append(resource)

                    if len(final_resources) >= expected:
                        break

            week["resources"] = final_resources
            week["resource_validation_report"] = result.get("validation_report", {})

            return week

        return list(await asyncio.gather(*(build_one(w) for w in weekly_breakdown)))