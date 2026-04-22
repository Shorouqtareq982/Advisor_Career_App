#!/usr/bin/env python
"""Test the progression validation logic"""
import sys
sys.path.insert(0, "backend")

# Mock data from the user's response
plan_data = {
    "weekly_breakdown": [
        {
            "week_number": 1,
            "focus_skills": ["Responsive Design & UI/UX"],
            "topic": "Foundations: Build Responsive Design & UI/UX from scratch",
            "description": "This week focuses on learning Responsive Design & UI/UX from scratch...",
            "learning_outcomes": ["Improve Responsive Design & UI/UX from none toward advanced"],
            "expected_level_after_week": "advanced",  # PROBLEM: Should be "beginner" for week 1!
            "resource_queries": []
        }
    ]
}

used_learning_targets = [
    {
        "skill_id": 10,
        "skill_name": "Responsive Design & UI/UX",
        "target_level": "advanced",
        "current_level": "none",  # Starting from NONE
        "learning_mode": "learn_from_scratch",
        "required_level": "beginner",
        "required_weeks": 4,
        "importance_weight": 4
    }
]

# Simulate the validation logic
LEVEL_VALUES = {
    "none": 0,
    "beginner": 1,
    "intermediate": 2,
    "advanced": 3,
}

def normalize_level(level):
    value = (level or "none").strip().lower()
    return value if value in LEVEL_VALUES else "none"

def test_week(week, used_learning_targets):
    i = week["week_number"]
    focus_skills = week.get("focus_skills", [])
    expected_level = normalize_level(week.get("expected_level_after_week"))
    
    print(f"\n🔍 Testing Week {i}:")
    print(f"  Focus skills: {focus_skills}")
    print(f"  Expected level after week: {expected_level}")
    
    for skill_name in focus_skills:
        print(f"    Checking skill: '{skill_name}'")
        
        # Find matching target
        matching_target = None
        for target in used_learning_targets:
            if (target.get("skill_name") or "").strip().lower() == skill_name.strip().lower():
                matching_target = target
                break
        
        if not matching_target:
            print(f"      ❌ No matching target found!")
            continue
        
        current = normalize_level(matching_target.get("current_level"))
        target_level = normalize_level(matching_target.get("target_level"))
        
        current_val = LEVEL_VALUES.get(current, 0)
        expected_val = LEVEL_VALUES.get(expected_level, 0)
        target_val = LEVEL_VALUES.get(target_level, 0)
        
        print(f"      current={current}({current_val}), target={target_level}({target_val}), expected={expected_level}({expected_val})")
        
        # Week 1 check
        if i == 1:
            max_reachable = min(current_val + 1, target_val)
            print(f"      Week 1 max_reachable={max_reachable}, expected_val={expected_val}")
            
            if expected_val > max_reachable:
                print(f"      ❌ VALIDATION FAILED! Week 1 can only reach {max_reachable}, but expected {expected_val}")
                print(f"      ERROR: '{expected_level}' is unrealistic for Week 1 (current={current})")
                return False
        
        # General check
        if expected_val > current_val + 1:
            print(f"      ❌ VALIDATION FAILED! Jump too fast: {expected_level}")
            return False
    
    return True

# Run test
print("=" * 60)
print("TESTING WEEK 1: Responsive Design & UI/UX")
print("Expected: Week 1 should FAIL validation")
print("=" * 60)

for week in plan_data["weekly_breakdown"]:
    result = test_week(week, used_learning_targets)
    if result:
        print("\n✅ VALIDATION PASSED (This is WRONG - should have failed!)")
    else:
        print("\n✅ VALIDATION FAILED AS EXPECTED")

print("\n" + "=" * 60)
