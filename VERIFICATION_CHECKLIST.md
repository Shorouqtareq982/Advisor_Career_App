# ✅ Time Calculation Unification - Verification Checklist

## Pre-Deployment Verification

### 1. Code Quality ✅
- [x] All files compile without syntax errors
- [x] No circular imports
- [x] Proper type hints
- [x] Docstrings present
- [x] Comments clear

**Verification:**
```bash
python -m py_compile \
  features/career_builder/services/unified_time_calculator.py \
  features/career_builder/services/time_guidance_service.py \
  features/career_builder/ml_models/advanced_realism_checker.py
# ✅ No output = All OK
```

---

### 2. Consistency Tests

#### Test Case A: Same Input → Same Output

```python
# Test: Preview and Checker endpoints should return same min/suit/max

input_data = {
    "cv_id": "7d0fbb6a-3316-4f5e-8798-2acbc8aedfd6",
    "track_id": 5,
    "selected_skill_ids": [30, 34],
    "detected_skill_levels": {...},
    "available_hours_per_week": 6,  # For preview
    "requested_weeks": 30,  # For confirm-time
}

# BEFORE FIX:
preview_result = await confirm_time_preview(input_data)
assert preview_result.minimum_weeks == 10  # ✅
assert preview_result.suitable_weeks == 23  # ✅
assert preview_result.maximum_weeks == 92  # ✅

checker_result = AdvancedRealismChecker().check_realism(input_data)
assert checker_result.calculated_minimum_weeks == 5   # ❌ WRONG!
assert checker_result.calculated_suitable_weeks == 14 # ❌ WRONG!
assert checker_result.calculated_maximum_weeks == 14  # ❌ WRONG!

# AFTER FIX:
preview_result = await confirm_time_preview(input_data)
assert preview_result.minimum_weeks == 10  # ✅

checker_result = AdvancedRealismChecker().check_realism(input_data)
assert checker_result.calculated_minimum_weeks == 10  # ✅ SAME NOW!
assert checker_result.calculated_suitable_weeks == 23 # ✅ SAME NOW!
assert checker_result.calculated_maximum_weeks == 92  # ✅ SAME NOW!
```

**Status:** [ ] To Verify

---

#### Test Case B: Progressive Time Ranges

```python
# Test: minimum < suitable < maximum

ranges = {
    "minimum_weeks": 10,
    "suitable_weeks": 23,
    "maximum_weeks": 92,
}

assert ranges["minimum_weeks"] <= ranges["suitable_weeks"]
assert ranges["suitable_weeks"] <= ranges["maximum_weeks"]
# Both BEFORE and AFTER should satisfy this
```

**Status:** [ ] To Verify

---

#### Test Case C: Adjustment Status

```python
# Test: Realism checker correctly categorizes time requests

test_cases = [
    {
        "requested": 5,
        "minimum": 10,
        "expected_adjustment": "unrealistic_too_short",  # 5 < 10
        "is_realistic": False,
    },
    {
        "requested": 15,
        "minimum": 10,
        "suitable": 23,
        "expected_adjustment": "very_tight",  # 10 < 15 < 23
        "is_realistic": True,
    },
    {
        "requested": 30,
        "minimum": 10,
        "suitable": 23,
        "maximum": 92,
        "expected_adjustment": "excessive",  # 30 > 92? NO! Should be "tight"
        # Recalculate: 23 < 30 < 92 → "tight"
    },
]

for test in test_cases:
    result = checker.check_realism(test)
    assert result.adjustment == test["expected_adjustment"]
```

**Status:** [ ] To Verify

---

### 3. Edge Cases

#### Case 1: Only Selected Skills (No Owned)
```python
selected_skills = [skill1, skill2]
owned_skills = None  # Empty

time_ranges = calculator.calculate_all_ranges(
    selected_skills=selected_skills,
    owned_skills=None,  # Key test: should handle gracefully
    available_hours_per_week=6
)

# Expected:
# - minimum: selected only, none→beginner
# - suitable: same as minimum (no owned to level up)
# - maximum: selected, none→advanced

assert time_ranges["minimum"].total_weeks > 0
assert time_ranges["suitable"].total_weeks >= time_ranges["minimum"].total_weeks
assert time_ranges["maximum"].total_weeks >= time_ranges["suitable"].total_weeks
```

**Status:** [ ] To Verify

---

#### Case 2: Very High Hours Per Week
```python
# Test: 24 hours/week should dramatically reduce weeks needed

result_3h = calculate_time_for_scope(
    selected_skills, None, scope, available_hours_per_week=3
)

result_24h = calculate_time_for_scope(
    selected_skills, None, scope, available_hours_per_week=24
)

# More hours = fewer weeks needed
assert result_24h.total_weeks < result_3h.total_weeks

# Ratio should be roughly 2-3x different
ratio = result_3h.total_weeks / result_24h.total_weeks
assert 1.5 < ratio < 3.0  # Reasonable adjustment
```

**Status:** [ ] To Verify

---

