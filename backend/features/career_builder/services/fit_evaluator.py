from typing import Dict, List, Any

class FitEvaluator:

    def evaluate(
        self,
        match_percentage: float,
        skill_gaps: List[Dict[str, Any]]
    ) -> Dict[str, Any]:

        core_gaps = [
            gap for gap in skill_gaps
            if gap.get("is_core", True) and gap.get("status") in ("missing", "partial")
        ]

        missing_core_skills = [gap["skill_name"] for gap in core_gaps]
        warnings = []

        severe_core_gaps = [
            gap for gap in core_gaps
            if gap.get("status") == "missing" or gap.get("gap_score", 0) >= 0.75
        ]

        # ============================
        # Improved Logic
        # ============================

        if match_percentage >= 70 and len(severe_core_gaps) == 0:
            fit_status = "good_fit"

        elif match_percentage >= 40:
            fit_status = "moderate_fit"

            if missing_core_skills:
                warnings.append(
                    f"You are missing some core skills such as: {', '.join(missing_core_skills[:3])}"
                )

            if severe_core_gaps:
                warnings.append(
                    "There are significant gaps in important core skills. You may need extra effort."
                )

        else:
            fit_status = "poor_fit"

            warnings.append(
                "Your current profile is far from the track requirements."
            )

            if missing_core_skills:
                warnings.append(
                    f"You should first learn foundational skills like: {', '.join(missing_core_skills[:3])}"
                )

        # ============================
        # Smart Plan Decision
        # ============================

        can_generate_plan = fit_status != "poor_fit"

        return {
            "fit_status": fit_status,
            "fit_score": round(match_percentage, 1),
            "missing_core_skills": missing_core_skills,
            "warnings": warnings,
            "can_generate_plan": can_generate_plan,
        }