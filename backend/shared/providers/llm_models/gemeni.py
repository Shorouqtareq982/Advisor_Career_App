import asyncio
from typing import Optional, Type
from google import genai
from google.genai import types
import pandas as pd
from pydantic import BaseModel, Field
from .llm_provider import LLMProvider
from core.config import Settings

class Gemini(LLMProvider): 
    def __init__(self, settings: Settings, system_prompt = None):
        self.settings = settings
        self.client = genai.Client(api_key=settings.GEMINI_API_KEY)
        self.system_prompt = system_prompt
        self.model = settings.GEMINI_MODEL
    
    async def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1
    ):
        try:
            generation_config = types.GenerateContentConfig(
                temperature=temperature,
                max_output_tokens=4000 if expecting_longer_output else None,
                response_mime_type="application/json" if need_json_output else None,
                response_schema=schema.model_json_schema() if schema else None,
                system_instruction=self.system_prompt
            )

            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=self.model,
                contents=prompt,
                config=generation_config
            )

            result = schema.model_validate_json(response.text) if schema else response.text

            if result is None:
                print("LLM returned empty response")
                print(response)

            return result

        except Exception as e:
            print("LLM error:", e)
            return None

    async def get_embedding(self, content, model=None, task_type=None):
        if model is None:
            model = self.settings.GEMINI_EMBEDDING_MODEL
        try:
            response = await asyncio.to_thread(
                self.client.models.embed_content,
                model=model,
                content=content,
                config=types.EmbedContentConfig(
                    task_type=task_type
                )
            )
            return response.data[0].embedding
        
        except Exception as e:
            print("LLM embedding error:", e)
            return None