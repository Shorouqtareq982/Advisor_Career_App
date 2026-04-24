"""
Fallback LLM Provider
Provides automatic failover from primary provider (OpenRouter) to backup (Mistral)
when the primary provider is unavailable or experiencing issues.
"""

import logging
import asyncio
from typing import Optional, Type, Any
from pydantic import BaseModel

from .llm_provider import LLMProvider
from core.config import Settings

logger = logging.getLogger(__name__)


class FallbackLLMProvider(LLMProvider):
    """
    LLM Provider with fallback support.
    
    Attempts to use primary provider (OpenRouter), and automatically
    falls back to backup provider (Mistral) if primary fails.
    
    Usage:
    - Set LLM_PROVIDER=openrouter-with-fallback
    - Will try OpenRouter first, fallback to Mistral on error
    """

    def __init__(self, settings: Settings, system_prompt: Optional[str] = None):
        self.settings = settings
        self.system_prompt = system_prompt
        self.primary_provider = None
        self.fallback_provider = None
        self.last_used_provider = None
        
        self._initialize_providers()

    def _initialize_providers(self):
        """Initialize primary and fallback providers"""
        try:
            from .openrouter_provider import OpenRouterProvider
            from .mistral_provider import MistralProvider
            
            # Primary: OpenRouter
            try:
                self.primary_provider = OpenRouterProvider(
                    self.settings, 
                    system_prompt=self.system_prompt
                )
                logger.info("✅ Primary provider (OpenRouter) initialized")
            except Exception as e:
                logger.warning(f"⚠️ Primary provider (OpenRouter) initialization failed: {str(e)}")
                self.primary_provider = None
            
            # Fallback: Mistral
            try:
                self.fallback_provider = MistralProvider(
                    self.settings,
                    system_prompt=self.system_prompt
                )
                logger.info("✅ Fallback provider (Mistral) initialized")
            except Exception as e:
                logger.warning(f"⚠️ Fallback provider (Mistral) initialization failed: {str(e)}")
                self.fallback_provider = None
            
            # Verify at least one provider is available
            if not self.primary_provider and not self.fallback_provider:
                raise ValueError("No LLM providers available (OpenRouter and Mistral both failed)")

        except Exception as e:
            logger.error(f"❌ Failed to initialize LLM providers: {str(e)}")
            raise

    async def get_response(
        self,
        prompt: str,
        expecting_longer_output: bool = False,
        need_json_output: bool = False,
        schema: Optional[Type[BaseModel]] = None,
        temperature: float = 0.1,
    ) -> Any:
        """
        Get response with fallback support.
        
        Tries primary provider (OpenRouter) first.
        If it fails, automatically uses fallback (Mistral).
        """
        
        # Try primary provider first
        if self.primary_provider:
            try:
                logger.debug("🔄 Trying primary provider (OpenRouter)...")
                response = await self.primary_provider.get_response(
                    prompt=prompt,
                    expecting_longer_output=expecting_longer_output,
                    need_json_output=need_json_output,
                    schema=schema,
                    temperature=temperature,
                )
                self.last_used_provider = "openrouter"
                logger.info("✅ Response from primary provider (OpenRouter)")
                return response
                
            except Exception as e:
                logger.warning(
                    f"⚠️ Primary provider (OpenRouter) failed: {str(e)}. "
                    f"Attempting fallback (Mistral)..."
                )

        # Fallback to backup provider
        if self.fallback_provider:
            try:
                logger.debug("🔄 Trying fallback provider (Mistral)...")
                response = await self.fallback_provider.get_response(
                    prompt=prompt,
                    expecting_longer_output=expecting_longer_output,
                    need_json_output=need_json_output,
                    schema=schema,
                    temperature=temperature,
                )
                self.last_used_provider = "mistral"
                logger.warning("⚠️ Response from fallback provider (Mistral) - OpenRouter unavailable")
                return response
                
            except Exception as e:
                logger.error(f"❌ Fallback provider (Mistral) also failed: {str(e)}")
                raise Exception(
                    f"All LLM providers failed. Primary: OpenRouter, Fallback: Mistral. "
                    f"Last error: {str(e)}"
                )

        # No providers available
        raise Exception("No LLM providers available")

    async def get_embedding(
        self,
        content: str,
        model: Optional[str] = None,
        task_type: Optional[str] = None,
    ) -> Any:
        """
        Get embedding with fallback support.
        
        Tries primary provider (OpenRouter) first.
        If it fails, uses fallback (Mistral).
        """
        
        # Try primary provider first
        if self.primary_provider:
            try:
                logger.debug("🔄 Trying embedding from primary provider (OpenRouter)...")
                embedding = await self.primary_provider.get_embedding(
                    content=content,
                    model=model,
                    task_type=task_type,
                )
                self.last_used_provider = "openrouter"
                logger.info("✅ Embedding from primary provider (OpenRouter)")
                return embedding
                
            except Exception as e:
                logger.warning(
                    f"⚠️ Primary provider embedding failed: {str(e)}. "
                    f"Attempting fallback..."
                )

        # Fallback to backup provider
        if self.fallback_provider:
            try:
                logger.debug("🔄 Trying embedding from fallback provider (Mistral)...")
                embedding = await self.fallback_provider.get_embedding(
                    content=content,
                    model=model,
                    task_type=task_type,
                )
                self.last_used_provider = "mistral"
                logger.warning("⚠️ Embedding from fallback provider (Mistral)")
                return embedding
                
            except Exception as e:
                logger.error(f"❌ Fallback provider embedding also failed: {str(e)}")
                raise Exception(
                    f"All embedding providers failed. Last error: {str(e)}"
                )

        raise Exception("No embedding providers available")

    def get_provider_status(self) -> dict:
        """Get status of both providers"""
        return {
            "primary_provider": "openrouter",
            "primary_available": self.primary_provider is not None,
            "fallback_provider": "mistral",
            "fallback_available": self.fallback_provider is not None,
            "last_used": self.last_used_provider,
            "mode": "fallback_enabled",
        }

    def get_health_status(self) -> str:
        """Get health status message"""
        status = self.get_provider_status()
        
        if status["primary_available"] and status["fallback_available"]:
            return "🟢 Healthy - Both providers available"
        elif status["fallback_available"]:
            return "🟡 Degraded - Primary down, using fallback (Mistral)"
        else:
            return "🔴 Critical - All providers down"
