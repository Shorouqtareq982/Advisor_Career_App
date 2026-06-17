import re

def extract_experience_years(job_text: str) -> int:
    job_lower = job_text.lower()
    
    patterns = [
        r'(\d+)\s*[–-]\s*(\d+)\+\s*(?:years?|yrs?)',
        r'(\d+)\s*-\s*(\d+)\+\s*(?:years?|yrs?)',
        r'(\d+)\s*[–-]\s*(\d+)\s*(?:years?|yrs?)',
        r'(\d+)\s*-\s*(\d+)\s*(?:years?|yrs?)',
        r'(\d+)\s*to\s*(\d+)\s*(?:years?|yrs?)',
        r'(\d+)\+\s*(?:years?|yrs?)\s*(?:of\s+)?experience',
        r'(\d+)\+\s*(?:years?|yrs?)\b',
        r'minimum\s*(\d+)\s*(?:years?|yrs?)',
        r'at least\s*(\d+)\s*(?:years?|yrs?)',
        r'experience\s*:?\s*(\d+)\+?\s*(?:years?|yrs?)',
        r'(\d+)\s*(?:years?|yrs?)\s+experience\b',
        r'(\d+)\s*(?:years?|yrs?)\s+of\s+experience',
        r'(\d+)\s*(?:years?|yrs?)\s+of\s+[\w\s]+?\s+experience\b',
        r'(\d+)\s*(?:years?|yrs?)\b',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, job_lower)
        if match:
            if len(match.groups()) == 2:
                return int(match.group(1))
            return int(match.group(1))
    
    return 0