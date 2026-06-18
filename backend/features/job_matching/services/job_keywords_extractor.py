import re
from ..data.job_profiles import get_all_skills_from_all_jobs, get_all_tools_from_all_jobs
from typing import List

def get_all_job_keywords_combined() -> List[str]:
    """Get ALL skills + tools from ALL job profiles"""
    all_skills = get_all_skills_from_all_jobs()
    all_tools = get_all_tools_from_all_jobs()
    
    combined = list(set(all_skills + all_tools))
    return combined

def extract_matched_keywords_from_job(job_text: str) -> List[str]:
    """Search for ALL keywords (from all jobs) inside job description"""
    all_keywords = get_all_job_keywords_combined()
    
    if not all_keywords:
        return []
    
    job_lower = job_text.lower()
    found = []
    
    for keyword in all_keywords:
        if re.search(rf'\b{re.escape(keyword)}\b', job_lower):
            found.append(keyword)
    
    return list(set(found))