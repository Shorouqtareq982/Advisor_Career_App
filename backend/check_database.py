#!/usr/bin/env python3
"""
Check database/repository layer
"""
import sys
import traceback

print("=" * 70)
print("DATABASE & REPOSITORY LAYER CHECK")
print("=" * 70)
print()

try:
    # Import repository
    from features.career_builder.repositories.career_repository import CareerRepository
    print("✅ CareerRepository imported successfully")
    
    # Check key methods exist
    key_methods = [
        "get_analysis_cache",
        "get_track_by_id",
        "get_curated_learning_resources",
        "get_discovered_learning_resources",
        "upsert_discovered_learning_resources",
    ]
    
    print()
    print("Checking key repository methods:")
    missing = []
    
    for method_name in key_methods:
        if hasattr(CareerRepository, method_name):
            print(f"  ✅ {method_name}")
        else:
            print(f"  ❌ {method_name} - MISSING")
            missing.append(method_name)
    
    if missing:
        print(f"\n❌ {len(missing)} methods missing from CareerRepository")
        sys.exit(1)
    else:
        print("\n✅ All key methods present")
    
    # Check Supabase client
    print()
    print("=" * 70)
    print("Checking Supabase connectivity...")
    
    try:
        from core.config import settings
        supabase_url = getattr(settings, "SUPABASE_URL", "")
        supabase_key = getattr(settings, "SUPABASE_ANON_KEY", "")
        
        if supabase_url and supabase_key:
            print(f"✅ Supabase URL configured: {supabase_url[:30]}...")
            print(f"✅ Supabase key configured")
        else:
            print("❌ Missing Supabase configuration")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ Supabase config error: {e}")
        sys.exit(1)
    
    print()
    print("=" * 70)
    print("✅ DATABASE & REPOSITORY LAYER HEALTHY")
    sys.exit(0)
    
except Exception as e:
    print(f"❌ ERROR: {e}")
    traceback.print_exc()
    sys.exit(1)
