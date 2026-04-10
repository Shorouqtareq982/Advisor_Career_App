from abc import ABC, abstractmethod
from typing import Optional, Type, Any
from pydantic import BaseModel

from core.config import Settings, get_settings


class LLMProvider(ABC):
    @abstractmethod
    async def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1
    ) -> Any:
        pass

    @abstractmethod
    async def get_embedding(
        self,
        content: str,
        model: Optional[str] = None,
        task_type: Optional[str] = None
    ) -> Any:
        pass


def create_llm_provider(
    settings: Optional[Settings] = None,
    system_prompt: Optional[str] = None
) -> LLMProvider:
    settings = settings or get_settings()

    if settings.LLM_PROVIDER == "gemini":
        from .gemini import Gemini
        return Gemini(settings, system_prompt=system_prompt)

    if settings.LLM_PROVIDER == "openrouter":
        from .openrouter_provider import OpenRouterProvider
        return OpenRouterProvider(settings, system_prompt=system_prompt)

    raise ValueError(f"Unsupported LLM provider: {settings.LLM_PROVIDER}")