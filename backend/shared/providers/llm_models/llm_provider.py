from abc import ABC, abstractmethod
from typing import Optional, Type
from fastapi import Depends
from pydantic import BaseModel

from core.config import Settings, get_settings

class LLMProvider(ABC):
    """
    Interface for any LLM provider.
    """

    @abstractmethod
    def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1
    ):
        """
        Generate a response from the LLM based on a prompt.
        """
        pass

    @abstractmethod
    def get_embedding(self, content: str, model: Optional[str] = None, task_type: Optional[str] = None):
        """
        Generate embeddings for given content.
        """
        pass

def create_llm_provider(settings:Settings = None, system_prompt: str = None) -> LLMProvider:
    """
    Factory function to create an instance of the appropriate LLM provider based on settings.
    """
    settings = settings or get_settings()
    if settings.LLM_PROVIDER == "gemini":
        from .gemeni import Gemini
        return Gemini(settings, system_prompt=system_prompt)
    else:
        raise ValueError(f"Unsupported LLM provider: {settings.LLM_PROVIDER}")
