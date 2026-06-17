import httpx
import os
import re
from html import unescape
from typing import List, Dict, Any
from dotenv import load_dotenv
import nltk
from nltk.corpus import stopwords
from itertools import cycle

# Download NLTK data (run once)
try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('stopwords')

stop_words = set(stopwords.words('english'))

load_dotenv()

# Load multiple JSearch keys
JSEARCH_API_KEYS = [
    os.getenv("JSEARCH_API_KEY_1"),
    os.getenv("JSEARCH_API_KEY_2"),
    os.getenv("JSEARCH_API_KEY_3"),
    os.getenv("JSEARCH_API_KEY_4"),
]
JSEARCH_API_KEYS = [k for k in JSEARCH_API_KEYS if k]

# Create round-robin cycler
_jsearch_cycler = cycle(JSEARCH_API_KEYS)

def get_next_jsearch_key() -> str:
    """Get next JSearch API key in round-robin fashion."""
    return next(_jsearch_cycler)

JSEARCH_URL = "https://jsearch.p.rapidapi.com/search"

COUNTRY_NAME_TO_CODE = {
    "Egypt": "EG",
    "Saudi Arabia": "SA",
    "United Arab Emirates": "AE",
    "Kuwait": "KW",
    "United States": "US"
}

MAX_JOBS_TO_FETCH = 50


# ==================== Normalization Helpers ====================

def normalize_job_type(job_type: str) -> str:
    """
    Normalize any job_type input to 'full-time' or 'part-time'
    """
    job_lower = job_type.lower().strip()
    
    # Full-time variations
    if job_lower in ["full-time", "fulltime", "full time", "ft", "full"]:
        return "full-time"
    
    # Part-time variations
    if job_lower in ["part-time", "parttime", "part time", "pt", "part"]:
        return "part-time"
    
    # Default to full-time
    return "full-time"


def normalize_work_mode(work_mode: str) -> str:
    """
    Normalize any work_mode input to 'remote' or 'onsite'
    """
    work_lower = work_mode.lower().strip()
    
    # Remote variations
    if work_lower in ["remote", "remotely", "work from home", "wfh", "from home", "fully remote"]:
        return "remote"
    
    # Onsite variations
    if work_lower in ["onsite", "on-site", "on site", "in office", "office", "in person"]:
        return "onsite"
    
    # Default to remote
    return "remote"


# ==================== Helper: Clean for Display ====================
def clean_for_display(raw_description: str, max_length: int = 1000) -> str:
    """Basic cleaning for frontend display (HTML, entities, whitespace)"""
    if not raw_description:
        return ""
    
    # Remove HTML tags
    cleaned = re.sub(r'<[^>]+>', ' ', raw_description)
    # Decode HTML entities
    cleaned = unescape(cleaned)
    # Remove extra whitespace
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    # Truncate
    if len(cleaned) > max_length:
        cleaned = cleaned[:max_length] + "..."
    
    return cleaned


# ==================== Helper: Clean for Matching ====================
def clean_for_matching(text: str, expand_abbr: bool = True) -> str:
    """Heavy cleaning for similarity calculation"""
    if not text:
        return ""
    
    # Lowercase
    text = text.lower()
    
    # Remove punctuation
    text = re.sub(r'[^\w\s]', ' ', text)
    
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    
    # Remove stop words only (without lemmatization)
    words = text.split()
    words = [w for w in words if w not in stop_words]

    return ' '.join(words)


# ==================== Helper: Detect if job is truly remote ====================
def detect_remote_from_text(job: dict) -> bool:
    """Detect if job is remote from title, location, or description"""
    title = job.get("job_title", "").lower()
    if "remote" in title:
        return True
    
    location = job.get("job_location", "").lower()
    if "remote" in location:
        return True
    
    description = job.get("job_description", "")[:1000].lower()
    remote_keywords = ["remote", "work from home", "wfh", "work from anywhere", "home office", "remotely"]
    for keyword in remote_keywords:
        if keyword in description:
            return True
    
    return False


# ==================== Helper: Check if text is English ====================
def is_english_text(text: str, threshold: float = 0.3) -> bool:
    if not text:
        return False
    english_chars = len(re.findall(r'[a-zA-Z]', text))
    spaces = text.count(' ')
    total_chars = len(text) - spaces
    if total_chars == 0:
        return False
    ratio = english_chars / total_chars
    return ratio >= threshold


