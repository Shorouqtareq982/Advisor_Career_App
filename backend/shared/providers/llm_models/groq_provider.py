import logging
from typing import Optional, Type, Any

import httpx
from pydantic import BaseModel

from .llm_provider import LLMProvider
from core.config import Settings

logger = logging.getLogger(__name__)


class GroqProvider(LLMProvider):
    def __init__(self, settings: Settings, system_prompt: Optional[str] = None, model: Optional[str] = None):
        self.settings = settings
        self.system_prompt = system_prompt
        self.api_key = settings.GROQ_API_KEY
        self.model = model or settings.GROQ_MODEL or "llama-3.3-70b-versatile"
        self.base_url = "https://api.groq.com/openai/v1"

        if not self.api_key:
            raise ValueError("GROQ_API_KEY is missing - cannot initialize Groq provider")

        logger.info(f"Groq provider initialized with model: {self.model}")

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
                    "content": self.system_prompt,
                })

            messages.append({
                "role": "user",
                "content": prompt,
            })

            if need_json_output and expecting_longer_output:
                max_tokens = 4000
            elif need_json_output:
                max_tokens = 2500
            elif expecting_longer_output:
                max_tokens = 2000
            else:
                max_tokens = 1200

            payload = {
                "model": self.model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
            }

            if need_json_output and schema is None:
                payload["response_format"] = {"type": "json_object"}

            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }

            timeout = httpx.Timeout(90.0, connect=20.0)

            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=headers,
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()

            choices = data.get("choices", [])
            if not choices:
                logger.error("Groq returned no choices")
                return None

            message = choices[0].get("message", {})
            response_text = message.get("content")

            if not response_text or not str(response_text).strip():
                logger.error("Groq returned empty content")
                return None

            if not need_json_output:
                return str(response_text)

            parsed_obj = None
            try:
                import json
                parsed_obj = json.loads(str(response_text))
                if isinstance(parsed_obj, str):
                    parsed_obj = json.loads(parsed_obj)
            except Exception as exc:
                logger.error(f"Groq JSON decode failed: {exc}")
                return None

            if schema:
                try:
                    return schema.model_validate(parsed_obj)
                except Exception as schema_error:
                    logger.error(f"Groq schema validation failed: {schema_error}")
                    return parsed_obj

            return parsed_obj

        except httpx.ReadTimeout:
            logger.error("Groq API timeout", exc_info=True)
            return None
        except Exception as exc:
            logger.error(f"Groq API error {type(exc).__name__}: {exc}", exc_info=True)
            return None

    async def get_embedding(
        self,
        content: str,
        model: Optional[str] = None,
        task_type: Optional[str] = None
    ) -> Any:
        logger.warning("Groq embeddings are not supported")
        return None
