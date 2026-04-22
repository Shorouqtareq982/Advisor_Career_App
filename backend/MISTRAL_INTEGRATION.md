"""
MISTRAL AI INTEGRATION COMPLETE
================================

Mistral AI has been successfully integrated as the LLM provider for the GROWZA Career Advisor platform.

CONFIGURATION SUMMARY
====================

1. ✅ Mistral Provider Created
   File: backend/shared/providers/llm_models/mistral_provider.py
   - Implements MistralProvider class extending LLMProvider
   - Supports chat completions via Mistral API
   - Supports embeddings generation
   - JSON output parsing with Pydantic schema support

2. ✅ Config Updated
   File: backend/core/config.py
   - Added MISTRAL_API_KEY setting
   - Added MISTRAL_MODEL setting
   - Both optional, loaded from environment variables

3. ✅ LLM Factory Updated
   File: backend/shared/providers/llm_models/llm_provider.py
   - Added "mistral" provider option in create_llm_provider()
   - Factory now supports: gemini, openrouter, mistral

4. ✅ Environment Configured
   File: backend/.env
   - LLM_PROVIDER=mistral
   - MISTRAL_API_KEY=Xh06hudn2AvgySCJpi23LJnLgibGDsJP
   - MISTRAL_MODEL=mistral-large-latest

MISTRAL MODELS AVAILABLE
========================

Primary Model (Set):
- mistral-large-latest: Large-scale model for complex tasks
  Best for: Plan generation, detailed analysis, JSON output
  Max tokens: 8000
  
Alternative Models:
- mistral-medium-latest: Medium model for standard tasks
- mistral-small-latest: Lightweight model for quick responses
- mistral-embed: Embeddings model for semantic search

TO USE DIFFERENT MODEL
======================

Update .env:
MISTRAL_MODEL=mistral-medium-latest

Or update code:
from core.config import get_settings
settings = get_settings()
settings.MISTRAL_MODEL = "mistral-small-latest"

FEATURES AVAILABLE
===================

1. Chat Completions
   - System prompts support
   - Custom temperature control (0-1)
   - Adaptive token allocation based on output needs
   - JSON output with schema validation

2. Embeddings
   - Semantic text embeddings
   - Compatible with similarity search
   - Uses mistral-embed model

3. Response Handling
   - Automatic JSON extraction from text responses
   - Pydantic schema validation
   - Error handling with logging
   - Timeout protection (60s for chat, 30s for embeddings)

USAGE IN CODE
=============

Basic Usage:
```python
from shared.providers.llm_models.llm_provider import create_llm_provider

provider = create_llm_provider()  # Auto-uses Mistral from config
response = await provider.get_response("Analyze this data...")
```

With System Prompt:
```python
system_prompt = "You are a career advisor. Provide structured career guidance."
provider = create_llm_provider(system_prompt=system_prompt)
response = await provider.get_response("I want to become a data scientist")
```

JSON Output:
```python
from pydantic import BaseModel

class CareerPlan(BaseModel):
    skills: List[str]
    duration_weeks: int
    milestones: List[str]

provider = create_llm_provider()
plan = await provider.get_response(
    prompt="Generate career plan",
    need_json_output=True,
    schema=CareerPlan
)
```

Embeddings:
```python
embedding = await provider.get_embedding("text to embed")
# Returns: List[float] - 1024-dimensional embedding vector
```

API ENDPOINTS NOW USING MISTRAL
================================

These endpoints will now use Mistral AI for their LLM operations:

1. Career Analysis
   POST /api/v1/career/analyze
   - Uses Mistral for CV analysis
   - Skill extraction
   - Level detection

2. Plan Generation
   POST /api/v1/career/generate-plan
   - Uses Mistral to generate optimized 32-week plans
   - Includes checkpoint scheduling
   - Capstone project recommendations

3. Plan Feedback & Regeneration
   POST /api/v1/career/regenerate-plan
   - Uses Mistral to refine plans based on feedback
   - Adapts to user preferences

4. Career Insights
   All endpoints generating insights will use Mistral

MONITORING & LOGGING
====================

Mistral initialization is logged at INFO level:
✅ Mistral provider initialized with model: mistral-large-latest

Check logs for:
- Provider initialization status
- API response times
- Error handling
- Embedding generation status

COST CONSIDERATIONS
===================

Mistral Pricing (as of 2024):
- Input tokens: Lower than OpenAI/Anthropic
- Output tokens: Competitive rates
- Embeddings: Cost-effective for semantic search

Optimization:
- Token limits adjusted based on output needs
- Short outputs: max 2000 tokens
- Long outputs: max 8000 tokens
- Reduces unnecessary token usage

ERROR HANDLING
==============

Common Issues & Solutions:

1. Missing API Key
   Error: "MISTRAL_API_KEY is missing"
   Solution: Add MISTRAL_API_KEY to .env

2. Invalid API Key
   Error: 401 Unauthorized
   Solution: Verify API key is correct in .env

3. Model Not Found
   Error: 404 Model not found
   Solution: Check MISTRAL_MODEL setting, use valid model name

4. Rate Limiting
   Error: 429 Too Many Requests
   Solution: Implement backoff strategy, check rate limits

5. Timeout
   Error: Timeout after 60 seconds
   Solution: Check network connection, reduce expected output size

TESTING
=======

To verify Mistral integration:

1. Check Provider Creation
```python
from shared.providers.llm_models.llm_provider import create_llm_provider
from core.config import get_settings

settings = get_settings()
print(f"LLM Provider: {settings.LLM_PROVIDER}")  # Should be "mistral"
print(f"Model: {settings.MISTRAL_MODEL}")  # Should be "mistral-large-latest"

provider = create_llm_provider()
print(f"Provider type: {type(provider).__name__}")  # Should be "MistralProvider"
```

2. Test Simple Completion
```python
import asyncio
from shared.providers.llm_models.llm_provider import create_llm_provider

async def test():
    provider = create_llm_provider()
    response = await provider.get_response("Say hello to the GROWZA team")
    print(response)

asyncio.run(test())
```

3. Test with JSON Output
```python
from pydantic import BaseModel
from typing import List

class TestOutput(BaseModel):
    greeting: str
    team: List[str]

async def test_json():
    provider = create_llm_provider()
    result = await provider.get_response(
        prompt='Return JSON with greeting and list ["dev", "qa", "support"]',
        need_json_output=True,
        schema=TestOutput
    )
    print(result)

asyncio.run(test_json())
```

SECURITY
========

API Key Protection:
- Never commit .env file with real keys
- Use environment variables in production
- Rotate keys periodically
- Monitor API usage for anomalies

Best Practices:
- Use separate API keys for dev/staging/production
- Implement rate limiting on endpoints
- Log API calls for audit purposes
- Validate all API responses

NEXT STEPS
==========

1. ✅ Integration Complete
   - Mistral is now the active LLM provider
   - All endpoints will use Mistral for LLM operations
   - System will use mistral-large-latest by default

2. 🔄 Monitor Logs
   - Watch for any Mistral API errors
   - Check response quality and latency
   - Monitor token usage and costs

3. ⚙️ Fine-tune if Needed
   - Adjust temperature for different use cases
   - Switch models if needed (medium, small)
   - Implement custom prompts for better results

4. 📊 Measure Impact
   - Compare output quality with previous provider
   - Check latency improvements
   - Monitor cost efficiency

SUPPORT & DOCUMENTATION
========================

Mistral AI Documentation: https://docs.mistral.ai/
- API Reference
- Model Documentation
- Best Practices
- Rate Limits

GROWZA Career Advisor:
- Backend API docs: /api/v1/docs
- Backend RedDoc: /api/v1/redoc
- This integration file: MISTRAL_INTEGRATION.md

QUICK REFERENCE
===============

Current Configuration:
- Provider: mistral
- Model: mistral-large-latest
- API Key: ✅ Configured
- Status: ✅ Ready to use

To Restart with Mistral:
1. Backend already running with uvicorn
2. Server automatically uses Mistral provider
3. No restart needed (hot reload enabled)

To Test Mistral:
- Run: curl http://localhost:5000/health
- Check for any errors in backend logs
- Try /api/v1/docs to test endpoints

=======================
Integration Date: 2026-04-16
Status: ✅ COMPLETE & ACTIVE
=======================
"""
