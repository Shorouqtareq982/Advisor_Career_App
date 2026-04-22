# 🔄 Career Builder - Updated to Use Shared Components

## ✅ التحديثات

### ملفات تم حذفها من career_builder/services/:
```
❌ metrics_collector.py      → تم نقله إلى shared/providers/monitoring/
❌ edge_case_handler.py      → تم نقله (refactored) إلى shared/providers/validation/
```

### ملفات بقيت في career_builder/services/:
```
✅ career_analysis_service.py
✅ cv_quality_analyzer.py        (career-specific)
✅ fit_evaluator.py
✅ plan_generation_service.py    (career-specific)
✅ plan_persistence_service.py
✅ plan_regeneration_service.py
✅ resource_search_service.py
✅ time_guidance_service.py      (career-specific)
```

---

## 🚀 كيفية الاستخدام في career_builder

### لـ Metrics Collection:

**Before:**
```python
from features.career_builder.services.metrics_collector import MetricsCollector

collector = MetricsCollector()
```

**After:**
```python
from shared.providers.monitoring import SharedMetricsCollector, FeatureType

collector = SharedMetricsCollector(FeatureType.CAREER_BUILDER)
```

---

### لـ Edge Case Validation:

**Before:**
```python
from features.career_builder.services.edge_case_handler import EdgeCaseHandler

handler = EdgeCaseHandler()
is_valid, warnings = await handler.validate_time_guidance_request(...)
```

**After:**
```python
from shared.providers.validation import GenericValidator, CAREER_BUILDER_CONSTRAINTS

validator = GenericValidator(CAREER_BUILDER_CONSTRAINTS)
is_valid, warnings, corrected = validator.validate_dict({
    "selected_skills": selected_skills,
    "available_hours": available_hours,
    "requested_duration": requested_weeks
})
```

---

## 📋 Shared Components Available

### 1. Monitoring (`shared/providers/monitoring/`)

```python
from shared.providers.monitoring import (
    SharedMetricsCollector,
    FeatureType,
    QualityMetric,
    PerformanceMetric,
    AccuracyMetric,
    ErrorMetric,
)

# Usage in career_builder
metrics = SharedMetricsCollector(FeatureType.CAREER_BUILDER)

# Record CV quality
metrics.record_quality_metric(QualityMetric(
    timestamp=datetime.now(),
    feature=FeatureType.CAREER_BUILDER,
    entity_id=cv_id,
    quality_score=82.5,
    quality_level="good",
    issues_count=1,
    issue_types={}
))

# Record performance
metrics.record_performance_metric(PerformanceMetric(
    timestamp=datetime.now(),
    feature=FeatureType.CAREER_BUILDER,
    operation="analyze",
    duration_ms=234.5,
    success=True
))

# Get stats
health = metrics.get_platform_health()
```

---

### 2. Validation (`shared/providers/validation/`)

```python
from shared.providers.validation import (
    GenericValidator,
    CAREER_BUILDER_CONSTRAINTS,
    ValidationCaseType,
    ValidationWarning,
)

# Usage in career_builder
validator = GenericValidator(CAREER_BUILDER_CONSTRAINTS)

# Validate single field
result = validator.validate_field("selected_skills", 15)
if not result.is_valid:
    print(result.error_message)

# Validate entire dictionary
is_valid, warnings, corrected_data = validator.validate_dict({
    "selected_skills": request.skill_ids,
    "available_hours": request.hours,
    "requested_duration": request.weeks
})

# Detect edge cases
edge_cases = validator.detect_edge_cases(data)
for edge_case in edge_cases:
    print(f"{edge_case.case_type}: {edge_case.message}")
```

---

## 📝 Integration Points

### في career_router.py:

إذا كنت تستخدم metrics_collector أو edge_case_handler، استبدلهم بـ:

```python
# Add to imports
from shared.providers.monitoring import (
    SharedMetricsCollector, 
    FeatureType, 
    PerformanceMetric
)
from shared.providers.validation import GenericValidator, CAREER_BUILDER_CONSTRAINTS

# In your endpoints
@app.post("/career/confirm-time")
async def confirm_time(request: ConfirmTimeRequest):
    # Validate
    validator = GenericValidator(CAREER_BUILDER_CONSTRAINTS)
    is_valid, warnings, data = validator.validate_dict({
        "selected_skills": request.selected_skill_ids,
        "available_hours": request.available_hours_per_week,
        "requested_duration": request.requested_weeks,
    })
    
    if not is_valid:
        critical = [w for w in warnings if w.severity == "error"]
        if critical:
            return {"status": "invalid", "errors": critical}
    
    # Track metrics
    metrics = SharedMetricsCollector(FeatureType.CAREER_BUILDER)
    
    start = time.time()
    try:
        # ... your logic ...
        duration = (time.time() - start) * 1000
        metrics.record_performance_metric(PerformanceMetric(
            timestamp=datetime.now(),
            feature=FeatureType.CAREER_BUILDER,
            operation="confirm_time",
            duration_ms=duration,
            success=True
        ))
    except Exception as e:
        metrics.record_error(ErrorMetric(...))
        raise
```

---

## ✅ Quality Measures

✅ Old files deleted from career_builder
✅ Shared components ready to use
✅ All new files compile without errors
✅ Backward compatible (legacy wrappers provided)
✅ Ready for integration

---

## 📊 Next Steps

1. **Optional:** Update career_router.py to use shared components
2. **Optional:** Update time_guidance_service.py to use shared validator
3. **Ready:** Use for all new features (job_matching, market_insights, etc.)

---

## 🎁 الفائدة الفورية

```
✨ Unified monitoring across platform
✨ Consistent validation rules
✨ Real-time health dashboard
✨ Reusable for all features
✨ Better maintenance
✨ Easier debugging & monitoring
```

---

**Status:** ✅ Career Builder cleaned & ready to use shared components
