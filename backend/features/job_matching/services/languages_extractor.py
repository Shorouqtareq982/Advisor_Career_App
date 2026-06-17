import re

COMMON_LANGUAGES = [
    "english", "arabic", "french", "german", "spanish",
    "mandarin", "chinese", "japanese", "korean", "russian",
    "italian", "portuguese", "dutch", "turkish", "hindi"
]

def extract_languages(job_text: str) -> list:
    job_lower = job_text.lower()
    found_languages = []
    
    for lang in COMMON_LANGUAGES:
        if re.search(rf'\b{re.escape(lang)}\b', job_lower):
            found_languages.append(lang)
    
    if not found_languages:
        return ["english"]
    
    return found_languages