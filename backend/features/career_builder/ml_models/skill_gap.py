def analyze_skill_gap(user_skills: list, required_skills: list) -> dict:
    missing = [s for s in required_skills if s not in user_skills]
    return {
        "missing_count": len(missing),
        "missing_skills": missing,
        "completion_percentage": (len(user_skills) / len(required_skills)) * 100 if required_skills else 0
    }