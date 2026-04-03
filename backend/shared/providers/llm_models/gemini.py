import asyncio
import logging
from typing import Optional, Type
from google import genai
from google.genai import types
import pandas as pd
from pydantic import BaseModel, Field
from .llm_provider import LLMProvider
from core.config import Settings

logger = logging.getLogger(__name__)

class Gemini(LLMProvider): 
    def __init__(self, settings: Settings, system_prompt = None):
        self.settings = settings
        self.client = genai.Client(api_key=settings.GEMINI_API_KEY)
        self.system_prompt = system_prompt
        self.model = settings.GEMINI_MODEL
        logger.info(f"Gemini provider initialized with model: {self.model}")
    
    async def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1
    ):
        """
        Get response from Gemini API.
        
        Args:
            prompt: The prompt to send
            expecting_longer_output: If True, increases max_output_tokens
            need_json_output: If True, requests JSON output
            schema: Pydantic model for schema validation
            temperature: Temperature for response generation
            
        Returns:
            Parsed response or raw text, or None if error
        """
        try:
            logger.debug(f"Calling Gemini API with prompt length: {len(prompt)}")
            
            generation_config = types.GenerateContentConfig(
                temperature=temperature,
                max_output_tokens=4000 if expecting_longer_output else 2000,
                response_mime_type="application/json" if need_json_output else "text/plain",
                response_schema=schema.model_json_schema() if schema else None,
                system_instruction=self.system_prompt
            )

            # Call Gemini API
            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=self.model,
                contents=prompt,
                config=generation_config
            )

            # Check if response is None
            if response is None:
                logger.error("Gemini API returned None response")
                return None
            
            # Extract text from response
            if not hasattr(response, 'text'):
                logger.error(f"Response has no 'text' attribute. Response type: {type(response)}, content: {response}")
                return None
            
            response_text = response.text
            if not response_text or response_text.strip() == "":
                logger.warning("Gemini returned empty text response")
                return None
            
            logger.debug(f"Gemini response received: {len(response_text)} chars")
            
            # If schema provided, validate JSON
            if schema:
                try:
                    result = schema.model_validate_json(response_text)
                    logger.debug(f"Successfully validated response with schema: {schema.__name__}")
                    return result
                except Exception as schema_error:
                    logger.error(f"Schema validation failed: {schema_error}, response text: {response_text[:200]}")
                    # Return raw text if schema validation fails
                    return response_text
            
            # Return raw text if no schema
            return response_text

        except Exception as e:
            logger.error(f"Gemini API error {type(e).__name__}: {str(e)}", exc_info=True)
            return None

    async def get_embedding(self, content, model=None, task_type=None):
        """
        Get embeddings from Gemini API.
        
        Args:
            content: Content to embed
            model: Embedding model to use
            task_type: Task type for embeddings
            
        Returns:
            Embedding vector or None if error
        """
        if model is None:
            model = self.settings.GEMINI_EMBEDDING_MODEL
        
        try:
            logger.debug(f"Getting embeddings for content length: {len(str(content))}")
            
            response = await asyncio.to_thread(
                self.client.models.embed_content,
                model=model,
                content=content,
                config=types.EmbedContentConfig(
                    task_type=task_type
                )
            )
            
            if response is None or not hasattr(response, 'data'):
                logger.error(f"Embedding response invalid: {type(response)}")
                return None
            
            embedding = response.data[0].embedding
            logger.debug(f"Embedding retrieved, dimensions: {len(embedding)}")
            return embedding
        
        except Exception as e:
            logger.error(f"Embedding error {type(e).__name__}: {str(e)}", exc_info=True)
            return None