#### Case 3: High Importance Skills
```python
# Test: High importance skills require more time

low_importance = {
    "skill_id": 1,
    "skill_name": "Basic Skill",
    "required_weeks": 4,
    "importance_weight": 1,  # Low
}

high_importance = {
    "skill_id": 2,
    "skill_name": "Critical Skill",
    "required_weeks": 4,
    "importance_weight": 5,  # High
}

result_low = calculator._estimate_skill_time(low_importance, ...)
result_high = calculator._estimate_skill_time(high_importance, ...)

# High importance should take more time
assert result_high.calculated_weeks > result_low.calculated_weeks
```

**Status:** [ ] To Verify

---

### 4. Integration Tests

#### Endpoint 1: /confirm-time-preview

```bash
POST /confirm-time-preview
Content-Type: form-data

cv_id: 7d0fbb6a-3316-4f5e-8798-2acbc8aedfd6
track_id: 5

Response:
{
  "status": "success",
  "time_guidance": {
    "minimum_weeks": 10,      # ✅ Should be consistent
    "suitable_weeks": 23,     # ✅ Should be consistent
    "maximum_weeks": 92,      # ✅ Should be consistent
    "study_intensity": "moderate",
    "breakdown": {...}
  }
}
```

**Status:** [ ] To Verify

---

#### Endpoint 2: /confirm-time

```bash
POST /confirm-time
Content-Type: application/json

{
  "cv_id": "7d0fbb6a-3316-4f5e-8798-2acbc8aedfd6",
  "track_id": 5,
  "available_hours_per_week": 10,
  "requested_weeks": 30
}

Response:
{
  "status": "success",
  "realism": {
    "is_realistic": true,
    "adjustment": "tight",  # 23 < 30 < 92
    "calculated_minimum_weeks": 10,      # ✅ Should match preview!
    "calculated_suitable_weeks": 23,     # ✅ Should match preview!
    "calculated_maximum_weeks": 92,      # ✅ Should match preview!
    "fit_percentage": 130.4,  # (23 / 30) * 100
    "warnings": [...],
    "suggestions": [...]
  }
}
```

**Status:** [ ] To Verify

---

### 5. Data Integrity

- [ ] No data lost during migration
- [ ] Existing cache entries still work
- [ ] Database consistency maintained
- [ ] No stale references

---

### 6. Performance

```python
# Time calculation should be fast
import time

start = time.time()
for _ in range(100):
    time_ranges = calculator.calculate_all_ranges(...)
elapsed = time.time() - start

# Expected: < 1 second for 100 calculations
assert elapsed < 1.0, f"Too slow: {elapsed}s"
print(f"✅ Average: {elapsed/100*1000:.2f}ms per calculation")
```

**Baseline:** < 50ms per call  
**Target:** < 50ms (same as before)  
**Actual:** [ ] To Measure

---

### 7. Documentation

- [x] Docstrings in UnifiedTimeCalculator
- [x] README comments in all services
- [x] Test suite with examples
- [x] Summary documentation created

---

## Post-Deployment Verification

### 1. Monitor Logs

```bash
# Look for any errors or warnings
grep -i "time_calculation\|UnifiedTimeCalculator" /var/log/app.log

# Should see:
# - Services instantiating calculator correctly
# - No calculation errors
# - Consistent results logged
```

**Status:** [ ] To Monitor

---

### 2. User Feedback

- [ ] No complaints about inconsistent guidance
- [ ] Time estimates match expectations
- [ ] Plans generated are reasonable
- [ ] Fit scores are meaningful

---

### 3. Analytics

```python
# Track:
- Number of time guidances generated
- Distribution of recommended weeks
- Accuracy of fit_percentage
- Correlation with actual learning time
```

---

## Rollback Plan

If issues found:

```bash
# 1. Identify the problem
# 2. Check if it's in UnifiedTimeCalculator or service integration
# 3. If UnifiedTimeCalculator: create hotfix patch
# 4. If service integration: quick revert to old logic (temporary)
# 5. Notify team
# 6. Provide rollback if needed

git revert <commit_hash>  # If absolute rollback needed
```

---

## Sign-Off Checklist

Before deploying to production:

- [ ] All code compiles without errors
- [ ] Consistency tests pass
- [ ] Edge cases handled correctly
- [ ] Integration tests pass
- [ ] Performance meets baseline
- [ ] Documentation complete
- [ ] Team reviewed and approved
- [ ] Deployment plan confirmed

---

## Current Status

```
Verification Phase: 🔄 IN PROGRESS

Code Quality:     ✅ COMPLETE
Integration:      [ ] PENDING
Testing:          [ ] PENDING  
Sign-off:         [ ] PENDING

Estimated Time:   2-4 hours for full verification
Next Step:        Run integration tests in staging
```

---

## Notes for Test Team

1. **Focus on consistency:** The main goal is ensuring min/suit/max are same across endpoints
2. **Test with varied hours:** 3hr/week vs 24hr/week - should see proportional changes
3. **Check edge cases:** Empty owned_skills, high importance weights, etc.
4. **Verify messages:** User guidance should be clear and correct
5. **Performance:** Should feel instant (< 100ms from user perspective)

---

**Last Updated:** 2026-04-13  
**Prepared By:** System Architect  
**Status:** Ready for Testing
