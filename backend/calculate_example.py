#!/usr/bin/env python3
"""
حساب مثال عملي: weeks=50, hours=3
المقارنة مع المثال السابق: min/suit/max
"""

import sys
sys.path.insert(0, '/Users/HP/GP/Advisor_Career_App/backend')

from features.career_builder.services.unified_time_calculator import UnifiedTimeCalculator
from features.career_builder.ml_models.advanced_realism_checker import AdvancedRealismChecker

# Data from previous example
selected_skills = [
    {
        "skill_id": 30,
        "skill_name": "Advanced Machine Learning",
        "required_weeks": 5,
        "importance_weight": 5,
    },
    {
        "skill_id": 34,
        "skill_name": "Big Data Tools (Hadoop/Spark)",
        "required_weeks": 5,
        "importance_weight": 3,
    },
]

owned_skills = [
    {
        "skill_id": 1,
        "skill_name": "Python",
        "required_weeks": 4,
        "importance_weight": 5,
        "detected_level": "beginner",
    },
]

print("=" * 70)
print("المثال السابق: hours=6")
print("=" * 70)

calculator = UnifiedTimeCalculator()
time_ranges_6h = calculator.calculate_all_ranges(
    selected_skills=selected_skills,
    owned_skills=owned_skills,
    available_hours_per_week=6,
)

print(f"Minimum:  {time_ranges_6h['minimum'].total_weeks} weeks")
print(f"Suitable: {time_ranges_6h['suitable'].total_weeks} weeks")
print(f"Maximum:  {time_ranges_6h['maximum'].total_weeks} weeks")

print("\n" + "=" * 70)
print("المثال الجديد: hours=3")
print("=" * 70)

time_ranges_3h = calculator.calculate_all_ranges(
    selected_skills=selected_skills,
    owned_skills=owned_skills,
    available_hours_per_week=3,
)

print(f"Minimum:  {time_ranges_3h['minimum'].total_weeks} weeks")
print(f"Suitable: {time_ranges_3h['suitable'].total_weeks} weeks")
print(f"Maximum:  {time_ranges_3h['maximum'].total_weeks} weeks")

print("\n" + "=" * 70)
print("الآن: check_realism مع weeks=50 و hours=3")
print("=" * 70)

checker = AdvancedRealismChecker()
result = checker.check_realism(
    requested_weeks=50,
    available_hours_per_week=3,
    learning_targets=selected_skills,
    current_owned_skills=owned_skills,
)

print(f"\n📊 الناتج:")
print(f"  Is Realistic: {result.is_realistic}")
print(f"  Adjustment: {result.adjustment}")
print(f"  Study Intensity: {result.study_intensity}")
print(f"  Fit Percentage: {result.fit_percentage}%")

print(f"\n🎯 الحسابات المقارنة:")
print(f"  Requested weeks: {result.requested_weeks}")
print(f"  Available hours/week: {result.available_hours_per_week}")
print(f"  Calculated minimum: {result.calculated_minimum_weeks} weeks")
print(f"  Calculated suitable: {result.calculated_suitable_weeks} weeks")
print(f"  Calculated maximum: {result.calculated_maximum_weeks} weeks")

print(f"\n⚠️ التحذيرات:")
for warning in result.warnings:
    print(f"  {warning}")

print(f"\n💡 الاقتراحات:")
for suggestion in result.suggestions:
    print(f"  {suggestion}")

print(f"\n📋 تفاصيل المهارات:")
for skill_key, skill_info in result.per_skill_analysis.items():
    print(f"\n  {skill_info['skill_name']}:")
    print(f"    - Current Level: {skill_info['current_level']}")
    print(f"    - Target Level: {skill_info['target_level']}")
    print(f"    - Base Required: {skill_info['base_required_weeks']} weeks")
    print(f"    - Calculated: {skill_info['calculated_weeks_for_this_skill']} weeks")
    print(f"    - Hours Adjustment: {skill_info['hours_adjustment']}x")
