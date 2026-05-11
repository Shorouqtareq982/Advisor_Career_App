import logging
from typing import Any, Dict, List, Optional
from uuid import NAMESPACE_URL, UUID, uuid5

logger = logging.getLogger(__name__)

BEHAVIORAL_QUESTION_TEXTS = [
    "Tell me about a time you had to collaborate closely with someone whose working style was very different from yours.",
    "Describe a situation where you took initiative on a problem that wasn't strictly your responsibility.",
    "Walk me through a time you disagreed with your manager or a colleague on how to handle something at work.",
    "Tell me about a time you had multiple urgent priorities at once. How did you decide what to tackle first?",
    "Share a mistake you made at work. What happened and what did you do about it?",
]


def _behavioral_question_id(text: str) -> UUID:
    return uuid5(NAMESPACE_URL, f"mock-interview-behavioral::{text}")


def _behavioral_question_records() -> List[Dict[str, Any]]:
    return [{"question_id": str(_behavioral_question_id(text)), "question_text": text} for text in BEHAVIORAL_QUESTION_TEXTS]


def _behavioral_question_id_set() -> set[str]:
    return {item["question_id"] for item in _behavioral_question_records()}


class QuestionsRepository:
    def __init__(self, client: Any):
        self.client = client

    async def list_behavioral_questions(self, role_name: Optional[str] = None) -> List[Dict[str, Any]]:
        return _behavioral_question_records()

    async def list_technical_questions(self, role_id: UUID) -> List[Dict[str, Any]]:
        try:
            result = (
                self.client.table("technical_questions")
                .select("question_id, question_text")
                .eq("role_id", str(role_id))
                .order("created_at")
                .execute()
            )
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error listing technical questions: {e}", exc_info=True)
            raise

    async def get_technical_question_text(self, question_id: UUID) -> Optional[str]:
        try:
            result = (
                self.client.table("technical_questions").select("question_text").eq("question_id", str(question_id)).limit(1).execute()
            )
            if not result.data:
                return None
            return result.data[0].get("question_text")
        except Exception as e:
            logger.error(f"Error getting technical question text: {e}", exc_info=True)
            raise

    async def get_behavioral_question_text(self, question_id: UUID) -> Optional[str]:
        for item in _behavioral_question_records():
            if item["question_id"] == str(question_id):
                return item["question_text"]
        return None

    async def get_question_text(self, question_id: UUID) -> Optional[str]:
        behavioral_text = await self.get_behavioral_question_text(question_id)
        if behavioral_text:
            return behavioral_text
        return await self.get_technical_question_text(question_id)
