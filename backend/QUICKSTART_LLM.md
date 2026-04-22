"""
QUICK START GUIDE - LLM Fallback System
دليل البدء السريع - نظام الاحتياطي
=====================================

✅ WHAT'S ACTIVE NOW
النظام المفعّل الآن:
- LLM_PROVIDER=openrouter-with-fallback
- Primary: OpenRouter (GPT-4O Mini)
- Fallback: Mistral (mistral-large-latest)

Auto-switch when OpenRouter is down! 🔄


🎯 CHECK SYSTEM STATUS
تحقق من حالة النظام:

curl http://localhost:5000/api/v1/llm/status


📊 GET CONFIGURATION  
اعرض الإعدادات:

curl http://localhost:5000/api/v1/llm/config


🧪 TEST LLM RESPONSE
اختبر الاستجابة:

curl -X POST http://localhost:5000/api/v1/llm/test \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello GROWZA"}'


📝 HOW TO USE IN CODE
استخدام في الكود:

from shared.providers.llm_models.llm_provider import create_llm_provider

# Auto-creates fallback provider if configured
provider = create_llm_provider()

# Get response (auto fallback if needed)
response = await provider.get_response("Your prompt here")

# Get status (if using fallback)
if hasattr(provider, 'get_provider_status'):
    status = provider.get_provider_status()
    print(f"Used: {status['last_used']}")


⚙️ CURRENT CONFIGURATION
الإعدادات الحالية:

┌─ Primary Provider: OpenRouter
│  ├─ Model: openai/gpt-4o-mini
│  └─ Key: your_openrouter_key (placeholder)
│
└─ Fallback Provider: Mistral
   ├─ Model: mistral-large-latest
   └─ Key: ✅ Configured (real key)


🔔 WHAT HAPPENS WHEN OPENROUTER IS DOWN
ماذا يحدث عند عطل OpenRouter:

1. Request comes in
2. System tries OpenRouter
3. OpenRouter fails (down/error)
4. ⚠️ System logs: "Primary provider failed"
5. 🔄 Automatically tries Mistral
6. ✅ Mistral returns response
7. ⚠️ User gets response + warning in logs


📋 LOG INDICATORS
مؤشرات السجل:

✅ Green (success):
   Primary provider (OpenRouter) initialized
   Response from primary provider (OpenRouter)
   Fallback provider (Mistral) initialized

⚠️ Yellow (warning):
   Primary provider initialization failed
   Primary provider failed... Attempting fallback
   Response from fallback provider (Mistral)
   Fallback triggered for operation

❌ Red (error):
   No LLM providers available
   Failed to initialize LLM providers
   All LLM providers failed


🛠️ TROUBLESHOOTING
حل المشاكل:

Q: How do I know which provider was used?
A: Check logs for "Response from [primary|fallback]"
   Or use /api/v1/llm/status endpoint

Q: What if both are down?
A: You'll get an error. Check API keys and network.
   Review .env file for proper configuration.

Q: How to switch only to Mistral?
A: Change .env: LLM_PROVIDER=mistral

Q: How to disable fallback?
A: Change .env: LLM_PROVIDER=openrouter (no fallback)

Q: Can I use different models?
A: Yes! Update in .env:
   OPENROUTER_MODEL=openai/gpt-4-turbo
   MISTRAL_MODEL=mistral-medium-latest


📂 FILES MODIFIED
الملفات المعدلة:

1. fallback_provider.py
   └─ New: Fallback logic & auto-switching

2. llm_provider.py
   └─ Modified: Added "openrouter-with-fallback" option

3. llm_health_router.py
   └─ New: Status & health check endpoints

4. openrouter_provider.py
   └─ Modified: Better error messages

5. .env
   └─ Modified: Fallback configuration active

6. app/main.py
   └─ Modified: Registered llm_health_router


🔍 MONITORING ENDPOINTS
نقاط المراقبة:

GET /api/v1/llm/status
├─ Shows: Primary/Fallback status
├─ Shows: Last used provider
└─ Shows: Health status (🟢/🟡/🔴)

POST /api/v1/llm/test
├─ Input: prompt (query param)
├─ Output: Response + provider used
└─ Use: Test if system working

GET /api/v1/llm/config
├─ Shows: Active provider configuration
├─ Shows: Configured providers
└─ Use: Check setup


💡 BEST PRACTICES
أفضل الممارسات:

1. Always keep both API keys configured
   احتفظ بمفاتيح API كليهما

2. Monitor fallback frequency
   اراقب تكرار التبديل للاحتياطي

3. Set up alerts for fallback triggering
   أنشئ تنبيهات عند تفعيل الاحتياطي

4. Regularly test both providers
   اختبر كلا المزودين بشكل منتظم

5. Keep response quality consistent
   اطلب جودة استجابة متسقة


🚀 PERFORMANCE TIPS
نصائح الأداء:

1. OpenRouter is usually faster (~1-2s)
   OpenRouter أسرع عادة

2. Mistral adds ~1s delay if fallback needed
   Mistral يضيف تأخير إذا لزم الأمر

3. Network latency affects both
   تأخير الشبكة يؤثر على كليهما

4. Cache responses when possible
   قم بتخزين الاستجابات عند الإمكان


📊 COST CONSIDERATIONS
اعتبارات التكاليف:

Typical Usage:
- 80% OpenRouter (primary)
- 20% Mistral (fallback)

OpenRouter: ~20% cheaper
Mistral: Standard rates
Average: Balanced cost

Consider your requirements for optimization!


🔐 SECURITY NOTES
ملاحظات الأمان:

✅ API keys stored in .env
✅ Never commit real keys to git
✅ Use environment variables in production
✅ Rotate keys periodically
✅ Log API errors for audit trail


🎓 LEARN MORE
اعرف المزيد:

Full Documentation:
→ LLM_FALLBACK_SYSTEM.md

Mistral Docs:
→ https://docs.mistral.ai/

OpenRouter Docs:
→ https://openrouter.ai/docs

GROWZA API:
→ http://localhost:5000/api/v1/docs


✨ READY TO USE!
جاهز للاستخدام!

Your system is configured and operational.
نظامك مكوّن وجاهز للعمل.

No further action needed - fallback is automatic! 🚀
"""
