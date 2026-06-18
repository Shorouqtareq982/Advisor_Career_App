from .cv_keywords_extractor import get_cv_all_terms
from .job_keywords_extractor import extract_matched_keywords_from_job
from .job_matcher_skills_tools import calculate_skills_tools_match
from .experience_extractor import extract_experience_years
from .seniority_extractor import extract_seniority
from .education_extractor import extract_education
from .languages_extractor import extract_languages
from .summary_builder import build_cv_summary, build_job_summary
from .hybrid_matcher import calculate_hybrid_similarity


def normalize_education(edu_text: str) -> str:
    """Normalize education text to standard level: bachelor, master, phd"""
    edu_lower = edu_text.lower()
    if "phd" in edu_lower or "doctorate" in edu_lower:
        return "phd"
    elif "master" in edu_lower or "msc" in edu_lower or "mba" in edu_lower:
        return "master"
    elif "bachelor" in edu_lower or "bsc" in edu_lower or "ba" in edu_lower:
        return "bachelor"
    return "bachelor"


def calculate_total_match_score(
    cv_data: dict,
    job_text: str,
    matches_preferences: bool = False,
    is_fallback: bool = False
) -> float:
    """
    Calculate final match score (0-100) between CV and job.
    - matches_preferences: +10% bonus
    - is_fallback: -5% penalty
    """
    # 1. Skills & Tools (Rules) - 35%
    cv_all_terms = get_cv_all_terms(cv_data)
    matched_keywords = extract_matched_keywords_from_job(job_text)
    skills_tools_score = calculate_skills_tools_match(cv_all_terms, matched_keywords)
    
    # 2. Hybrid (Transformer on skills) - 35%
    cv_summary = build_cv_summary(cv_data)
    job_summary = build_job_summary(job_text)
    hybrid_score = calculate_hybrid_similarity(cv_summary, job_summary)
    
    # 3. Experience - 10%
    cv_exp = cv_data.get("experience_years", 0)
    job_exp = extract_experience_years(job_text)
    if job_exp == 0:
        exp_score = 100.0
    else:
        exp_score = min(100.0, (cv_exp / job_exp) * 100)
    
    # 4. Seniority - 8%
    cv_sen = cv_data.get("seniority", "mid")
    job_sen = extract_seniority(job_text)
    sen_score = 100.0 if cv_sen == job_sen else 50.0
    
    # 5. Education - 6% (with normalization)
    cv_edu_raw = cv_data.get("education", "bachelor")
    cv_edu_norm = normalize_education(cv_edu_raw)
    job_edu = extract_education(job_text)
    edu_score = 100.0 if cv_edu_norm == job_edu else 50.0
    
    # 6. Languages - 6%
    cv_langs = set(cv_data.get("languages", []))
    job_langs = set(extract_languages(job_text))
    if cv_langs:
        lang_score = (len(cv_langs.intersection(job_langs)) / len(cv_langs)) * 100
    else:
        lang_score = 100.0
    
    # 7. Bonus / Penalty
    bonus = 0.0
    if matches_preferences:
        bonus = 10.0
    elif is_fallback:
        bonus = -5.0
    
    # Final weighted sum
    final_score = (
        (skills_tools_score * 0.35) +
        (hybrid_score * 0.35) +
        (exp_score * 0.10) +
        (sen_score * 0.08) +
        (edu_score * 0.06) +
        (lang_score * 0.06)
    ) + bonus
    
    return min(max(final_score, 0.0), 100.0)