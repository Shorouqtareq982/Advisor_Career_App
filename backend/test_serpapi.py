#!/usr/bin/env python3
"""
Quick SerpApi test script to verify the API is working correctly
and to identify what types of results it returns.
"""
import asyncio
import logging
import sys
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Add backend to path
BACKEND_DIR = Path(__file__).parent
sys.path.insert(0, str(BACKEND_DIR))

from features.career_builder.services.resource_search_service import ResourceSearchService

async def test_serpapi():
    """Test SerpApi with different resource types."""
    print("\n" + "="*70)
    print("🧪 TESTING SERPAPI RESOURCE SEARCH")
    print("="*70 + "\n")
    
    service = ResourceSearchService()
    
    # Check if API keys are configured
    print(f"✓ YouTube API Key configured: {bool(service.youtube_api_key)}")
    print(f"✓ SerpApi API Key configured: {bool(service.serpapi_api_key)}\n")
    
    if not service.serpapi_api_key:
        print("❌ SerpApi API Key not configured! Check .env file")
        return
    
    # Test queries for different resource types
    test_queries = [
        {
            "title": "Python Pandas",
            "query": "python pandas",
            "type": "docs"
        },
        {
            "title": "React Course",
            "query": "react frontend framework",
            "type": "course"
        },
        {
            "title": "JavaScript Practice",
            "query": "javascript coding exercises",
            "type": "practice"
        },
        {
            "title": "Web Development",
            "query": "web development tutorial",
            "type": "article"
        },
    ]
    
    print("🔍 Testing SerpApi searches...\n")
    
    for test in test_queries:
        print(f"\n📝 Testing: {test['type'].upper()} - {test['title']}")
        print(f"   Query: {test['query']}")
        print("   " + "-"*60)
        
        try:
            results = await service._search_serpapi(
                query=test['query'],
                resource_type=test['type'],
                title=test['title']
            )
            
            print(f"   ✓ Got {len(results)} results")
            
            youtube_count = sum(1 for r in results if r.get('type') == 'youtube')
            non_youtube_count = len(results) - youtube_count
            
            print(f"   YouTube: {youtube_count}, Non-YouTube: {non_youtube_count}")
            
            if results:
                print(f"   Top result: {results[0].get('title')[:60]}")
                print(f"   Domain: {results[0].get('url', 'N/A').split('/')[2] if '/' in results[0].get('url', '') else 'N/A'}")
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    print("\n" + "="*70)
    print("✅ TEST COMPLETE - Check logs above for resource type distribution")
    print("="*70 + "\n")

if __name__ == "__main__":
    asyncio.run(test_serpapi())
