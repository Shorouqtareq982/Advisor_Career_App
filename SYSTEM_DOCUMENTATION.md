# 📚 Career Time Guidance System - Complete Documentation

## 🎯 Overview

نظام شامل لحساب الوقت المطلوب للدراسة بناءً على:
- **المهارات المختارة** (selected skills)
- **المهارات الحالية** (owned skills)
- **ساعات الدراسة المتاحة** (available hours per week)
- **أهمية المهارة** (importance_weight)
- **مرحلة التعلم** (learning progression)

---

## 🔄 API Flow

```
1. /analyze              → Analyze CV
   └─ Output: CV skills, gaps, fit analysis

2. /confirm-skills       → Select which skills to learn
   └─ Output: Updated analysis with selected skills

3. /confirm-time-preview → Get guidance (min/suitable/max weeks)
   └─ Input: cv_id, track_id
   └─ Output: Time guidance (NO user hours/weeks input yet)

4. /confirm-time         → Validate user's time commitment
   └─ Input: requested_weeks, available_hours_per_week
   └─ Output: Realism check + warnings/suggestions

5. /generate-plan        → Create learning plan
   └─ Automatically determines planning mode (min/suitable/max)
   └─ Output: Weekly breakdown

6. /save-plan            → Save to database
   └─ Saves plan + metadata
```

---

## 📊 Planning Modes

يتم تحديد mode تلقائياً بناءً على requested_weeks vs realism calculations:

### MINIMUM Mode
**Condition:** `requested_weeks <= calculated_minimum_weeks`

**Scope:**
- ✅ Selected skills ONLY
- ✅ none → beginner
- ❌ NO owned skills

**Example:**
```
Skills: Python (none), React (none)
Requested: 4 weeks
Mode: MINIMUM
Result: Python + React → beginner only
```

---

### SUITABLE Mode (Most common)
**Condition:** `calculated_minimum_weeks < requested_weeks <= calculated_suitable_weeks`

**Scope:**
- ✅ Selected skills: none → intermediate (core) OR beginner (non-core)
- ✅ Owned core skills: level-up to intermediate
- ❌ Owned non-core skills: skip

**Example:**
```
Selected: Python (core, none), Testing (non-core, none)
Owned: AWS (core, beginner)
Requested: 8 weeks
Mode: SUITABLE
Result:
  - Python: none → intermediate
  - Testing: none → beginner
  - AWS: beginner → intermediate
```

---

### MAXIMUM Mode
**Condition:** `requested_weeks >= calculated_suitable_weeks`

**Scope:**
- ✅ Selected skills: none → advanced
- ✅ ALL owned skills: ✅ level-up to advanced

**Example:**
```
Selected: Python (none), React (none)
Owned: AWS (beginner), Docker (intermediate)
Requested: 20 weeks
Mode: MAXIMUM
Result:
  - Python: none → advanced
  - React: none → advanced
  - AWS: beginner → advanced
  - Docker: intermediate → advanced
```

---

## 🧮 Calculation Formula

**Base Formula:**
```
weeks = required_weeks × progression_multiplier × importance_adjustment × hours_adjustment
```

### 1. Progression Multiplier (based on level transition)
```
("none", "beginner"): 0.4         # Fastest
("none", "intermediate"): 1.0
("none", "advanced"): 1.6         # Slowest

("beginner", "intermediate"): 0.6
("beginner", "advanced"): 1.2

("intermediate", "advanced"): 0.7
```

### 2. Importance Adjustment (importance_weight: 1-5)
```
Weight 5: 1.15×  (takes 15% more time)
Weight 4: 1.05×
Weight 3: 1.0×   (neutral)
Weight 2: 0.9×   (takes 10% less time)
Weight 1: 0.9×
```

### 3. Hours Adjustment (inversely proportional)
```
≤ 3 hours/week: 2.0×   (takes twice as long)
≤ 5 hours/week: 1.5×
≤10 hours/week: 1.0×   (neutral)
≤15 hours/week: 0.85×
> 15 hours/week: 0.7×  (takes 30% less time)
```

---

## 📈 Realistic Checking

