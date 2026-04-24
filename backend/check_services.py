#!/usr/bin/env python3
"""
Comprehensive health check for all career_builder services
"""
import sys
import traceback

services_to_check = [
    ("PlanGenerationService", "features.career_builder.services.plan_generation_service"),
    ("ResourceSearchService", "features.career_builder.services.resource_search_service"),
    ("WeeklyResourceOrchestrator", "features.career_builder.services.weekly_resource_orchestrator"),
    ("CareerAnalysisService", "features.career_builder.services.career_analysis_service"),
    ("UnifiedTimeCalculator", "features.career_builder.services.unified_time_calculator"),
    ("PlanRegenerationService", "features.career_builder.services.plan_regeneration_service"),
    ("PlanPersistenceService", "features.career_builder.services.plan_persistence_service"),
    ("TimeGuidanceService", "features.career_builder.services.time_guidance_service"),
    ("FitEvaluator", "features.career_builder.services.fit_evaluator"),
    ("CvQualityAnalyzer", "features.career_builder.services.cv_quality_analyzer"),
    ("CapstoneProjectManager", "features.career_builder.services.capstone_project_manager"),
    ("PlanFeedbackMapper", "features.career_builder.services.plan_feedback_mapper"),
]

print("=" * 70)
print("CAREER_BUILDER SERVICES HEALTH CHECK")
print("=" * 70)
print()

results = {}

for class_name, module_path in services_to_check:
    try:
        module = __import__(module_path, fromlist=[class_name])
        cls = getattr(module, class_name, None)
        
        if cls is None:
            results[class_name] = ("❌ NOT FOUND", f"Class not exported from {module_path}")
            print(f"❌ {class_name:30} - NOT FOUND in module")
        else:
            results[class_name] = ("✅ OK", f"Imported successfully")
            print(f"✅ {class_name:30} - OK")
            
    except ImportError as e:
        results[class_name] = ("❌ IMPORT ERROR", str(e))
        print(f"❌ {class_name:30} - IMPORT ERROR: {str(e)[:40]}...")
        
    except Exception as e:
        results[class_name] = ("❌ ERROR", str(e))
        print(f"❌ {class_name:30} - ERROR: {str(e)[:40]}...")

print()
print("=" * 70)
print("SUMMARY")
print("=" * 70)

ok_count = sum(1 for status, _ in results.values() if status == "✅ OK")
error_count = len(results) - ok_count

print(f"✅ Working: {ok_count}/{len(results)}")
print(f"❌ Failed:  {error_count}/{len(results)}")
print()

if error_count > 0:
    print("FAILED SERVICES:")
    for service, (status, msg) in results.items():
        if "❌" in status:
            print(f"  • {service}: {msg[:60]}")
    print()
    sys.exit(1)
else:
    print("✅ ALL SERVICES HEALTHY")
    sys.exit(0)
