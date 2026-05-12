import logging
from typing import Any, Dict, List, Optional
from uuid import UUID

logger = logging.getLogger(__name__)

BEHAVIORAL_RESPONSES_TABLE = "behavioral_responses"
TECHNICAL_RESPONSES_TABLE = "technical_responses"
BEHAVIORAL_SESSION_TABLE = "behavioral_session"
TECHNICAL_SESSION_TABLE = "technical_session"


class ResponsesRepository:
    def __init__(self, client: Any):
        self.client = client

    async def upsert_behavioral_analysis(
        self,
        session_id: UUID,
        analysis_metrics: Dict[str, Any],
        behavioral_report: str,
        transcript: Optional[str] = None,
        video_url: Optional[str] = None,
        score: Optional[float] = None,
    ) -> Optional[Dict[str, Any]]:
        try:
            payload = {
                "user_response": transcript,
                "analysis_metrics": analysis_metrics,
                "behavioral_report": behavioral_report,
                "status": "completed",
            }
            result = (
                self.client.table(BEHAVIORAL_SESSION_TABLE)
                .update(payload)
                .eq("session_id", str(session_id))
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error upserting behavioral analysis: {e}", exc_info=True)
            raise

    async def upsert_technical_analysis(
        self,
        session_id: UUID,
        technical_report: str,
        transcript: Optional[str] = None,
        video_url: Optional[str] = None,
        score: Optional[float] = None,
    ) -> Optional[Dict[str, Any]]:
        try:
            payload = {
                "user_response": transcript,
                "technical_report": technical_report,
                "status": "completed",
            }
            result = (
                self.client.table(TECHNICAL_SESSION_TABLE)
                .update(payload)
                .eq("session_id", str(session_id))
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error upserting technical analysis: {e}", exc_info=True)
            raise

    async def get_session_analysis(self, session_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            b_result = (
                self.client.table(BEHAVIORAL_SESSION_TABLE)
                .select("*")
                .eq("session_id", str(session_id))
                .limit(1)
                .execute()
            )
            t_result = (
                self.client.table(TECHNICAL_SESSION_TABLE)
                .select("*")
                .eq("session_id", str(session_id))
                .limit(1)
                .execute()
            )

            b = b_result.data[0] if b_result.data else None
            t = t_result.data[0] if t_result.data else None

            if not b and not t:
                return None

            analysis_id = str(session_id)
            analyzed_at = b.get("created_at") if b else None
            t_created = t.get("created_at") if t else None
            if t_created and (not analyzed_at or str(t_created) > str(analyzed_at)):
                analyzed_at = t_created

            return {
                "analysis_id": analysis_id,
                "behavioral_report": b.get("behavioral_report") if b else None,
                "technical_report": t.get("technical_report") if t else None,
                "analysis_metrics": {
                    "behavioral": b or {},
                    "technical": t or {},
                },
                "analyzed_at": analyzed_at,
            }
        except Exception as e:
            logger.error(f"Error getting session analysis: {e}", exc_info=True)
            raise

    async def save_behavioral_response(
        self,
        user_id: int,
        session_id: int,
        report: str,
        analytics_metrics: Dict[str, Any],
        user_response: str,
        strengths: List[str],
        weaknesses: List[str],
        suggestions: List[str],
    ) -> None:
        """Saves the entire behavioral response payload to the database."""
        try:
            payload = {
                "user_id": user_id,
                "session_id": session_id,
                "report": report,
                "analytics_metrics": analytics_metrics,
                "user_response": user_response,
                "strengths": strengths,
                "weaknesses": weaknesses,
                "suggestions": suggestions,
            }
            await self.client.table(BEHAVIORAL_RESPONSES_TABLE).insert(payload).execute()
        except Exception as e:
            logger.error(f"Error saving behavioral response: {e}", exc_info=True)
            raise

    async def save_technical_response(
        self,
        user_id: int,
        session_id: int,
        report: str,
        user_response: str,
        strengths: List[str],
        weaknesses: List[str],
        suggestions: List[str],
    ) -> None:
        """Saves the entire technical response payload to the database."""
        try:
            payload = {
                "user_id": user_id,
                "session_id": session_id,
                "report": report,
                "user_response": user_response,
                "strengths": strengths,
                "weaknesses": weaknesses,
                "suggestions": suggestions,
            }
            await self.client.table(TECHNICAL_RESPONSES_TABLE).insert(payload).execute()
        except Exception as e:
            logger.error(f"Error saving technical response: {e}", exc_info=True)
            raise