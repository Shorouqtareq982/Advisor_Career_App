"""
LLM Provider Health Check Router
Provides endpoints to monitor LLM provider status and fallback behavior.
"""

import logging
from fastapi import APIRouter

from shared.providers.llm_models.llm_provider import create_llm_provider
from shared.providers.llm_models.fallback_provider import FallbackLLMProvider

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/llm", tags=["LLM Provider"])


@router.get("/status")
async def get_llm_provider_status():
    """
    Get current LLM provider status and health.
    
    Returns:
    - Current provider configuration
    - Primary/Fallback provider status
    - Last used provider
    - Health status
    """
    try:
        provider = create_llm_provider()
        
        # If using fallback provider, get detailed status
        if isinstance(provider, FallbackLLMProvider):
            status = provider.get_provider_status()
            health = provider.get_health_status()
            
            return {
                "status": "success",
                "mode": "fallback_enabled",
                "primary": status["primary_provider"],
                "primary_available": status["primary_available"],
                "fallback": status["fallback_provider"],
                "fallback_available": status["fallback_available"],
                "last_used": status["last_used"],
                "health_status": health,
                "message": "System is configured to automatically fallback to Mistral if OpenRouter is down"
            }
        
        # Single provider mode
        return {
            "status": "success",
            "mode": "single_provider",
            "provider": provider.__class__.__name__,
            "fallback_available": False,
            "health_status": "🟢 Using single provider (no fallback)",
        }
        
    except Exception as e:
        logger.error(f"Error getting LLM provider status: {str(e)}")
        return {
            "status": "error",
            "error": str(e),
            "health_status": "🔴 Critical - Provider initialization failed"
        }


@router.post("/test")
async def test_llm_provider(
    prompt: str = "Say hello to GROWZA Career Advisor",
):
    """
    Test LLM provider with a simple prompt.
    
    Useful for testing if the provider is working correctly.
    If using fallback mode, shows which provider was used.
    """
    try:
        provider = create_llm_provider()
        
        # Get initial status
        initial_provider = None
        if isinstance(provider, FallbackLLMProvider):
            status_before = provider.get_provider_status()
            initial_provider = status_before["last_used"]
        
        # Get response
        response = await provider.get_response(
            prompt=prompt,
            temperature=0.7,
        )
        
        # Get final status
        final_provider = None
        if isinstance(provider, FallbackLLMProvider):
            status_after = provider.get_provider_status()
            final_provider = status_after["last_used"]
        
        return {
            "status": "success",
            "prompt": prompt,
            "response": response[:200] + "..." if len(response) > 200 else response,
            "provider_used": final_provider or provider.__class__.__name__,
            "fallback_triggered": isinstance(provider, FallbackLLMProvider) and final_provider == "mistral",
        }
        
    except Exception as e:
        logger.error(f"Error testing LLM provider: {str(e)}")
        return {
            "status": "error",
            "error": str(e),
            "message": "Failed to get response from LLM provider. Check if all API keys are configured correctly."
        }


@router.get("/config")
async def get_llm_config():
    """
    Get current LLM provider configuration.
    
    Returns configured settings (without exposing API keys).
    """
    from core.config import get_settings
    
    settings = get_settings()
    
    config = {
        "primary_provider": settings.LLM_PROVIDER,
        "providers_configured": {
            "gemini": bool(settings.GEMINI_API_KEY),
            "openrouter": bool(settings.OPENROUTER_API_KEY),
            "mistral": bool(settings.MISTRAL_API_KEY),
        },
        "primary_model": None,
        "fallback_model": None,
    }
    
    # Add model info based on provider
    if settings.LLM_PROVIDER == "gemini":
        config["primary_model"] = settings.GEMINI_MODEL or "gemini-pro"
    elif settings.LLM_PROVIDER == "openrouter":
        config["primary_model"] = settings.OPENROUTER_MODEL or "openai/gpt-4o-mini"
    elif settings.LLM_PROVIDER == "mistral":
        config["primary_model"] = settings.MISTRAL_MODEL or "mistral-large-latest"
    elif settings.LLM_PROVIDER == "openrouter-with-fallback":
        config["primary_model"] = settings.OPENROUTER_MODEL or "openai/gpt-4o-mini"
        config["fallback_model"] = settings.MISTRAL_MODEL or "mistral-large-latest"
    
    return {
        "status": "success",
        "config": config,
    }
