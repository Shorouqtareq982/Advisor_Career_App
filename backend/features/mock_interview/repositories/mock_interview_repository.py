import logging
from typing import Dict, Any, List, Optional
from uuid import UUID

logger = logging.getLogger(__name__)


class MockInterviewRepository:
    def __init__(self, db_provider):
        self.client = db_provider.client
        logger.debug("MockInterviewRepository initialized")

    async def get_role_by_name(self, role_name: str) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("roles")
                .select("*")
                .eq("role_name", role_name)
                .limit(1)
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting role by name: {e}", exc_info=True)
            raise

    async def get_role_by_id(self, role_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("roles")
                .select("*")
                .eq("role_id", str(role_id))
                .limit(1)
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting role by id: {e}", exc_info=True)
            raise

    async def list_behavioral_questions(self, role_name: str) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("behavioral_questions")
                .select("question_id, question_text")
                .eq("role_name", role_name)
                .order("created_at")
                .execute()
            )
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error listing behavioral questions: {e}", exc_info=True)
            raise

    async def get_question_text(self, question_id: UUID) -> Optional[str]:
        try:
            result = (
                self.client.table("behavioral_questions")
                .select("question_text")
                .eq("question_id", str(question_id))
                .limit(1)
                .execute()
            )
            if not result.data:
                return None
            return result.data[0].get("question_text")
        except Exception as e:
            logger.error(f"Error getting question text: {e}", exc_info=True)
            raise

    async def create_session(self, user_id: UUID, role_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            payload = {
                "user_id": str(user_id),
                "role_id": str(role_id),
                "status": "active",
            }
            result = self.client.table("sessions").insert(payload).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error creating session: {e}", exc_info=True)
            raise

    async def get_session(self, session_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("sessions")
                .select("*")
                .eq("session_id", str(session_id))
                .limit(1)
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting session: {e}", exc_info=True)
            raise

    async def update_session_status(self, session_id: UUID, status: str) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("sessions")
                .update({"status": status})
                .eq("session_id", str(session_id))
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error updating session status: {e}", exc_info=True)
            raise

    async def upsert_behavioral_analysis(
        self,
        session_id: UUID,
        analysis_metrics: Dict[str, Any],
        behavioral_report: str,
    ) -> Optional[Dict[str, Any]]:
        try:
            existing = (
                self.client.table("session_analysis")
                .select("analysis_id")
                .eq("response_id", str(session_id))
                .limit(1)
                .execute()
            )
            if existing.data:
                result = (
                    self.client.table("session_analysis")
                    .update({
                        "analysis_metrics": analysis_metrics,
                        "behavioral_report": behavioral_report,
                    })
                    .eq("response_id", str(session_id))
                    .execute()
                )
                return result.data[0] if result.data else None

            result = self.client.table("session_analysis").insert({
                "response_id": str(session_id),
                "analysis_metrics": analysis_metrics,
                "behavioral_report": behavioral_report,
            }).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error upserting behavioral analysis: {e}", exc_info=True)
            raise

    async def upsert_technical_analysis(
        self,
        session_id: UUID,
        technical_report: str,
    ) -> Optional[Dict[str, Any]]:
        try:
            existing = (
                self.client.table("session_analysis")
                .select("analysis_id")
                .eq("response_id", str(session_id))
                .limit(1)
                .execute()
            )
            if existing.data:
                result = (
                    self.client.table("session_analysis")
                    .update({"technical_report": technical_report})
                    .eq("response_id", str(session_id))
                    .execute()
                )
                return result.data[0] if result.data else None

            result = self.client.table("session_analysis").insert({
                "response_id": str(session_id),
                "analysis_metrics": {},
                "technical_report": technical_report,
            }).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error upserting technical analysis: {e}", exc_info=True)
            raise

    async def get_session_analysis(self, session_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("session_analysis")
                .select("*")
                .eq("response_id", str(session_id))
                .limit(1)
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting session analysis: {e}", exc_info=True)
            raise

    async def insert_session_response(
        self,
        user_id: UUID,
        question_id: UUID,
        response: str,
    ) -> Optional[Dict[str, Any]]:
        try:
            payload = {
                "user_id": str(user_id),
                "question_id": str(question_id),
                "response": response,
            }
            result = self.client.table("session_responses").insert(payload).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error inserting session response: {e}", exc_info=True)
            raise

    async def get_latest_response_for_user(self, user_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("session_responses")
                .select("*")
                .eq("user_id", str(user_id))
                .order("created_at", desc=True)
                .limit(1)
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting latest session response: {e}", exc_info=True)
            raise

    async def list_responses_for_user(
        self,
        user_id: UUID,
        limit: int = 25,
    ) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("session_responses")
                .select("*")
                .eq("user_id", str(user_id))
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error listing session responses: {e}", exc_info=True)
            raise
