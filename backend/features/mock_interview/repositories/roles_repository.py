import logging
from typing import Any, Dict, Optional
from uuid import UUID

logger = logging.getLogger(__name__)


class RolesRepository:
    def __init__(self, client: Any):
        self.client = client

    async def get_role_by_name(self, role_name: str) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("roles").select("*").eq("role_name", role_name).limit(1).execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting role by name: {e}", exc_info=True)
            raise

    async def get_role_by_id(self, role_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            result = (
                self.client.table("roles").select("*").eq("role_id", str(role_id)).limit(1).execute()
            )
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting role by id: {e}", exc_info=True)
            raise
