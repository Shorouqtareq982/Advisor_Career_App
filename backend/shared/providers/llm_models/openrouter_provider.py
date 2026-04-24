import json
import logging
import re
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
            raise ValueError("OPENROUTER_API_KEY is missing - cannot initialize OpenRouter provider")

        logger.info(f"✅ OpenRouter provider initialized with model: {self.model}")

    async def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1
    ) -> Any:
        try:
            print("===== OPENROUTER DEBUG START =====")
            print("PROVIDER:", getattr(self.settings, "LLM_PROVIDER", None))
            print("MODEL:", self.model)
            print("KEY STARTS WITH:", self.api_key[:12] if self.api_key else None)

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

            # Reduced token limits to avoid 402 / insufficient credits issues
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
            elif need_json_output and schema:
                raw_schema = schema.model_json_schema()
                strict_schema = self.enforce_strict_schema(raw_schema)
                payload["response_format"] = {
                    "type": "json_schema",
                    "json_schema": {
                        "name": schema.__name__,
                        "schema": strict_schema,
                        "strict": True,
                    },
                }

            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }

            timeout = httpx.Timeout(90.0, connect=20.0)

            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=headers,
                    json=payload
                )

                try:
                    response.raise_for_status()
                except httpx.HTTPStatusError as e:
                    error_msg = f"OpenRouter API Error {e.response.status_code}"

                    if e.response.status_code == 401:
                        error_msg = "OpenRouter: Authentication failed - Invalid API key"
                    elif e.response.status_code == 402:
                        error_msg = "OpenRouter: Insufficient credits or max_tokens too high"
                    elif e.response.status_code == 429:
                        error_msg = "OpenRouter: Rate limit exceeded - Too many requests"
                    elif e.response.status_code == 503:
                        error_msg = "OpenRouter: Service unavailable - Try fallback provider"
                    elif e.response.status_code == 504:
                        error_msg = "OpenRouter: Gateway timeout - Try fallback provider"

                    logger.error(
                        "OpenRouter HTTP error. Status=%s Reason=%s Response=%s",
                        e.response.status_code,
                        error_msg,
                        e.response.text,
                        exc_info=True
                    )
                    return None

                data = response.json()

            print("===== OPENROUTER DEBUG END =====")

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

            parsed_obj = None
            if need_json_output:
                try:
                    parsed_obj = json.loads(response_text)

                    # handle double-encoded JSON (LLM sometimes does this)
                    if isinstance(parsed_obj, str):
                        parsed_obj = json.loads(parsed_obj)

                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode failed: {e}, raw: {response_text[:300]}")
                    return None
            
            if schema:
                try:
                    if parsed_obj is None:
                        return schema.model_validate_json(response_text)
                    return schema.model_validate(parsed_obj)

                except Exception as schema_error:
                    logger.error(
                        f"Schema validation failed: {schema_error}, response text: {response_text[:300]}"
                    )
                    return parsed_obj if parsed_obj else response_text

            if need_json_output:
                return parsed_obj
            
            return response_text

        except httpx.ReadTimeout:
            logger.error("OpenRouter API timeout - provider took too long to respond", exc_info=True)
            return None
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

            timeout = httpx.Timeout(60.0, connect=20.0)

            async with httpx.AsyncClient(timeout=timeout) as client:
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
            json_str = cleaned[start:end + 1]

            try:
                import json as json_module
                json_module.loads(json_str)
                return json_str
            except json.JSONDecodeError:
                open_braces = json_str.count("{")
                close_braces = json_str.count("}")
                open_brackets = json_str.count("[")
                close_brackets = json_str.count("]")

                if open_braces > close_braces:
                    json_str += "}" * (open_braces - close_braces)

                if open_brackets > close_brackets:
                    json_str += "]" * (open_brackets - close_brackets)

                json_str = re.sub(r",\s*([\]\}])", r"\1", json_str)
                return json_str

        return cleaned
    
    def enforce_strict_schema(self, schema: dict) -> dict:
        if isinstance(schema, dict):
            if schema.get("type") == "object":
                schema["additionalProperties"] = False

            for key, value in schema.items():
                self.enforce_strict_schema(value)

        elif isinstance(schema, list):
            for item in schema:
                self.enforce_strict_schema(item)

        return schema