# ==================== EDUCATION EXTRACTOR ====================

import re

EDUCATION_KEYWORDS = {
    "bachelor": [
        "bachelor", "bachelor's", "bachelors", "bsc", "ba",
        "bs", "b.a", "b.s", "undergraduate", "bachelor degree"
    ],
    "master": [
        "master", "master's", "masters", "msc", "ma", "ms",
        "m.a", "m.s", "graduate degree", "master degree"
    ],
    "phd": [
        "phd", "ph.d", "doctorate", "doctoral", "doctor of",
        "dphil", "dr."
    ]
}

def extract_education(job_text: str) -> str:

    job_lower = job_text.lower()
    
    for keyword in EDUCATION_KEYWORDS["phd"]:
        if re.search(rf'\b{re.escape(keyword)}\b', job_lower):
            return "phd"
    
    for keyword in EDUCATION_KEYWORDS["master"]:
        if re.search(rf'\b{re.escape(keyword)}\b', job_lower):
            return "master"
    
    for keyword in EDUCATION_KEYWORDS["bachelor"]:
        if re.search(rf'\b{re.escape(keyword)}\b', job_lower):
            return "bachelor"
    
    return "bachelor"
