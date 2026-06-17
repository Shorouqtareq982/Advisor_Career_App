import re
from .experience_extractor import extract_experience_years

SENIORITY_KEYWORDS = {
    "junior": [
        "junior", "entry", "entry level", "fresh graduate", 
        "graduate", "intern", "internship", "trainee", "associate",
        "administrative"
    ],
    "mid": [
        "mid", "mid level", "mid-level", "intermediate", 
        "regular", "experienced", "specialist"
    ],
    "senior": [
        "senior", "lead", "principal", "staff", "sr", "sr.", 
        "head of", "director", "chief", "cto", "vp"
    ]
}

def extract_seniority_from_years(experience_years: int) -> str:
    if experience_years == 0:
        return None
    elif experience_years < 2:
        return "junior"
    elif experience_years < 5:
        return "mid"
    else:
        return "senior"

def extract_seniority_from_keywords(job_text: str) -> str:
    job_lower = job_text.lower()
    
    for keyword in SENIORITY_KEYWORDS["junior"]:
        if re.search(rf'\b{re.escape(keyword)}\b', job_lower):
            return "junior"
    
    for keyword in SENIORITY_KEYWORDS["senior"]:
        if re.search(rf'\b{re.escape(keyword)}\b', job_lower):
            return "senior"
    
    for keyword in SENIORITY_KEYWORDS["mid"]:
        if re.search(rf'\b{re.escape(keyword)}\b', job_lower):
            return "mid"
    
    return None

def extract_seniority(job_text: str) -> str:
    experience_years = extract_experience_years(job_text)
    
    if experience_years > 0:
        from_years = extract_seniority_from_years(experience_years)
        if from_years is not None:
            return from_years
    
    from_keywords = extract_seniority_from_keywords(job_text)
    if from_keywords is not None:
        return from_keywords
    
    return "junior"