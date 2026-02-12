from typing import List
from pydantic import BaseModel, Field


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
        description=(
            "Detailed notes about why the section passed or failed. "
            "Include formatting issues, missing fields, missing metrics, or other actionable observations."
        ),
    )


class SectionAnalysis(BaseModel):
    """
    Per-section evaluation of the resume with an overall sections score.
    """
    Overall_Section_Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "Aggregated 0–100 score summarizing the quality and completeness of all major resume sections "
            "(Contact Info, Work Experience, Education, Skills). "
            "Score factors: presence of required sections, formatting, completeness, and presence of metrics."
        ),
    )
    Contact_Info: PassNotes = Field(
        ...,
        description="Evaluation for the Contact Info section: readability of name, email, phone, and location."
    )
    Work_Experience: PassNotes = Field(
        ...,
        description=(
            "Evaluation for Work Experience: presence of company, title, dates, location, and impact-focused bullets. "
            "Notes should include missing quantifiable achievements and formatting problems."
        ),
    )
    Education: PassNotes = Field(
        ...,
        description="Evaluation for Education: presence of institution, degree, dates, and relevant honors or coursework."
    )
    Skills: PassNotes = Field(
        ...,
        description=(
            "Evaluation for Skills: clarity and relevance of listed hard and soft skills, separation of categories (e.g., "
            "tools, languages), and ATS-friendliness (avoid images/icons)."
        ),
    )
    Additional_Sections: PassNotes = Field(
        ...,
        description=(
            "Evaluation for other resume sections (Certifications, Projects, Publications, Volunteer, etc.). "
            "Notes should identify relevance and formatting issues."
        ),
    )


class SkillsAnalysis(BaseModel):
    Matched_Skills: List[str] = Field(
        default_factory=list,
        description="List of skills that appear in both the job description and the resume (exact or close matches).",
    )
    Missing_Skills: List[str] = Field(
        default_factory=list,
        description="Important skills required by the job description that are missing from the resume.",
    )


class ExperienceAlignment(BaseModel):
    Matched_Experience: List[str] = Field(
        default_factory=list,
        description=(
            "Specific responsibilities, achievements, or experience areas from the resume that align with the job "
            "description requirements."
        ),
    )
    Missing_Experience: List[str] = Field(
        default_factory=list,
        description=(
            "Experience or responsibility areas required by the job description that are not present or are weakly "
            "represented in the resume."
        ),
    )


class KeywordAnalysis(BaseModel):
    Keywords_in_Job_Description: List[str] = Field(
        default_factory=list,
        description="Keywords and phrases extracted from the job description (role-specific, industry terms, tools).",
    )
    Matched_Keywords: List[str] = Field(
        default_factory=list,
        description="Subset of job-description keywords that are present in the resume (helps With ATS matching).",
    )
    Missing_Keywords: List[str] = Field(
        default_factory=list,
        description="Keywords from the job description that do not appear in the resume and should be considered.",
    )


class JobAlignment(BaseModel):
    """
    Evaluation of how well the resume matches the job description across skills, experience, and keywords.
    """
    Match_Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "0–100 holistic score reflecting how well the resume matches the job description. "
            "Derived from skills alignment, experience alignment, keyword coverage, and relevance of achievements."
        ),
    )
    Skills_Analysis: SkillsAnalysis = Field(..., description="Detailed skills match and gaps.")
    Experience_Alignment: ExperienceAlignment = Field(..., description="Experience matches and missing experience areas.")
    Keyword_Analysis: KeywordAnalysis = Field(..., description="Keywords extracted from JD and match/miss results.")


class IndustryKeywordOptimization(BaseModel):
    Recommended_Keywords: List[str] = Field(
        default_factory=list,
        description=(
            "Industry- and role-specific keywords that are recommended but missing from the resume. "
            "Include terms important for ATS and recruiter search."
        ),
    )
    Suggestions: List[str] = Field(
        default_factory=list,
        description=(
            "Actionable suggestions for where to place missing keywords (e.g., 'Add to Skills', "
            "'Add to Work Experience bullet: \"...\"', 'Add to Summary'). "
            "Each suggestion should map a missing keyword to a natural placement."
        ),
    )


class ATSAnalysisResponse(BaseModel):
    """
    Top-level model for the ATS & job-alignment analysis output.
    Must follow the strict JSON structure required by downstream systems.
    """
    ATS_Readability_Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "0–100 score for ATS readability. Factors include structure & formatting checks (headings, bullets, layout), "
            "ATS parsing compatibility (no tables/graphics), contact info readability, file-level issues, and exact "
            "deduction reasons for any points lost."
        ),
    )
    Content_Quality_Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "0–100 score for content quality. Factors include writing quality (active verbs, clarity), "
            "achievement strength (measurable results/KPIs), skill coverage, and grammar/tense consistency. "
            "Detailed comments should justify the score."
        ),
    )
    Section_Analysis: SectionAnalysis = Field(..., description="Per-section pass/fail results and overall section score.")
    Job_Alignment: JobAlignment = Field(..., description="Resume vs job-description matching details and scores.")
    Industry_Keyword_Optimization: IndustryKeywordOptimization = Field(
        ...,
        description="Suggestions and missing industry keywords to improve discoverability and relevance."
    )
    ATS_Issues: List[str] = Field(
        default_factory=list,
        description=(
            "List of specific technical or formatting issues that could break ATS parsing (e.g., tables, text in images, "
            "non-standard fonts, unusual characters, headers/footers with critical info, hidden text). Be granular."
        ),
    )
    Improvement_Tips: List[str] = Field(
        default_factory=list,
        description=(
            "Highly actionable, non-generic improvement tips such as rewrite examples, bullet enhancements, "
            "where to add metrics, suggested keyword placements, and structural reordering. "
            "Each tip should be directly implementable."
        ),
    )