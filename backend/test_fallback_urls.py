#!/usr/bin/env python3
"""
Quick test to validate fallback URLs are safe and not root/generic
"""
import sys
from features.career_builder.services.plan_generation_service import PlanGenerationService

GENERIC_ROOT_URLS = {
    "https://github.com",
    "https://github.com/",
    "https://www.github.com",
    "https://www.github.com/",
    "https://kaggle.com",
    "https://kaggle.com/",
    "https://www.kaggle.com",
    "https://www.kaggle.com/",
}

def test_fallback_resources():
    """Test that fallback resources don't have generic root URLs"""
    
    service = PlanGenerationService(repository=None, analysis_service=None)
    
    week = {
        "topic": "Python Fundamentals",
        "focus_skills": ["Python"],
    }
    
    fallback = service._build_fallback_resources_for_week(
        week=week,
        track_name="backend",
        current_level="beginner",
        target_level="intermediate",
        available_hours_per_week=6,
    )
    
    print("✓ Generated fallback resources:")
    print(f"  Count: {len(fallback)}")
    print()
    
    has_generic = False
    for idx, resource in enumerate(fallback, 1):
        url = resource.get("url", "").strip()
        r_type = resource.get("type", "unknown")
        title = resource.get("title", "Unknown")
        
        if url in GENERIC_ROOT_URLS:
            print(f"  ✗ [{idx}] {r_type.upper()}: GENERIC ROOT URL DETECTED!")
            print(f"      URL: {url}")
            has_generic = True
        else:
            print(f"  ✓ [{idx}] {r_type.upper()}: {title}")
            print(f"      URL: {url}")
    
    print()
    
    if has_generic:
        print("❌ FAILED: Generic root URLs found in fallback resources")
        return False
    else:
        print("✅ PASSED: All fallback URLs are specific and valid")
        return True

if __name__ == "__main__":
    try:
        success = test_fallback_resources()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
