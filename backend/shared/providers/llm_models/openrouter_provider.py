import json
import logging
from typing import Optional, Type, Any

import httpx
from pydantic import BaseModel

from .llm_provider import LLMProvider
from core.config import Settings

logger = logging.getLogger(__name__)


class OpenRouterProvider(LLMProvider):
    def __init__(self, settings: Settings, system_prompt: Optional[str] = None):
        self.settings = settings
        self.system_prompt = system_prompt
        self.api_key = settings.OPENROUTER_API_KEY
        self.model = settings.OPENROUTER_MODEL or "openai/gpt-4o-mini"
        self.base_url = "https://openrouter.ai/api/v1"

        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY is missing")

        logger.info(f"OpenRouter provider initialized with model: {self.model}")

    async def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1
    ) -> Any:
        try:
            messages = []

            if self.system_prompt:
                messages.append({
                    "role": "system",
                    "content": self.system_prompt
                })

            messages.append({
                "role": "user",
                "content": prompt
            })

            payload = {
                "model": self.model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": 4000 if expecting_longer_output else 2000,
            }

            if need_json_output:
                payload["response_format"] = {"type": "json_object"}

            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }

            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=headers,
                    json=payload
                )
                response.raise_for_status()
                data = response.json()

            choices = data.get("choices", [])
            if not choices:
                logger.error("OpenRouter returned no choices")
                return None

            message = choices[0].get("message", {})
            response_text = message.get("content")

            if not response_text or not str(response_text).strip():
                logger.error("OpenRouter returned empty content")
                return None

            response_text = self._extract_json_if_needed(str(response_text), need_json_output)

            if schema:
                try:
                    return schema.model_validate_json(response_text)
                except Exception as schema_error:
                    logger.error(
                        f"Schema validation failed: {schema_error}, response text: {response_text[:300]}"
                    )
                    return response_text

            return response_text

        except Exception as e:
            logger.error(f"OpenRouter API error {type(e).__name__}: {str(e)}", exc_info=True)
            return None

    async def get_embedding(
        self,
        content: str,
        model: Optional[str] = None,
        task_type: Optional[str] = None
    ) -> Any:
        """
        Optional embeddings via OpenRouter.
        If you are not using embeddings through OpenRouter yet, you can keep returning None.
        """
        embedding_model = model or "openai/text-embedding-3-small"

        try:
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }

            payload = {
                "model": embedding_model,
                "input": content
            }

            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{self.base_url}/embeddings",
                    headers=headers,
                    json=payload
                )
                response.raise_for_status()
                data = response.json()

            items = data.get("data", [])
            if not items:
                logger.error("OpenRouter embeddings returned no data")
                return None

            return items[0].get("embedding")

        except Exception as e:
            logger.error(f"OpenRouter embedding error {type(e).__name__}: {str(e)}", exc_info=True)
            return None

    def _extract_json_if_needed(self, text: str, need_json_output: bool) -> str:
        if not need_json_output:
            return text

        cleaned = text.strip()

        if cleaned.startswith("{") and cleaned.endswith("}"):
            return cleaned

        start = cleaned.find("{")
        end = cleaned.rfind("}")

        if start != -1 and end != -1 and end > start:
            return cleaned[start:end + 1]

        return cleaned