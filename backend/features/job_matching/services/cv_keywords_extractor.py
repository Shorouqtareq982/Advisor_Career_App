from typing import List, Dict, Any

def normalize_text(text: str) -> str:
    return text.lower().strip()

def get_cv_skills_pairs(cv_data: Dict) -> List:
    pairs = []
    
    for skill in cv_data.get("skills", []):
        name = normalize_text(skill.get("name", ""))
        synonym = normalize_text(skill.get("synonym", ""))
        
        if name:
            pairs.append((name, synonym))
    
    return pairs

def get_cv_tools_set(cv_data: Dict) -> List[str]:
    tools_set = set()
    
    for tool in cv_data.get("tools", []):
        if tool:
            tools_set.add(normalize_text(tool))
    
    return list(tools_set)

def get_cv_all_terms(cv_data: Dict) -> List[str]:
    """Combine CV skills (name + synonym) + tools into one list"""
    terms_set = set()
    
    for skill in cv_data.get("skills", []):
        name = normalize_text(skill.get("name", ""))
        synonym = normalize_text(skill.get("synonym", ""))
        
        if name:
            terms_set.add(name)
        if synonym:
            terms_set.add(synonym)
    
    for tool in cv_data.get("tools", []):
        if tool:
            terms_set.add(normalize_text(tool))
    
    return list(terms_set)