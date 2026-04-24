import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)


class WeeklyResourceOrchestrator:
    """
    Stable dynamic resource orchestration.

    Flow:
    1) Search dynamic resources
    2) Validate weekly contract
    3) Reuse discovered resources if needed
    4) Reuse curated resources if needed
    5) Fallback only as last resort
    6) Persist good dynamic results for future reuse
    """

    VALID_RESOURCE_TYPES = {"docs", "article", "youtube", "practice", "project"}

    def __init__(self, repository, resource_search_service):
        self.repo = repository
        self.resource_search_service = resource_search_service

    # =========================================================
    # Public API
    # =========================================================

    async def build_week_resources(
        self,
        *,
        plan_id: Optional[int],
        track_id: int,
        track_name: str,
        week: Dict[str, Any],
        resource_queries: List[Dict[str, Any]],
        current_level: str,
        target_level: str,
        available_hours_per_week: int,
        context_keywords: Optional[List[str]] = None,
        week_number: Optional[int] = None,
        duration_weeks: Optional[int] = None,
        skill_id: Optional[int] = None,
        skill_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        clean_queries = self._normalize_resource_queries(resource_queries)
        canonical_topic = self._canonical_topic(week.get("topic", ""))
        expected_total = self._expected_week_resource_count(available_hours_per_week)
        resolved_week_number = week_number or week.get("week_number")

        logger.info(
            "[ORCH] start | week=%s | skill=%s | topic=%s | level=%s->%s | queries=%s",
            resolved_week_number,
            skill_name,
            week.get("topic", ""),
            current_level,
            target_level,
            len(clean_queries),
        )

        dynamic_resources: List[Dict[str, Any]] = []
        if self.resource_search_service and clean_queries:
            try:
                dynamic_resources = await self.resource_search_service.search_resources(
                    resource_queries=clean_queries,
                    max_per_week=expected_total,
                    current_level=current_level,
                    target_level=target_level,
                    available_hours_per_week=available_hours_per_week,
                    week_number=resolved_week_number,
                    duration_weeks=duration_weeks,
                    context_keywords=context_keywords or [],
                    track_name=track_name,
                    week_topic=week.get("topic", ""),
                    skill_id=skill_id,
                )
            except Exception as e:
                logger.warning("[ORCH] dynamic search failed | week=%s | reason=%s", resolved_week_number, e, exc_info=True)
                dynamic_resources = []

        dynamic_resources = self._dedupe_local(dynamic_resources)
        dynamic_resources = self._filter_invalid_resources(dynamic_resources)
        packaged_dynamic = self._package_week_resources(dynamic_resources, available_hours_per_week)
        packaged_dynamic = self._dedupe_local(packaged_dynamic)
        dynamic_validation = self._validate_week_resources(packaged_dynamic, available_hours_per_week)

        logger.info(
            "[ORCH] dynamic validation | week=%s | passed=%s | count=%s",
            resolved_week_number,
            dynamic_validation["passed"],
            len(packaged_dynamic),
        )

        if dynamic_validation["passed"]:
            await self._save_successful_discovered_resources(
                plan_id=plan_id,
                track_id=track_id,
                skill_id=skill_id,
                canonical_topic=canonical_topic,
                week_topic=week.get("topic", ""),
                current_level=current_level,
                target_level=target_level,
                resources=packaged_dynamic,
            )
            return {
                "resources": packaged_dynamic,
                "validation_report": self._build_validation_report(packaged_dynamic, available_hours_per_week, source="dynamic"),
            }

        discovered_resources = await self._load_discovered_resources(
            track_id=track_id,
            skill_id=skill_id,
            canonical_topic=canonical_topic,
            current_level=current_level,
            target_level=target_level,
        )
        merged_with_discovered = self._merge_resource_sets(dynamic_resources, discovered_resources)
        merged_with_discovered = self._filter_invalid_resources(merged_with_discovered)
        merged_with_discovered = self._package_week_resources(merged_with_discovered, available_hours_per_week)
        merged_with_discovered = self._dedupe_local(merged_with_discovered)
        discovered_validation = self._validate_week_resources(merged_with_discovered, available_hours_per_week)

        logger.info(
            "[ORCH] discovered validation | week=%s | passed=%s | count=%s",
            resolved_week_number,
            discovered_validation["passed"],
            len(merged_with_discovered),
        )

        if discovered_validation["passed"]:
            return {
                "resources": merged_with_discovered,
                "validation_report": self._build_validation_report(merged_with_discovered, available_hours_per_week, source="dynamic_plus_discovered"),
            }

        curated_resources = await self._load_curated_resources(
            track_id=track_id,
            skill_id=skill_id,
            current_level=current_level,
            target_level=target_level,
        )
        merged_final = self._merge_resource_sets(merged_with_discovered, curated_resources)
        merged_final = self._filter_invalid_resources(merged_final)
        merged_final = self._package_week_resources(merged_final, available_hours_per_week)
        merged_final = self._dedupe_local(merged_final)
        curated_validation = self._validate_week_resources(merged_final, available_hours_per_week)

        logger.info(
            "[ORCH] curated validation | week=%s | passed=%s | count=%s",
            resolved_week_number,
            curated_validation["passed"],
            len(merged_final),
        )

        if curated_validation["passed"]:
            return {
                "resources": merged_final,
                "validation_report": self._build_validation_report(merged_final, available_hours_per_week, source="dynamic_plus_discovered_plus_curated"),
            }

        fallback_resources = self._build_hard_fallback_resources(
            track_name=track_name,
            week=week,
            skill_name=skill_name,
            available_hours_per_week=available_hours_per_week,
        )
        logger.warning("[ORCH] hard fallback | week=%s | count=%s", resolved_week_number, len(fallback_resources))
        return {
            "resources": fallback_resources,
            "validation_report": self._build_validation_report(fallback_resources, available_hours_per_week, source="hard_fallback"),
        }

    # =========================================================
    # Contracts / validation
    # =========================================================

    def _expected_youtube_count(self, available_hours_per_week: int) -> int:
        return 1

    def _expected_week_resource_count(self, available_hours_per_week: int) -> int:
        return 4

    def _resource_type_counts(self, resources: List[Dict[str, Any]]) -> Dict[str, int]:
        counts = {"docs": 0, "article": 0, "youtube": 0, "practice": 0, "project": 0}
        for resource in resources or []:
            r_type = (resource.get("type") or "").strip().lower()
            if r_type in counts:
                counts[r_type] += 1
        return counts

    def _validate_week_resources(self, resources, available_hours_per_week):
        counts = self._resource_type_counts(resources)

        has_reference = counts["docs"] >= 1 or counts["article"] >= 1
        has_practice_or_project = counts["practice"] >= 1 or counts["project"] >= 1
        has_any_resource = len(resources or []) >= 3

        # YouTube optional عشان 403 ما يوقعش الأسبوع
        passed = has_reference and has_practice_or_project and has_any_resource

        return {
            "passed": passed,
            "resource_type_counts": counts,
            "expected_youtube": 1,
            "youtube_optional": True,
            "contract_note": "youtube is optional; docs/article + practice/project + min 3 resources required",
        }

    def _build_validation_report(self, resources: List[Dict[str, Any]], available_hours_per_week: int, source: str) -> Dict[str, Any]:
        validation = self._validate_week_resources(resources, available_hours_per_week)
        return {
            "source": source,
            "resource_count": len(resources),
            "expected_resource_count": self._expected_week_resource_count(available_hours_per_week),
            "youtube_expected": validation["expected_youtube"],
            "resource_type_counts": validation["resource_type_counts"],
            "contract_passed": validation["passed"],
        }

    # =========================================================
    # Loading / saving
    # =========================================================

    async def _load_discovered_resources(
        self,
        *,
        track_id: int,
        skill_id: Optional[int],
        canonical_topic: str,
        current_level: str,
        target_level: str,
    ) -> List[Dict[str, Any]]:
        if not skill_id:
            return []
        try:
            return await self.repo.get_discovered_learning_resources(
                track_id=track_id,
                skill_id=skill_id,
                canonical_topic=canonical_topic,
                current_level=current_level,
                target_level=target_level,
                limit=12,
            )
        except Exception as e:
            logger.warning("Failed loading discovered resources: %s", e, exc_info=True)
            return []

    async def _load_curated_resources(
        self,
        *,
        track_id: int,
        skill_id: Optional[int],
        current_level: str,
        target_level: str,
    ) -> List[Dict[str, Any]]:
        if not skill_id:
            return []
        try:
            return await self.repo.get_curated_learning_resources(
                track_id=track_id,
                skill_id=skill_id,
                current_level=current_level,
                target_level=target_level,
                limit=12,
            )
        except Exception as e:
            logger.warning("Failed loading curated resources: %s", e, exc_info=True)
            return []

    async def _save_successful_discovered_resources(
        self,
        *,
        plan_id: Optional[int],
        track_id: int,
        skill_id: Optional[int],
        canonical_topic: str,
        week_topic: str,
        current_level: str,
        target_level: str,
        resources: List[Dict[str, Any]],
    ) -> None:
        if not skill_id or not resources:
            return
        rows = []
        for resource in resources:
            rows.append(
                {
                    "plan_id": plan_id,
                    "track_id": track_id,
                    "skill_id": skill_id,
                    "week_topic": week_topic,
                    "canonical_topic": canonical_topic,
                    "current_level": current_level,
                    "target_level": target_level,
                    "resource_type": resource.get("type"),
                    "title": resource.get("title"),
                    "url": resource.get("url"),
                    "snippet": resource.get("snippet"),
                    "source_provider": resource.get("source_provider") or "dynamic",
                    "source_domain": self._extract_domain(resource.get("url", "")),
                    "estimated_duration_minutes": self._duration_to_minutes(resource),
                    "base_score": float(resource.get("score") or 0),
                    "final_score": float(resource.get("score") or 0),
                    "times_selected": 1,
                    "times_validation_passed": 1,
                    "times_used_in_final_plan": 1,
                    "is_active": True,
                    "is_official": bool(resource.get("is_official", False)),
                    "is_practical": bool(resource.get("is_practical", False)),
                    "was_fallback": False,
                }
            )
        try:
            await self.repo.upsert_discovered_learning_resources(rows)
        except Exception as e:
            logger.warning("Failed saving discovered resources: %s", e, exc_info=True)

    # =========================================================
    # Packaging / filtering / merging
    # =========================================================

    def _normalize_resource_queries(self, resource_queries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        clean_queries = []
        for query in resource_queries or []:
            r_type = (query.get("type") or "").strip().lower()
            title = (query.get("title") or "").strip()
            q = (query.get("query") or "").strip()
            if r_type not in self.VALID_RESOURCE_TYPES:
                continue
            if not title and not q:
                continue
            clean_queries.append({
                "type": r_type,
                "title": title or q,
                "query": q or title,
                "skill_name": query.get("skill_name"),
            })
        return clean_queries

    def _filter_invalid_resources(self, resources: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        final = []
        for resource in resources or []:
            if (resource.get("type") or "").strip().lower() not in self.VALID_RESOURCE_TYPES:
                continue
            if not resource.get("title") or not resource.get("url"):
                continue
            final.append(resource)
        return final

    def _package_week_resources(self, resources: List[Dict[str, Any]], available_hours_per_week: int) -> List[Dict[str, Any]]:
        expected_youtube = self._expected_youtube_count(available_hours_per_week)
        deduped = self._dedupe_local(resources)

        docs = [r for r in deduped if (r.get("type") or "").lower() == "docs"]
        articles = [r for r in deduped if (r.get("type") or "").lower() == "article"]
        practice = [r for r in deduped if (r.get("type") or "").lower() == "practice"]
        projects = [r for r in deduped if (r.get("type") or "").lower() == "project"]
        youtube = [r for r in deduped if (r.get("type") or "").lower() == "youtube"]

        final: List[Dict[str, Any]] = []
        if docs:
            final.append(docs[0])
        elif articles:
            final.append(articles[0])
        if practice:
            final.append(practice[0])
        if projects:
            final.append(projects[0])
        final.extend(youtube[:expected_youtube])

        expected_total = self._expected_week_resource_count(available_hours_per_week)
        for item in deduped:
            if item in final:
                continue
            final.append(item)
            if len(final) >= expected_total:
                break

        return final[:expected_total]

    def _merge_resource_sets(self, primary: List[Dict[str, Any]], secondary: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return self._dedupe_local((primary or []) + (secondary or []))

    def _dedupe_local(self, resources: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        final = []
        seen = set()
        for resource in resources or []:
            url = (resource.get("url") or "").strip().lower()
            if not url or url in seen:
                continue
            seen.add(url)
            final.append(resource)
        return final

    # =========================================================
    # Fallbacks / helpers
    # =========================================================

    def _canonical_topic(self, topic: str) -> str:
        text = (topic or "").strip().lower()
        text = text.replace("—", " ")
        text = " ".join(text.split())
        return text[:200]

    def _extract_domain(self, url: str) -> Optional[str]:
        try:
            from urllib.parse import urlparse
            return urlparse(url).netloc.lower() or None
        except Exception:
            return None

    def _duration_to_minutes(self, resource: Dict[str, Any]) -> Optional[int]:
        if resource.get("youtube_duration_minutes"):
            return int(resource.get("youtube_duration_minutes"))
        duration = (resource.get("duration") or "").strip().lower()
        if not duration:
            return None
        if duration.endswith("min"):
            digits = "".join(ch for ch in duration if ch.isdigit())
            return int(digits) if digits else None
        if "hour" in duration:
            digits = "".join(ch for ch in duration if ch.isdigit())
            return int(digits) * 60 if digits else 120
        return None

    def _build_hard_fallback_resources(self, *, track_name: str, week: Dict[str, Any], skill_name: Optional[str], available_hours_per_week: int) -> List[Dict[str, Any]]:
        topic = week.get("topic", "Learning topic")
        skill = skill_name or (week.get("focus_skills") or ["General Skill"])[0]
        youtube_query = topic.replace(" ", "+")
        return [
            {
                "title": f"{topic} docs",
                "url": "https://scikit-learn.org/stable/user_guide.html" if "data" in track_name.lower() else "https://developer.mozilla.org/",
                "type": "docs",
                "snippet": f"Fallback docs for {skill}",
                "duration": "30 min",
                "source_provider": "hard_fallback",
            },
            {
                "title": f"{topic} practice",
                "url": "https://www.kaggle.com/learn",
                "type": "practice",
                "snippet": f"Fallback practice for {skill}",
                "duration": "2 hours",
                "source_provider": "hard_fallback",
            },
            {
                "title": f"{topic} project",
                "url": "https://github.com/topics/machine-learning" if "data" in track_name.lower() else "https://github.com/topics/software-engineering",
                "type": "project",
                "snippet": f"Fallback project for {skill}",
                "duration": "full course",
                "source_provider": "hard_fallback",
            },
            {
                "title": f"{topic} tutorial 1",
                "url": f"https://www.youtube.com/results?search_query={youtube_query}+tutorial",
                "type": "youtube",
                "snippet": f"Fallback video for {skill}",
                "duration": "10 min",
                "youtube_duration_minutes": 10,
                "source_provider": "hard_fallback",
            },
        ]
