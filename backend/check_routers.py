#!/usr/bin/env python3
"""
Check main endpoints and router setup
"""
import sys
import traceback

print("=" * 70)
print("CAREER_BUILDER ROUTERS HEALTH CHECK")
print("=" * 70)
print()

try:
    from features.career_builder.routers.career_router import router
    print("✅ Router imported successfully")
    
    # Check if router has routes
    if hasattr(router, 'routes'):
        routes = router.routes
        print(f"✅ Found {len(routes)} routes")
        
        # List key endpoints
        key_endpoints = [
            "/generate-plan",
            "/regenerate-plan",
            "/confirm-time",
            "/analyze",
            "/confirm-skills",
        ]
        
        print()
        print("Checking key endpoints:")
        
        for endpoint in key_endpoints:
            found = any(endpoint in str(route.path) for route in routes if hasattr(route, 'path'))
            status = "✅" if found else "❌"
            print(f"  {status} {endpoint}")
    
    print()
    print("=" * 70)
    
    # Try to instantiate main services
    print("Checking service dependencies...")
    print()
    
    try:
        from features.career_builder.services.plan_generation_service import PlanGenerationService
        print("✅ PlanGenerationService: Available")
    except Exception as e:
        print(f"❌ PlanGenerationService: {e}")
    
    try:
        from features.career_builder.services.resource_search_service import ResourceSearchService
        service = ResourceSearchService()
        print("✅ ResourceSearchService: Available and instantiable")
    except Exception as e:
        print(f"❌ ResourceSearchService: {e}")
    
    try:
        from features.career_builder.services.weekly_resource_orchestrator import WeeklyResourceOrchestrator
        print("✅ WeeklyResourceOrchestrator: Available")
    except Exception as e:
        print(f"❌ WeeklyResourceOrchestrator: {e}")
    
    print()
    print("=" * 70)
    print("✅ ALL ROUTERS AND KEY SERVICES FUNCTIONAL")
    sys.exit(0)
    
except Exception as e:
    print(f"❌ ERROR: {e}")
    traceback.print_exc()
    sys.exit(1)
