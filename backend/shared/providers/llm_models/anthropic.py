"""
Anthropic Claude Provider
"""
import os
import json
from typing import Optional, Type
from pydantic import BaseModel
import anthropic
import logging

logger = logging.getLogger(__name__)


class AnthropicProvider:
    """Anthropic Claude LLM Provider"""
    
    def __init__(self):
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY not found in environment")
        
        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = os.getenv("ANTHROPIC_MODEL", "claude-3-5-sonnet-20241022")
        logger.info(f"✅ Anthropic provider initialized with model: {self.model}")
    
    def get_response(
        self,
        prompt: str,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        max_tokens: int = 4096,
        temperature: float = 0.3
    ):
        """Get response from Claude"""
        try:
            # Prepare system message for JSON output
            system_message = ""
            if need_json_output:
                system_message = (
                    "You are a helpful assistant that returns responses in valid JSON format. "
                    "Always return valid JSON without any markdown formatting or explanation."
                )
            
            # Call Claude API
            logger.info(f"Calling Claude API (model: {self.model})...")
            response = self.client.messages.create(
                model=self.model,
                max_tokens=max_tokens,
                temperature=temperature,
                system=system_message if system_message else anthropic.NOT_GIVEN,
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            )
            
            # Extract text content
            text_content = ""
            for block in response.content:
                if block.type == "text":
                    text_content += block.text
            
            if not text_content:
                logger.warning("Claude returned empty response")
                return None
            
            # Parse JSON if needed
            if need_json_output:
                try:
                    # Remove markdown code blocks if present
                    cleaned = text_content.strip()
                    if cleaned.startswith("```json"):
                        cleaned = cleaned[7:]
                    if cleaned.startswith("```"):
                        cleaned = cleaned[3:]
                    if cleaned.endswith("```"):
                        cleaned = cleaned[:-3]
                    cleaned = cleaned.strip()
                    
                    # Parse JSON
                    parsed_json = json.loads(cleaned)
                    
                    # Convert to Pydantic if schema provided
                    if schema:
                        try:
                            return schema(**parsed_json)
                        except Exception as e:
                            logger.warning(f"Failed to convert to {schema.__name__}: {e}")
                            return parsed_json
                    
                    return parsed_json
                    
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse JSON from Claude: {e}")
                    logger.error(f"Raw response: {text_content[:500]}")
                    return None
            
            return text_content
            
        except anthropic.APIError as e:
            logger.error(f"Anthropic API error: {type(e).__name__}: {e}")
            logger.error(f"Status code: {getattr(e, 'status_code', 'unknown')}")
            logger.error(f"Response: {getattr(e, 'response', 'unknown')}")
            return None
        except Exception as e:
            logger.error(f"Anthropic provider error: {type(e).__name__}: {e}", exc_info=True)
            return None