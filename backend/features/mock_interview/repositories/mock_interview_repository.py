from typing import Any
from .roles_repository import RolesRepository
from .sessions_repository import SessionsRepository
from .questions_repository import QuestionsRepository
from .responses_repository import ResponsesRepository


class MockInterviewRepository:
    """Facade repository composing smaller repository modules.

    Keeps the same import path so existing services/routers continue to work.
    Methods are delegated to the module that owns them.
    """

    def __init__(self, db_provider: Any):
        # previous code used db_provider.client
        client = getattr(db_provider, "client", db_provider)
        self.roles = RolesRepository(client)
        self.sessions = SessionsRepository(client)
        self.questions = QuestionsRepository(client)
        self.responses = ResponsesRepository(client)

    def __getattr__(self, name: str):
        for repo in (self.roles, self.sessions, self.questions, self.responses):
            if hasattr(repo, name):
                return getattr(repo, name)
        raise AttributeError(f"MockInterviewRepository has no attribute {name}")
