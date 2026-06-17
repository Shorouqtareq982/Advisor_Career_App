from typing import List

def calculate_skills_tools_match(
    cv_all_terms: List[str], 
    matched_keywords: List[str]
) -> float:
    """
    Calculate match score based on matched keywords from job description.
    Score = (Matched CV Terms / Total Job Description Terms) * 100
    """
    if not matched_keywords:
        return 0.0
    
    cv_set = set(cv_all_terms)
    matched_set = set(matched_keywords)
    
    matched_count = len(cv_set.intersection(matched_set))
    
    percentage = (matched_count / len(matched_keywords)) * 100
    
    return min(percentage, 100.0)