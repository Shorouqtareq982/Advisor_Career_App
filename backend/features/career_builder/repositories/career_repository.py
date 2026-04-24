import logging
from uuid import UUID
from typing import Optional, Dict, Any, List

logger = logging.getLogger(__name__)


class CareerRepository:
    def __init__(self, db_provider):
        self.client = db_provider.client
        logger.debug("CareerRepository initialized")

    # =====================================================
    # TRACKS
    # =====================================================

    async def get_track_by_id(self, track_id: int) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("career_tracks")
                .select("*")
                .eq("track_id", track_id)
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting track by id: {e}", exc_info=True)
            raise

    async def get_all_tracks(self) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("career_tracks")
                .select("*")
                .order("track_name")
                .execute()
            )
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error getting all tracks: {e}", exc_info=True)
            raise

    async def search_skills_by_name(self, query: str) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("career_skills")
                .select("*")
                .ilike("skill_name", f"%{query}%")
                .execute()
            )
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error searching skills: {e}", exc_info=True)
            raise

    async def get_skills_by_track(
        self,
        track_id: int,
        level: str = "beginner"
    ) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("track_skills")
                .select("""
                    skill_id,
                    importance_weight,
                    required_weeks,
                    is_core,
                    career_skills (
                        skill_id,
                        skill_name,
                        category,
                        aliases
                    )
                """)
                .eq("track_id", track_id)
                .execute()
            )

            rows = result.data if result.data else []
            skills = []

            for row in rows:
                skill_data = row.get("career_skills") or {}

                required_weeks = row.get("required_weeks")
                if not required_weeks or required_weeks <= 0:
                    logger.warning(
                        f"Skill {skill_data.get('skill_name')} has invalid required_weeks: {required_weeks}"
                    )
                    required_weeks = 4

                aliases = skill_data.get("aliases") or []
                if not isinstance(aliases, list):
                    aliases = []

                skills.append({
                    "skill_id": skill_data.get("skill_id") or row.get("skill_id"),
                    "skill_name": skill_data.get("skill_name"),
                    "category": skill_data.get("category", "General"),
                    "aliases": aliases,
                    "importance_weight": int(row.get("importance_weight", 3) or 3),
                    "required_weeks": int(required_weeks),
                    "is_core": bool(row.get("is_core", True)),
                })

            return skills

        except Exception as e:
            logger.error(f"Error getting skills by track: {e}", exc_info=True)
            raise

    # =====================================================
    # CV
    # =====================================================

    async def save_cv(
        self,
        file_url: str,
        text_content: str,
        parsed_content: dict,
        user_id: Optional[UUID] = None
    ) -> Optional[UUID]:
        try:
            data = {
                "file_url": file_url,
                "text_content": text_content,
                "parsed_content": parsed_content
            }

            if user_id:
                data["user_id"] = str(user_id)

            result = self.client.table("cv").insert(data).execute()
            return UUID(result.data[0]["cv_id"]) if result.data else None

        except Exception as e:
            logger.error(f"Error saving CV: {e}", exc_info=True)
            raise

    async def get_cv_by_id(self, cv_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("cv")
                .select("*")
                .eq("cv_id", str(cv_id))
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting CV by id: {e}", exc_info=True)
            raise

    async def get_user_cvs(self, user_id: UUID) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("cv")
                .select("*")
                .eq("user_id", str(user_id))
                .execute()
            )
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error getting user CVs: {e}", exc_info=True)
            raise

    # =====================================================
    # ANALYSIS CACHE
    # =====================================================

    async def save_analysis_cache(
        self,
        cv_id: UUID,
        track_id: int,
        analysis_data: dict,
        state_version: Optional[int] = None
    ) -> None:
        try:
            existing = (
                self.client.table("analysis_cache")
                .select("*")
                .eq("cv_id", str(cv_id))
                .eq("track_id", track_id)
                .execute()
            )

            if existing.data:
                current = existing.data[0]
                previous_version = int(current.get("state_version") or 1)
                next_version = state_version if state_version is not None else previous_version + 1

                (
                    self.client.table("analysis_cache")
                    .update({
                        "analysis_data": analysis_data,
                        "state_version": next_version,
                    })
                    .eq("cv_id", str(cv_id))
                    .eq("track_id", track_id)
                    .execute()
                )
            else:
                payload = {
                    "cv_id": str(cv_id),
                    "track_id": track_id,
                    "analysis_data": analysis_data,
                    "state_version": state_version or 1,
                }
                self.client.table("analysis_cache").insert(payload).execute()

        except Exception as e:
            logger.error(f"Error saving analysis cache: {e}", exc_info=True)
            raise

    async def get_analysis_cache(
        self,
        cv_id: UUID,
        track_id: int
    ) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("analysis_cache")
                .select("*")
                .eq("cv_id", str(cv_id))
                .eq("track_id", track_id)
                .execute()
            )

            if result.data:
                raw = result.data[0].get("analysis_data")
                if isinstance(raw, dict):
                    return raw
                if isinstance(raw, str):
                    import json
                    return json.loads(raw)
                return None

            return None

        except Exception as e:
            logger.error(f"Error getting analysis cache: {e}", exc_info=True)
            raise

    async def get_analysis_cache_record(
        self,
        cv_id: UUID,
        track_id: int
    ) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("analysis_cache")
                .select("*")
                .eq("cv_id", str(cv_id))
                .eq("track_id", track_id)
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting analysis cache record: {e}", exc_info=True)
            raise

    async def delete_analysis_cache(self, cv_id: UUID, track_id: int) -> None:
        try:
            (
                self.client.table("analysis_cache")
                .delete()
                .eq("cv_id", str(cv_id))
                .eq("track_id", track_id)
                .execute()
            )
        except Exception as e:
            logger.error(f"Error deleting analysis cache: {e}", exc_info=True)
            raise

    # =====================================================
    # PLAN PERSISTENCE
    # =====================================================

    async def create_plan(
        self,
        user_id: UUID,
        cv_id: UUID,
        track_id: int,
        detected_level: str,
        confirmed_level: str,
        duration_weeks: int,
        realism_flag: bool = False,
        suggested_min_weeks: Optional[int] = None
    ) -> Optional[int]:
        try:
            payload = {
                "user_id": str(user_id),
                "cv_id": str(cv_id),
                "track_id": track_id,
                "detected_level": detected_level,
                "confirmed_level": confirmed_level,
                "duration_weeks": duration_weeks,
                "realism_flag": realism_flag,
                "suggested_min_weeks": suggested_min_weeks
            }

            result = (
                self.client.table("career_plan_info")
                .insert(payload)
                .execute()
            )

            return result.data[0]["plan_id"] if result.data else None

        except Exception as e:
            logger.error(f"Error creating plan: {e}", exc_info=True)
            raise

    async def upsert_plan_info(
        self,
        *,
        user_id: UUID,
        cv_id: UUID,
        track_id: int,
        detected_level: str,
        confirmed_level: str,
        duration_weeks: int,
        realism_flag: bool = False,
        suggested_min_weeks: Optional[int] = None,
        available_hours_per_week: Optional[int] = None,
        requested_weeks: Optional[int] = None,
        realism_zone: Optional[str] = None,
        confirmed_learning_targets: Optional[List[Dict[str, Any]]] = None,
        detected_skill_levels: Optional[Dict[str, Any]] = None,
        selected_skill_ids: Optional[List[int]] = None,
        generation_mode: Optional[str] = None,
        state_version: int = 1,
    ) -> Optional[int]:
        try:
            existing = (
                self.client.table("career_plan_info")
                .select("*")
                .eq("user_id", str(user_id))
                .eq("cv_id", str(cv_id))
                .eq("track_id", track_id)
                .order("created_at", desc=True)
                .limit(1)
                .execute()
            )

            payload = {
                "user_id": str(user_id),
                "cv_id": str(cv_id),
                "track_id": track_id,
                "detected_level": detected_level,
                "confirmed_level": confirmed_level,
                "duration_weeks": duration_weeks,
                "realism_flag": realism_flag,
                "suggested_min_weeks": suggested_min_weeks,
                "available_hours_per_week": available_hours_per_week,
                "requested_weeks": requested_weeks,
                "realism_zone": realism_zone,
                "confirmed_learning_targets": confirmed_learning_targets or [],
                "detected_skill_levels": detected_skill_levels or {},
                "selected_skill_ids": selected_skill_ids or [],
                "generation_mode": generation_mode,
                "state_version": state_version,
            }

            if existing.data:
                plan_id = existing.data[0]["plan_id"]
                (
                    self.client.table("career_plan_info")
                    .update(payload)
                    .eq("plan_id", plan_id)
                    .execute()
                )
                return plan_id

            result = (
                self.client.table("career_plan_info")
                .insert(payload)
                .execute()
            )
            return result.data[0]["plan_id"] if result.data else None

        except Exception as e:
            logger.error(f"Error upserting plan info: {e}", exc_info=True)
            raise

    async def replace_plan_user_skills(
        self,
        plan_id: int,
        skills_data: List[Dict[str, Any]]
    ) -> None:
        try:
            (
                self.client.table("career_user_skills")
                .delete()
                .eq("plan_id", plan_id)
                .execute()
            )

            if not skills_data:
                return

            self.client.table("career_user_skills").insert(skills_data).execute()

        except Exception as e:
            logger.error(f"Error replacing plan user skills: {e}", exc_info=True)
            raise

    async def replace_plan_content(
        self,
        plan_id: int,
        weekly_data: List[Dict[str, Any]]
    ) -> None:
        try:
            (
                self.client.table("career_plan_content")
                .delete()
                .eq("plan_id", plan_id)
                .execute()
            )

            if not weekly_data:
                return

            self.client.table("career_plan_content").insert(weekly_data).execute()

        except Exception as e:
            logger.error(f"Error replacing plan content: {e}", exc_info=True)
            raise

    async def insert_plan_content(self, weekly_data: List[Dict[str, Any]]) -> None:
        try:
            if not weekly_data:
                return
            self.client.table("career_plan_content").insert(weekly_data).execute()
        except Exception as e:
            logger.error(f"Error inserting plan content: {e}", exc_info=True)
            raise

    async def insert_user_skills(self, skills_data: List[Dict[str, Any]]) -> None:
        try:
            if not skills_data:
                return
            self.client.table("career_user_skills").insert(skills_data).execute()
        except Exception as e:
            logger.error(f"Error inserting user skills: {e}", exc_info=True)
            raise

    async def get_plan_by_id(self, plan_id: int) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("career_plan_info")
                .select("*")
                .eq("plan_id", plan_id)
                .execute()
            )
            return result.data[0] if result.data else None

        except Exception as e:
            logger.error(f"Error getting plan by id: {e}", exc_info=True)
            raise

    async def get_plan_content(self, plan_id: int) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("career_plan_content")
                .select("*")
                .eq("plan_id", plan_id)
                .order("week_number")
                .execute()
            )
            return result.data if result.data else []

        except Exception as e:
            logger.error(f"Error getting plan content: {e}", exc_info=True)
            raise

    async def get_plan_user_skills(self, plan_id: int) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("career_user_skills")
                .select("*")
                .eq("plan_id", plan_id)
                .execute()
            )
            return result.data if result.data else []

        except Exception as e:
            logger.error(f"Error getting plan user skills: {e}", exc_info=True)
            raise

    async def get_user_plans(self, user_id: UUID) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("career_plan_info")
                .select("*")
                .eq("user_id", str(user_id))
                .order("created_at", desc=True)
                .execute()
            )
            return result.data if result.data else []

        except Exception as e:
            logger.error(f"Error getting user plans: {e}", exc_info=True)
            raise

    # =====================================================
    # CURATED / DISCOVERED LEARNING RESOURCES
    # =====================================================

    def _format_duration_label(self, minutes: Optional[int]) -> Optional[str]:
        if not minutes or int(minutes) <= 0:
            return None

        minutes = int(minutes)
        if minutes >= 60:
            hours = minutes // 60
            rem = minutes % 60
            if rem == 0:
                return f"{hours} hour" if hours == 1 else f"{hours} hours"
            return f"{hours}h {rem}m"

        return f"{minutes} min"

    def _map_learning_resource_row(self, row: Dict[str, Any]) -> Dict[str, Any]:
        resource_type = (row.get("resource_type") or "").strip().lower()
        duration_minutes = row.get("estimated_duration_minutes")

        return {
            "title": row.get("title"),
            "url": row.get("url"),
            "type": resource_type,
            "snippet": row.get("snippet"),
            "duration": self._format_duration_label(duration_minutes),
            "youtube_duration_minutes": duration_minutes if resource_type == "youtube" else None,
            "source_provider": row.get("source_provider"),
            "source_domain": row.get("source_domain"),
            "is_official": bool(row.get("is_official", False)),
            "is_practical": bool(row.get("is_practical", False)),
            "score": float(
                row.get("final_score")
                or row.get("quality_score")
                or row.get("base_score")
                or 0
            ),
        }

    async def get_curated_learning_resources(
        self,
        track_id: int,
        skill_id: int,
        current_level: str,
        target_level: str,
        limit: int = 12,
    ) -> List[Dict[str, Any]]:
        try:
            current_level = (current_level or "none").strip().lower()
            target_level = (target_level or "beginner").strip().lower()

            rows: List[Dict[str, Any]] = []

            exact = (
                self.client.table("curated_learning_resources")
                .select("*")
                .eq("is_active", True)
                .eq("skill_id", skill_id)
                .eq("track_id", track_id)
                .eq("current_level", current_level)
                .eq("target_level", target_level)
                .order("priority", desc=False)
                .order("quality_score", desc=True)
                .limit(limit)
                .execute()
            )
            rows.extend(exact.data or [])

            if len(rows) < limit:
                global_exact = (
                    self.client.table("curated_learning_resources")
                    .select("*")
                    .eq("is_active", True)
                    .eq("skill_id", skill_id)
                    .is_("track_id", "null")
                    .eq("current_level", current_level)
                    .eq("target_level", target_level)
                    .order("priority", desc=False)
                    .order("quality_score", desc=True)
                    .limit(limit)
                    .execute()
                )
                rows.extend(global_exact.data or [])

            if len(rows) < limit:
                soft_none = (
                    self.client.table("curated_learning_resources")
                    .select("*")
                    .eq("is_active", True)
                    .eq("skill_id", skill_id)
                    .or_(f"track_id.eq.{track_id},track_id.is.null")
                    .eq("current_level", "none")
                    .eq("target_level", target_level)
                    .order("priority", desc=False)
                    .order("quality_score", desc=True)
                    .limit(limit)
                    .execute()
                )
                rows.extend(soft_none.data or [])

            final: List[Dict[str, Any]] = []
            seen_urls = set()

            for row in rows:
                url = (row.get("url") or "").strip().lower()
                if not url or url in seen_urls:
                    continue
                seen_urls.add(url)
                final.append(self._map_learning_resource_row(row))
                if len(final) >= limit:
                    break

            return final

        except Exception as e:
            logger.error(f"Error getting curated learning resources: {e}", exc_info=True)
            raise

    async def get_discovered_learning_resources(
        self,
        track_id: int,
        skill_id: int,
        canonical_topic: str,
        current_level: str,
        target_level: str,
        limit: int = 12,
    ) -> List[Dict[str, Any]]:
        try:
            current_level = (current_level or "none").strip().lower()
            target_level = (target_level or "beginner").strip().lower()
            canonical_topic = (canonical_topic or "").strip().lower()

            rows: List[Dict[str, Any]] = []

            exact = (
                self.client.table("discovered_learning_resources")
                .select("*")
                .eq("is_active", True)
                .eq("skill_id", skill_id)
                .eq("track_id", track_id)
                .eq("canonical_topic", canonical_topic)
                .eq("current_level", current_level)
                .eq("target_level", target_level)
                .order("times_validation_passed", desc=True)
                .order("final_score", desc=True)
                .order("updated_at", desc=True)
                .limit(limit)
                .execute()
            )
            rows.extend(exact.data or [])

            if len(rows) < limit:
                global_exact = (
                    self.client.table("discovered_learning_resources")
                    .select("*")
                    .eq("is_active", True)
                    .eq("skill_id", skill_id)
                    .is_("track_id", "null")
                    .eq("canonical_topic", canonical_topic)
                    .eq("current_level", current_level)
                    .eq("target_level", target_level)
                    .order("times_validation_passed", desc=True)
                    .order("final_score", desc=True)
                    .order("updated_at", desc=True)
                    .limit(limit)
                    .execute()
                )
                rows.extend(global_exact.data or [])

            if len(rows) < limit:
                soft_none = (
                    self.client.table("discovered_learning_resources")
                    .select("*")
                    .eq("is_active", True)
                    .eq("skill_id", skill_id)
                    .or_(f"track_id.eq.{track_id},track_id.is.null")
                    .eq("canonical_topic", canonical_topic)
                    .eq("current_level", "none")
                    .eq("target_level", target_level)
                    .order("times_validation_passed", desc=True)
                    .order("final_score", desc=True)
                    .order("updated_at", desc=True)
                    .limit(limit)
                    .execute()
                )
                rows.extend(soft_none.data or [])

            final: List[Dict[str, Any]] = []
            seen_urls = set()

            for row in rows:
                url = (row.get("url") or "").strip().lower()
                if not url or url in seen_urls:
                    continue
                seen_urls.add(url)
                final.append(self._map_learning_resource_row(row))
                if len(final) >= limit:
                    break

            return final

        except Exception as e:
            logger.error(f"Error getting discovered learning resources: {e}", exc_info=True)
            raise

    async def upsert_discovered_learning_resources(
        self,
        rows: List[Dict[str, Any]],
    ) -> None:
        try:
            if not rows:
                return

            for row in rows:
                url = (row.get("url") or "").strip()
                skill_id = row.get("skill_id")
                canonical_topic = (row.get("canonical_topic") or "").strip().lower()
                current_level = (row.get("current_level") or "none").strip().lower()
                target_level = (row.get("target_level") or "beginner").strip().lower()

                if not url or not skill_id or not canonical_topic:
                    continue

                existing = (
                    self.client.table("discovered_learning_resources")
                    .select("*")
                    .eq("skill_id", skill_id)
                    .eq("canonical_topic", canonical_topic)
                    .eq("current_level", current_level)
                    .eq("target_level", target_level)
                    .eq("url", url)
                    .limit(1)
                    .execute()
                )

                if existing.data:
                    existing_row = existing.data[0]

                    (
                        self.client.table("discovered_learning_resources")
                        .update({
                            "times_selected": int(existing_row.get("times_selected", 1) or 1) + int(row.get("times_selected", 1) or 1),
                            "times_validation_passed": int(existing_row.get("times_validation_passed", 1) or 1) + int(row.get("times_validation_passed", 1) or 1),
                            "times_used_in_final_plan": int(existing_row.get("times_used_in_final_plan", 1) or 1) + int(row.get("times_used_in_final_plan", 1) or 1),
                            "final_score": max(
                                float(existing_row.get("final_score", 0) or 0),
                                float(row.get("final_score", 0) or 0),
                            ),
                            "base_score": max(
                                float(existing_row.get("base_score", 0) or 0),
                                float(row.get("base_score", 0) or 0),
                            ),
                            "week_topic": row.get("week_topic"),
                            "source_provider": row.get("source_provider"),
                            "source_domain": row.get("source_domain"),
                            "estimated_duration_minutes": row.get("estimated_duration_minutes"),
                            "is_official": bool(row.get("is_official", False)),
                            "is_practical": bool(row.get("is_practical", False)),
                            "was_fallback": bool(row.get("was_fallback", False)),
                            "track_id": row.get("track_id"),
                            "plan_id": row.get("plan_id"),
                            "title": row.get("title"),
                            "snippet": row.get("snippet"),
                            "resource_type": row.get("resource_type"),
                            "is_active": True,
                        })
                        .eq("id", existing_row["id"])
                        .execute()
                    )
                else:
                    payload = {
                        "track_id": row.get("track_id"),
                        "skill_id": skill_id,
                        "plan_id": row.get("plan_id"),
                        "week_topic": row.get("week_topic"),
                        "canonical_topic": canonical_topic,
                        "current_level": current_level,
                        "target_level": target_level,
                        "resource_type": row.get("resource_type"),
                        "title": row.get("title"),
                        "url": url,
                        "snippet": row.get("snippet"),
                        "source_provider": row.get("source_provider"),
                        "source_domain": row.get("source_domain"),
                        "estimated_duration_minutes": row.get("estimated_duration_minutes"),
                        "base_score": float(row.get("base_score", 0) or 0),
                        "final_score": float(row.get("final_score", 0) or 0),
                        "times_selected": int(row.get("times_selected", 1) or 1),
                        "times_validation_passed": int(row.get("times_validation_passed", 1) or 1),
                        "times_used_in_final_plan": int(row.get("times_used_in_final_plan", 1) or 1),
                        "is_active": bool(row.get("is_active", True)),
                        "is_official": bool(row.get("is_official", False)),
                        "is_practical": bool(row.get("is_practical", False)),
                        "was_fallback": bool(row.get("was_fallback", False)),
                    }
                    self.client.table("discovered_learning_resources").insert(payload).execute()

        except Exception as e:
            logger.error(f"Error upserting discovered learning resources: {e}", exc_info=True)
            raise
