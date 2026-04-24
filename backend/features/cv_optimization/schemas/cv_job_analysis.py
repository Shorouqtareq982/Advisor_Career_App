from math import ceil
from typing import Any, Iterable, List, Optional
from pydantic import BaseModel, Field, field_validator, model_validator


def _normalize_and_validate_terms(terms: Iterable[str], max_words: int = 4) -> List[str]:
    """Normalize terms, enforce concise length, and deduplicate case-insensitively."""
    normalized_terms: List[str] = []
    seen_terms = set()

    for raw_term in terms:
        if not isinstance(raw_term, str):
            raise ValueError("Each term must be a string.")
        term = " ".join(raw_term.split())
        if not term:
            raise ValueError("Terms must not be empty.")

        word_count = len(term.split())
        if word_count > max_words:
            raise ValueError(
                f"Each term must be {max_words} words or fewer. Invalid term: '{term}'"
            )

        key = term.casefold()
        if key in seen_terms:
            continue

        seen_terms.add(key)
        normalized_terms.append(term)

    return normalized_terms


def _normalize_terms_before_validation(value: Any, max_words: int = 4) -> List[str]:
    """Normalize list-like values before field constraints (e.g., max_length) run."""
    if not isinstance(value, list):
        raise ValueError("Value must be a list of strings.")
    return _normalize_and_validate_terms(value, max_words=max_words)


class PassNotes(BaseModel):
    """
    Represents the pass/fail result and human-readable notes for a resume section.
    """
    Pass: bool = Field(
        ...,
        description=(
            "Whether the section passes the assistant's minimum checks. "
            "True = section passes basic ATS readability & content checks; "
            "False = section failed (missing/incorrect formatting or critical content)."
        ),
    )
    Notes: str = Field(
        "",
        max_length=500,
        description=(
            "Detailed notes about why the section passed or failed. "
            "Include formatting issues, missing fields, missing metrics, or other actionable observations. "
            "Maximum 30 words."
        ),
    )

    # @field_validator("Notes", mode="before")
    # @classmethod
    # def validate_notes_word_count(cls, value: Any) -> str:
    #     if value is None:
    #         return ""
    #     if not isinstance(value, str):
    #         raise ValueError("Notes must be a string.")

    #     normalized_value = " ".join(value.split())
    #     if len(normalized_value.split()) > 30:
    #         raise ValueError("Notes must be 30 words or fewer.")
    #     return normalized_value

    # @model_validator(mode="after")
    # def validate_failed_section_has_notes(self) -> "PassNotes":
    #     if not self.Pass and not self.Notes:
    #         raise ValueError("Notes are required when Pass is False.")
    #     return self

class SectionAnalysis(BaseModel):
    """Per-section pass/fail evaluation with notes (see cv_analysis_prompt for detailed criteria)."""
    Contact_Info: PassNotes = Field(
        ...,
        description="Pass if Name, Email, Phone all present. Fail if any missing."
    )
    Work_Experience: PassNotes = Field(
        ...,
        description="Pass if bullets with measurable achievements present. Each entry needs company, title, dates, location."
    )
    Education: PassNotes = Field(
        ...,
        description="Pass if degree, institution, and dates present."
    )
    Skills: PassNotes = Field(
        ...,
        description="Pass if at least 5 relevant, non-generic skills listed in ATS-friendly format."
    )
    Additional_Sections: PassNotes = Field(
        ...,
        description="Pass if relevant sections (Certifications, Projects, etc.) present and add value."
    )

class SkillsAnalysis(BaseModel):
    """Skills matching (1-4 word terms, case-normalized, no duplicates—see cv_analysis_prompt for rules)."""
    Matched_Skills: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="Skills in both JD and CV (1-4 words each, case-normalized, no duplicates)."
    )
    Missing_Skills: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="Key skills in JD but missing from CV (1-4 words each). Prioritize critical skills."
    )

    # @field_validator("Matched_Skills", "Missing_Skills", mode="before")
    # @classmethod
    # def validate_skill_terms(cls, value: Any) -> List[str]:
    #     return _normalize_terms_before_validation(value, max_words=4)

class ExperienceAlignment(BaseModel):
    """Experience and responsibility matching (verb+object extraction—see cv_analysis_prompt for rules)."""
    Matched_Experience: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="CV responsibilities/achievements matching JD requirements."
    )
    Missing_Experience: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="Experience/responsibilities required by JD but missing from CV. Prioritize critical gaps."
    )

class KeywordAnalysis(BaseModel):
    """Keyword extraction and matching from JD (1-4 word terms, case-normalized, no duplicates—see cv_analysis_prompt)."""
    Keywords_in_Job_Description: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="Important keywords from JD: tools, technologies, methodologies, certifications (1-4 words each)."
    )
    Matched_Keywords: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="JD keywords found in CV (case-normalized, no duplicates)."
    )
    Missing_Keywords: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="Keywords from JD not in CV. Prioritize ATS-critical terms."
    )

    # @field_validator("Keywords_in_Job_Description", "Matched_Keywords", "Missing_Keywords", mode="before")
    # @classmethod
    # def validate_keyword_terms(cls, value: Any) -> List[str]:
    #     return _normalize_terms_before_validation(value, max_words=4)

    # @model_validator(mode="after")
    # def validate_keyword_subsets(self) -> "KeywordAnalysis":
    #     jd_keywords = {term.casefold() for term in self.Keywords_in_Job_Description}
    #     matched_keywords = {term.casefold() for term in self.Matched_Keywords}
    #     if not matched_keywords.issubset(jd_keywords):
    #         raise ValueError("Matched_Keywords must be a subset of Keywords_in_Job_Description.")

    #     missing_keywords = {term.casefold() for term in self.Missing_Keywords}
    #     overlap = matched_keywords.intersection(missing_keywords)
    #     if overlap:
    #         raise ValueError("Matched_Keywords and Missing_Keywords must not overlap.")

    #     return self

