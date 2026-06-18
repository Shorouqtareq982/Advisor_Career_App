from typing import List, Dict, Any
from .cv_keywords_extractor import get_cv_all_terms
from .job_keywords_extractor import extract_matched_keywords_from_job


def build_cv_summary(cv_data: Dict) -> str:
    """Build summary from CV skills and tools only"""
    all_terms = get_cv_all_terms(cv_data)
    if all_terms:
        return "skills: " + " ".join(all_terms)
    return ""


def build_job_summary(job_text: str) -> str:
    """Build summary from job description skills/tools only"""
    matched_keywords = extract_matched_keywords_from_job(job_text)
    if matched_keywords:
        return "skills: " + " ".join(matched_keywords)
    return ""