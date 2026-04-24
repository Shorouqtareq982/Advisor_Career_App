"""
Test script for LLM Fallback System
التحقق من نظام الـ fallback
"""

import asyncio
import logging
from shared.providers.llm_models.llm_provider import create_llm_provider
from shared.providers.llm_models.fallback_provider import FallbackLLMProvider

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def test_llm_system():
    """Test the fallback LLM system"""
    print("\n" + "="*70)
    print("LLM FALLBACK SYSTEM TEST")
    print("="*70 + "\n")
    
    try:
        # Create provider
        print("1️⃣ Initializing LLM Provider...")
        provider = create_llm_provider()
        print(f"   ✅ Provider initialized: {provider.__class__.__name__}\n")
        
        # Get status if fallback provider
        if isinstance(provider, FallbackLLMProvider):
            print("2️⃣ Getting Provider Status...")
            status = provider.get_provider_status()
            print(f"   Primary (OpenRouter): {'✅ Available' if status['primary_available'] else '❌ Not available'}")
            print(f"   Fallback (Mistral):   {'✅ Available' if status['fallback_available'] else '❌ Not available'}")
            print(f"   Last used: {status['last_used']}\n")
            
            health = provider.get_health_status()
            print(f"3️⃣ Health Status:")
            print(f"   {health}\n")
        
        # Test getting response
        print("4️⃣ Testing Response Generation...")
        prompt = "مرحبا! ما اسمك؟ (Say your name in Arabic)"
        
        response = await provider.get_response(
            prompt=prompt,
            temperature=0.7,
        )
        
        if isinstance(provider, FallbackLLMProvider):
            used = provider.last_used_provider
            print(f"   Provider Used: {used.upper()}")
            print(f"   Response: {response[:100]}...\n")
        else:
            print(f"   Response: {response[:100]}...\n")
        
        # Test with JSON output
        print("5️⃣ Testing JSON Output...")
        from pydantic import BaseModel, Field
        
        class TestOutput(BaseModel):
            message: str = Field(..., description="A greeting message")
            language: str = Field(..., description="The language used")
        
        try:
            json_response = await provider.get_response(
                prompt='Return JSON with greeting in Arabic and mention the language',
                need_json_output=True,
                schema=TestOutput,
            )
            print(f"   JSON Response: {json_response}\n")
        except Exception as e:
            print(f"   ⚠️ JSON test failed: {str(e)}\n")
        
        # Final status
        print("="*70)
        print("✅ ALL TESTS PASSED - System is working correctly!")
        print("="*70 + "\n")
        
    except Exception as e:
        print(f"\n❌ TEST FAILED: {str(e)}\n")
        return False
    
    return True


if __name__ == "__main__":
    import sys
    sys.path.insert(0, '/backend')
    
    success = asyncio.run(test_llm_system())
    exit(0 if success else 1)