# ==================== Helper: Fetch jobs by type and mode ====================
async def _fetch_jobs_by_type_and_mode(
    job_title: str,
    country_code: str,
    employment_type: str,
    work_mode: str,
    needed_count: int
) -> List[Dict[str, Any]]:
    fetched_jobs = []
    jobs_per_page = 10
    max_pages = (needed_count // jobs_per_page) + 2
    
    for page in range(1, max_pages + 1):
        if len(fetched_jobs) >= needed_count:
            break
        
        params = {
            "query": job_title,
            "country": country_code,
            "employment_types": employment_type,
            "page": page,
            "num_pages": 1,
        }
        
        headers = {
            "X-RapidAPI-Key": get_next_jsearch_key(),
            "X-RapidAPI-Host": "jsearch.p.rapidapi.com"
        }
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                print(f"🔍 Fetching {employment_type} {work_mode} jobs, page {page}...")
                response = await client.get(JSEARCH_URL, headers=headers, params=params)
                
                if response.status_code != 200:
                    print(f"⚠️ API error (status {response.status_code})")
                    break
                
                data = response.json()
                raw_jobs = data.get("data", [])
                
                if not raw_jobs:
                    break
                
                for job in raw_jobs:
                    if len(fetched_jobs) >= needed_count:
                        break
                    
                    is_remote = detect_remote_from_text(job)
                    
                    if work_mode == "remote" and not is_remote:
                        continue
                    if work_mode == "onsite" and is_remote:
                        continue
                    
                    raw_description = job.get("job_description", "")
                    
                    # For frontend display (cleaned, readable, 1000 chars)
                    display_description = clean_for_display(raw_description, 1000)
                    
                    # Skip non-English jobs
                    if not is_english_text(display_description):
                        continue
                    
                    # For matching (heavily cleaned)
                    matching_description = clean_for_matching(raw_description)
                    
                    standardized = {
                        "title": job.get("job_title", ""),
                        "company": job.get("employer_name", ""),
                        "location": job.get("job_location", ""),
                        "work_mode": work_mode,
                        "job_type": "part-time" if employment_type == "PARTTIME" else "full-time",
                        "link": job.get("job_apply_link", ""),
                        "description_preview": display_description,
                        "description_full": matching_description,
                        "is_remote": is_remote,
                        "matches_preferences": True,
                        "is_fallback": False
                    }
                    fetched_jobs.append(standardized)
                    
        except Exception as e:
            print(f"❌ Error: {str(e)}")
            break
    
    return fetched_jobs


# ==================== Main Function ====================
async def fetch_jobs_from_jsearch(
    job_title: str,
    country_name: str,
    job_type: str,
    work_mode: str
) -> List[Dict[str, Any]]:
    # Normalize inputs
    job_type = normalize_job_type(job_type)
    work_mode = normalize_work_mode(work_mode)
    
    if not JSEARCH_API_KEYS:
        print("❌ No JSearch API keys found")
        return []
    
    country_code = COUNTRY_NAME_TO_CODE.get(country_name)
    if not country_code:
        print(f"❌ Country '{country_name}' not supported")
        return []
    
    employment_type_map = {
        "full-time": "FULLTIME",
        "part-time": "PARTTIME",
    }
    
    primary_employment_type = employment_type_map.get(job_type, "FULLTIME")
    
    all_jobs = []
    
    # Step 1: Preferred (job_type + work_mode)
    print(f"🔍 Fetching {job_type} {work_mode} jobs (preferred)...")
    preferred_jobs = await _fetch_jobs_by_type_and_mode(
        job_title, country_code, primary_employment_type, work_mode, MAX_JOBS_TO_FETCH
    )
    all_jobs.extend(preferred_jobs)
    print(f"✅ Found {len(preferred_jobs)} preferred jobs.")
    
    # Step 2: Same job_type, other work_mode
    if len(all_jobs) < MAX_JOBS_TO_FETCH:
        other_mode = "onsite" if work_mode == "remote" else "remote"
        needed = MAX_JOBS_TO_FETCH - len(all_jobs)
        print(f"⚠️ Need {needed} more. Fetching {job_type} {other_mode} fallback...")
        
        fallback_mode = await _fetch_jobs_by_type_and_mode(
            job_title, country_code, primary_employment_type, other_mode, needed
        )
        for job in fallback_mode:
            job["matches_preferences"] = False
            job["is_fallback"] = True
        all_jobs.extend(fallback_mode)
        print(f"✅ Added {len(fallback_mode)} {other_mode} jobs.")
    
    # Step 3: Part-time only -> full-time fallback
    if job_type == "part-time" and len(all_jobs) < MAX_JOBS_TO_FETCH:
        needed = MAX_JOBS_TO_FETCH - len(all_jobs)
        print(f"⚠️ Need {needed} more. Fetching full-time {work_mode} fallback...")
        
        fallback_ft = await _fetch_jobs_by_type_and_mode(
            job_title, country_code, "FULLTIME", work_mode, needed
        )
        for job in fallback_ft:
            job["matches_preferences"] = False
            job["is_fallback"] = True
        all_jobs.extend(fallback_ft)
        print(f"✅ Added {len(fallback_ft)} full-time jobs.")
    
    print(f"🎯 Total fetched: {len(all_jobs)} jobs")
    return all_jobs[:MAX_JOBS_TO_FETCH]