```python
# AdvancedRealismChecker
is_realistic = (
    calculated_minimum_weeks <= requested_weeks <= calculated_maximum_weeks
)
```

**Adjustment Statuses:**
- `ok`: Within suitable range
- `tight`: Below suitable but above minimum
- `very_tight`: Below minimum by <50%
- `unrealistic_too_short`: Below minimum by >50% ❌
- `excessive`: Above maximum but achievable

**Fit Percentage:**
```
fit_percentage = (requested_weeks / calculated_suitable_weeks) × 100

- 100%+: تام الكفاية
- 80-100%: مناسب
- 50-80%: ضيق لكن ممكن
- <50%: غير واقعي
```

---

## 🔍 Example Walkthrough

### Scenario:
```
Track: Full Stack Development
CV Skills: Python (beginner), HTML (beginner)
Selected: Python (core), React (core, new), TypeScript (non-core, new)
Owned Core (can level-up): JavaScript (beginner)
Available: 8 hours/week
Requested: 12 weeks
```

### Step 1: Calculate Minimum
```
Selected only, none→beginner:
- Python: 4 (base) × 0.4 × 1.0 × 1.0 = 1.6 ≈ 2 weeks
- React: 4 × 0.4 × 1.0 × 1.0 = 2 weeks
- TypeScript: 3 × 0.4 × 0.9 × 1.0 = 1.08 ≈ 1 week
Total minimum = 5 weeks
```

### Step 2: Calculate Suitable
```
Selected + Owned core level-up:
- Python (learn, core, none→intermediate): 4 × 1.0 × 1.0 × 1.0 = 4 weeks
- React (learn, core, none→intermediate): 4 × 1.0 × 1.0 × 1.0 = 4 weeks
- TypeScript (learn, non-core, none→beginner): 3 × 0.4 × 0.9 × 1.0 = 1 week
- JavaScript (level-up, core, beginner→intermediate): 4 × 0.6 × 1.0 × 1.0 = 2 weeks
Total suitable = 11 weeks
```

### Step 3: Determine Mode & Check Realism
```
requested_weeks: 12 weeks
min: 5, suitable: 11, max: ~15

12 > 11? YES → mode = "maximum_plan"
is_realistic: true ✅
adjustment: "ok"
fit_percentage: (12 / 11) × 100 = 109%
```

### Step 4: Generate Plan with MAXIMUM Mode
```
Targets for plan generation:
1. Python: none → advanced
2. React: none → advanced
3. TypeScript: none → beginner (non-core)
4. JavaScript: beginner → advanced

Plan structure: 12 weeks with all 4 skills progressed appropriately
```

---

## 🛠️ Database Tables Involved

### `track_skills`
```
track_id: 2
skill_id: 100
importance_weight: 4      (1-5)
required_weeks: 4         (base)
is_core: true
```

### `career_skills`
```
skill_id: 100
skill_name: "Python"
category: "Language"
aliases: ["Python 3", "Py"]
```

### `analysis_cache`
```
cv_id: uuid
track_id: 2
analysis_data:
  - selected_skill_ids: [100, 101]
  - detected_skill_levels: {"python": "beginner"}
  - realism: {
      calculated_minimum_weeks: 5,
      calculated_suitable_weeks: 11,
      calculated_maximum_weeks: 15,
      ...
    }
```

---

## ⚠️ Validation Rules

1. **required_weeks**: 1-104 (max 2 years)
2. **importance_weight**: 1-5
3. **available_hours_per_week**: 1-80
4. **requested_weeks**: 1-104

---

## 🐛 Debugging

### Check Logs For:
```
"Skill 'Python' has invalid required_weeks: -1"
"Out-of-range importance_weight: 10, clamping to 3"
"Error getting skills by track: ..."
```

### Common Issues:
1. **Empty time guidance** → Check if selected_skill_ids is empty
2. **Unrealistic warning** → requested_weeks < calculated_minimum_weeks
3. **Wrong planning mode** → Check realism_info in cache

---

## 📞 Support

- Check `FEATURE_REVIEW.md` for known issues
- Check `FIXES_APPLIED.md` for recent fixes
- All files compiled and tested ✅

---
