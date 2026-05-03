"""
Mistral AI LLM Provider
Provides integration with Mistral AI for language model capabilities.
"""

import json
import logging
import re
from typing import Optional, Type, Any

import httpx
from pydantic import BaseModel

from .llm_provider import LLMProvider
from core.config import Settings

logger = logging.getLogger(__name__)


class MistralProvider(LLMProvider):
    """Mistral AI provider implementation"""

    def __init__(self, settings: Settings, system_prompt: Optional[str] = None, model: Optional[str] = None):
        self.settings = settings
        self.system_prompt = system_prompt
        self.api_key = settings.MISTRAL_API_KEY
        self.model = model or settings.MISTRAL_MODEL or "mistral-large-latest"
        self.base_url = "https://api.mistral.ai/v1"

        if not self.api_key:
            raise ValueError("MISTRAL_API_KEY is missing")

        logger.info(f"✅ Mistral provider initialized with model: {self.model}")

    async def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1,
    ) -> Any:
        """
        Get response from Mistral AI.

        Args:
            prompt: User prompt
            expecting_longer_output: Whether longer output is expected
            need_json_output: Whether JSON output is needed
            schema: Optional Pydantic schema for JSON parsing
            temperature: Temperature for generation (0-1)

        Returns:
            Parsed response or raw text
        """
        try:
            messages = []

            if self.system_prompt:
                messages.append({"role": "system", "content": self.system_prompt})

            messages.append({"role": "user", "content": prompt})

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": self.model,
                        "messages": messages,
                        "temperature": temperature,
                        "top_p": 0.9,
                        "max_tokens": 8000 if expecting_longer_output else 2000,
                    },
                    timeout=60.0,
                )

                if response.status_code != 200:
                    logger.error(f"Mistral API error: {response.status_code} - {response.text}")
                    raise Exception(f"Mistral API error: {response.status_code}")

                result = response.json()
                response_text = result["choices"][0]["message"]["content"]

                # Parse JSON if requested
                if need_json_output:
                    return self._parse_json_response(response_text, schema)

                return response_text

        except Exception as e:
            logger.error(f"Error getting response from Mistral: {str(e)}")
            raise

    async def get_embedding(
        self,
        content: str,
        model: Optional[str] = None,
        task_type: Optional[str] = None,
    ) -> Any:
        """
        Get embeddings from Mistral AI.

        Args:
            content: Text to embed
            model: Optional embedding model (defaults to mistral-embed)
            task_type: Optional task type specification

        Returns:
            Embedding vector
        """
        try:
            embedding_model = model or "mistral-embed"

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/embeddings",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": embedding_model,
                        "input": content,
                    },
                    timeout=30.0,
                )

                if response.status_code != 200:
                    logger.error(f"Mistral embedding error: {response.status_code}")
                    raise Exception(f"Mistral embedding error: {response.status_code}")

                result = response.json()
                return result["data"][0]["embedding"]

        except Exception as e:
            logger.error(f"Error getting embedding from Mistral: {str(e)}")
            raise

    def _parse_json_response(
        self, response_text: str, schema: Optional[Type[BaseModel]] = None
    ) -> Any:
        """
        Parse JSON from Mistral response.

        Args:
            response_text: Raw response text
            schema: Optional Pydantic schema for validation

        Returns:
            Parsed JSON object or schema instance
        """
        try:
            # Extract JSON from response (may be wrapped in text)
            json_match = re.search(r"\{.*\}", response_text, re.DOTALL)
            if json_match:
                json_str = json_match.group()
                parsed = json.loads(json_str)

                if schema:
                    return schema(**parsed)
                return parsed

            logger.warning("No JSON found in response")
            return None

        except Exception as e:
            logger.error(f"Error parsing JSON response: {str(e)}")
            raise
