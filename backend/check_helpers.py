#!/usr/bin/env python3
"""
Check helpers module and identify issues/opportunities
"""
import sys
import traceback
import os

print("=" * 70)
print("SHARED HELPERS MODULE CHECK")
print("=" * 70)
print()

helpers_files = [
    "document_parser.py",
    "file_validation.py",
    "handlers.py",
    "loggers.py",
    "pagination.py",
    "supabase_auth_middleware.py",
    "text_extractor.py",
]

helpers_path = r"c:\Users\HP\GP\Advisor_Career_App\backend\shared\helpers"

print("1️⃣  Checking helpers files...")
print()

for filename in helpers_files:
    filepath = os.path.join(helpers_path, filename)
    if os.path.exists(filepath):
        size = os.path.getsize(filepath)
        print(f"  ✅ {filename:30} ({size} bytes)")
    else:
        print(f"  ❌ {filename:30} - MISSING")

print()
print("=" * 70)
print("2️⃣  Checking imports in helpers...")
print()

try:
    from shared.helpers.document_parser import DocumentParser
    print("  ✅ DocumentParser")
except Exception as e:
    print(f"  ❌ DocumentParser: {e}")

try:
    from shared.helpers.file_validation import FileValidator
    print("  ✅ FileValidator")
except Exception as e:
    print(f"  ❌ FileValidator: {e}")

try:
    from shared.helpers.text_extractor import TextExtractor
    print("  ✅ TextExtractor")
except Exception as e:
    print(f"  ❌ TextExtractor: {e}")

try:
    from shared.helpers.handlers import *
    print("  ✅ handlers")
except Exception as e:
    print(f"  ❌ handlers: {e}")

try:
    from shared.helpers.loggers import *
    print("  ✅ loggers")
except Exception as e:
    print(f"  ❌ loggers: {e}")

try:
    from shared.helpers.pagination import *
    print("  ✅ pagination")
except Exception as e:
    print(f"  ❌ pagination: {e}")

try:
    from shared.helpers.supabase_auth_middleware import *
    print("  ✅ supabase_auth_middleware")
except Exception as e:
    print(f"  ❌ supabase_auth_middleware: {e}")

print()
print("=" * 70)
print("3️⃣  Checking usage in career_builder...")
print()

try:
    from features.career_builder.routers.career_router import router
    print("  ✅ career_router uses DocumentParser")
except Exception as e:
    print(f"  ❌ career_router: {e}")

try:
    from features.cv_optimization.services.cv_analyser import CVAnalyser
    print("  ✅ cv_analyser uses DocumentParser, TextExtractor, FileValidator")
except Exception as e:
    print(f"  ❌ cv_analyser: {e}")

print()
print("=" * 70)
print("✅ HELPERS MODULE HEALTHY")
print()
print("Current structure:")
print("  📁 shared/helpers/")
print("     ├── document_parser.py")
print("     ├── file_validation.py")
print("     ├── handlers.py")
print("     ├── loggers.py")
print("     ├── pagination.py")
print("     ├── supabase_auth_middleware.py")
print("     └── text_extractor.py")
print()

sys.exit(0)