class JobAlignment(BaseModel):
    """Resume-JD match score (0-100): Title(5) + Education(5) + Experience_Level(5) + Skills(30) + Keywords(30) + Experience(25). See cv_analysis_prompt.py for detailed formulas and matching rules."""
    Match_Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "0–100 holistic score reflecting resume-JD match. "
            "Formula: Match_Score = Title_Match(5) + Education_Level_Match(5) + Experience_Level_Match(5) + "
            "Skills_Score(30) + Keyword_Score(30) + Experience_Score(25). "
            "Maximum: 100 points. Round UP all intermediate calculations."
        ),
    )
    Title_Match: bool = Field(
        ...,
        description="Whether CV title matches or aligns with JD title (5 points if True)."
    )
    Experience_Level_Match: bool = Field(
        ...,
        description="Whether CV experience level (junior/mid/senior) matches JD requirements (5 points if True)."
    )
    Education_Level_Match: bool = Field(
        ...,
        description="Whether CV education meets or exceeds JD requirements (5 points if True)."
    )    
    Skills_Analysis: SkillsAnalysis
    Experience_Alignment: ExperienceAlignment
    Keyword_Analysis: KeywordAnalysis

    @staticmethod
    def _ratio_score(matched: int, total: int, max_points: int) -> int:
        if total <= 0:
            return 0
        return min(ceil((matched / total) * max_points), max_points)

    # @model_validator(mode="after")
    # def validate_match_score_consistency(self) -> "JobAlignment":
    #     title_points = 5 if self.Title_Match else 0
    #     education_points = 5 if self.Education_Level_Match else 0
    #     experience_level_points = 5 if self.Experience_Level_Match else 0

    #     total_required_skills = len(self.Skills_Analysis.Matched_Skills) + len(self.Skills_Analysis.Missing_Skills)
    #     skills_points = self._ratio_score(
    #         matched=len(self.Skills_Analysis.Matched_Skills),
    #         total=total_required_skills,
    #         max_points=30,
    #     )

    #     total_keywords = len(self.Keyword_Analysis.Keywords_in_Job_Description)
    #     keyword_points = self._ratio_score(
    #         matched=len(self.Keyword_Analysis.Matched_Keywords),
    #         total=total_keywords,
    #         max_points=30,
    #     )

    #     total_responsibilities = len(self.Experience_Alignment.Matched_Experience) + len(self.Experience_Alignment.Missing_Experience)
    #     experience_points = self._ratio_score(
    #         matched=len(self.Experience_Alignment.Matched_Experience),
    #         total=total_responsibilities,
    #         max_points=25,
    #     )

    #     expected_match_score = min(
    #         title_points + education_points + experience_level_points + skills_points + keyword_points + experience_points,
    #         100,
    #     )

    #     if self.Match_Score != expected_match_score:
    #         raise ValueError(
    #             f"Match_Score mismatch: expected {expected_match_score}, got {self.Match_Score}."
    #         )

    #     return self

class IndustryKeywordOptimization(BaseModel):
    """ Industry/role-specific recommendations (1-4 word terms, placement suggestions—see cv_analysis_prompt.py). """
    Recommended_Keywords: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="Industry-standard keywords recommended but missing from CV (1-4 words each)."
    )
    Suggestions: List[str] = Field(
        default_factory=list,
        max_length=10,
        description="Where to naturally place keywords (e.g., 'Add Docker to Skills section')."
    )

    # @field_validator("Recommended_Keywords", mode="before")
    # @classmethod
    # def validate_recommended_keyword_terms(cls, value: Any) -> List[str]:
    #     return _normalize_terms_before_validation(value, max_words=4)

class ATSAnalysisResponse(BaseModel):
    """
    Complete ATS and job alignment analysis. See cv_analysis_prompt.py for all evaluation rules, scoring formulas, and output requirements.
        """
    Section_Analysis: SectionAnalysis = Field(
        ..., 
        description=(
            "Per-section Pass/Fail evaluation with detailed notes. Evaluates: Contact_Info (Name/Email/Phone required), "
            "Work_Experience (bullets, achievements, required fields), Education (degree, institution, dates), "
            "Skills (≥5 relevant, ATS-friendly), Additional_Sections (relevance, value-add)."
        )
    )
    Job_Alignment: Optional[JobAlignment] = Field(
        None, 
        description=(
            "CV vs JD matching analysis. Match_Score (0-100) = Title(5) + Education(5) + Experience_Level(5) + "
            "Skills(30) + Keywords(30) + Experience(25). Includes detailed breakdowns for each component."
        )
    )
    Industry_Keyword_Optimization: IndustryKeywordOptimization = Field(
        ...,
        description=(
            "Industry/role-specific keyword recommendations not in CV (even if missing from JD). "
            "Includes specific placement suggestions for natural integration."
        )
    )
    Improvement_Tips: List[str] = Field(
        default_factory=list,
        max_length=10,
        description="Specific, actionable improvement suggestions with examples."
    )