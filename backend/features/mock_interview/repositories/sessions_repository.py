import logging
from typing import Any, Dict, Optional
from uuid import UUID

logger = logging.getLogger(__name__)

BEHAVIORAL_SESSION_TABLE = "behavioral_session"
TECHNICAL_SESSION_TABLE  = "technical_session"


class SessionsRepository:
    def __init__(self, client: Any):
        self.client = client

    def _resolve_session_table(self, session_type: str) -> str:
        session_type_normalized = (session_type or "").strip().lower()
        if session_type_normalized.startswith("tech"):
            return TECHNICAL_SESSION_TABLE
        return BEHAVIORAL_SESSION_TABLE

    def _get_session_from_table(self, table_name: str, session_id: UUID) -> Optional[Dict[str, Any]]:
        result = (
            self.client.table(table_name)
            .select("*")
            .eq("session_id", str(session_id))
            .limit(1)
            .execute()
        )
        if not result.data:
            return None
        row = result.data[0]
        row["_session_table"] = table_name
        return row

    def _get_session_from_any_table(self, session_id: UUID) -> Optional[Dict[str, Any]]:
        for table_name in (BEHAVIORAL_SESSION_TABLE, TECHNICAL_SESSION_TABLE):
            try:
                row = self._get_session_from_table(table_name, session_id)
                if row:
                    return row
            except Exception:
                continue
        return None

    async def create_session(
        self,
        user_id: UUID,
        role_id: UUID,
        session_type: str = "behavioral",
    ) -> Optional[Dict[str, Any]]:
        try:
            table_name = self._resolve_session_table(session_type)
            payload = {
                "user_id": str(user_id),
                "role_id": str(role_id),
                "status": "pending",
            }
            result = self.client.table(table_name).insert(payload).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error creating session: {e}", exc_info=True)
            raise

    async def get_session(self, session_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            return self._get_session_from_any_table(session_id)
        except Exception as e:
            logger.error(f"Error getting session: {e}", exc_info=True)
            raise

    async def update_session_status(self, session_id: UUID, status: str) -> Optional[Dict[str, Any]]:
        try:
            session = self._get_session_from_any_table(session_id)
            if not session:
                return None
            table_name = session["_session_table"]
            result = (
                self.client.table(table_name)
                .update({"status": status})
                .eq("session_id", str(session_id))
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error updating session status: {e}", exc_info=True)
            raise

    async def claim_session_for_processing(self, session_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            session = self._get_session_from_any_table(session_id)
            if not session:
                return None
            table_name = session["_session_table"]
            result = (
                self.client.table(table_name)
                .update({"status": "in_progress"})
                .eq("session_id", str(session_id))
                .in_("status", ["pending"])
                .execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error claiming session for processing: {e}", exc_info=True)
            raise