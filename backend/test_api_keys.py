#!/usr/bin/env python3
"""
Test script to verify API keys are working
"""
import os
import sys
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_youtube_api():
    """Test YouTube API key"""
    print("\n🔍 Testing YouTube API Key...")
    api_key = os.getenv('YOUTUBE_API_KEY')
    if not api_key:
        print("❌ YouTube API Key not found")
        return False
    
    try:
        url = "https://www.googleapis.com/youtube/v3/search"
        params = {
            'q': 'test',
            'part': 'snippet',
            'key': api_key,
            'maxResults': 1
        }
        response = requests.get(url, params=params, timeout=5)
        if response.status_code == 200:
            print("✅ YouTube API Key is VALID")
            return True
        else:
            print(f"❌ YouTube API Key INVALID - Status: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"❌ YouTube API Error: {str(e)}")
        return False

def test_serpapi():
    """Test SerpAPI key"""
    print("\n🔍 Testing SerpAPI Key...")
    api_key = os.getenv('SERPAPI_API_KEY')
    if not api_key:
        print("❌ SerpAPI Key not found")
        return False
    
    try:
        url = "https://serpapi.com/search"
        params = {
            'q': 'test',
            'api_key': api_key
        }
        response = requests.get(url, params=params, timeout=5)
        if response.status_code == 200:
            print("✅ SerpAPI Key is VALID")
            return True
        else:
            print(f"❌ SerpAPI Key INVALID - Status: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"❌ SerpAPI Error: {str(e)}")
        return False

def test_tavily_api():
    """Test Tavily API key"""
    print("\n🔍 Testing Tavily API Key...")
    api_key = os.getenv('TAVILY_API_KEY')
    if not api_key:
        print("❌ Tavily API Key not found")
        return False
    
    try:
        url = "https://api.tavily.com/search"
        payload = {
            'api_key': api_key,
            'query': 'test',
            'max_results': 1
        }
        response = requests.post(url, json=payload, timeout=5)
        if response.status_code == 200:
            print("✅ Tavily API Key is VALID")
            return True
        else:
            print(f"❌ Tavily API Key INVALID - Status: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"❌ Tavily API Error: {str(e)}")
        return False

def test_github_token():
    """Test GitHub token"""
    print("\n🔍 Testing GitHub Token...")
    token = os.getenv('GITHUB_TOKEN')
    if not token:
        print("❌ GitHub Token not found")
        return False
    
    try:
        url = "https://api.github.com/user"
        headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        response = requests.get(url, headers=headers, timeout=5)
        if response.status_code == 200:
            user_data = response.json()
            print(f"✅ GitHub Token is VALID (User: {user_data.get('login', 'Unknown')})")
            return True
        else:
            print(f"❌ GitHub Token INVALID - Status: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"❌ GitHub Token Error: {str(e)}")
        return False

def test_llm_rerank():
    """Test LLM rerank settings"""
    print("\n🔍 Checking LLM Rerank Settings...")
    enable_rerank = os.getenv('ENABLE_LLM_RERANK', 'false').lower() == 'true'
    max_candidates = os.getenv('MAX_RERANK_CANDIDATES', '8')
    
    print(f"   ENABLE_LLM_RERANK: {enable_rerank}")
    print(f"   MAX_RERANK_CANDIDATES: {max_candidates}")
    
    if enable_rerank:
        print("✅ LLM Rerank is ENABLED")
        return True
    else:
        print("⚠️  LLM Rerank is DISABLED")
        return True

def main():
    print("=" * 60)
    print("🧪 API Keys & Settings Validation")
    print("=" * 60)
    
    results = {
        'YouTube API': test_youtube_api(),
        'SerpAPI': test_serpapi(),
        'Tavily API': test_tavily_api(),
        'GitHub Token': test_github_token(),
        'LLM Rerank': test_llm_rerank()
    }
    
    print("\n" + "=" * 60)
    print("📊 SUMMARY")
    print("=" * 60)
    
    for service, status in results.items():
        status_icon = "✅" if status else "❌"
        print(f"{status_icon} {service}: {'WORKING' if status else 'FAILED'}")
    
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    print(f"\n✨ Overall: {passed}/{total} APIs validated")
    
    return all(results.values())

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
