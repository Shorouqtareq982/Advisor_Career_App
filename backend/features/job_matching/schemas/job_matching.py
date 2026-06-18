from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime


# ==================== CV Extraction Schemas ====================

class SkillWithSynonym(BaseModel):
    """Skill with its synonym (full form if abbreviated)"""
    name: str
    synonym: str = ""  # Full form if abbreviation, empty otherwise


class CVExtractedInfo(BaseModel):
    """Data extracted from CV by LLM"""
    skills: List[SkillWithSynonym]  # Skills with synonyms
    tools: List[str] = []  # Tools, frameworks, platforms
    experience_years: int = 0  # Years of experience (integer)
    job_titles: List[str] = []  # Current/most recent job titles
    education: str = ""  # Education level and field
    seniority: str = ""  # junior / mid / senior
    domains: List[str] = []  # Fields of expertise
    languages: List[str] = []  # Spoken languages
    certifications: List[str] = []  # Professional certifications


# ==================== Job Matching Schemas ====================

class JobMatch(BaseModel):
    """Single job match result returned to frontend"""
    rank: int
    job_title: str
    company: str
    location: str
    work_mode: str  # onsite / remote
    job_type: str  # full-time / part-time
    link: str
    description_preview: str  # Cleaned and truncated (max 1000 chars)
    match_score: float  # 0-100 percentage
    explanation: Optional[str] = ""
    common_skills: List[str] = []
    common_domains: List[str] = []


class MatchJobsResponse(BaseModel):
    """Final response for /match-jobs endpoint"""
    success: bool
    cv_info: CVExtractedInfo
    matches: List[JobMatch]
    message: Optional[str] = None
    error: Optional[str] = None


# ==================== Saved Jobs Schemas ====================

class SavedJob(BaseModel):
    """Saved job in database"""
    id: str
    user_id: str
    job_data: Dict[str, Any]
    saved_at: datetime


class SaveJobRequest(BaseModel):
    """Request body for saving a job"""
    job_data: Dict[str, Any]


class SavedJobsResponse(BaseModel):
    """Response for GET /saved-jobs endpoint"""
    success: bool
    saved_jobs: List[SavedJob]
    error: Optional[str] = None


class DeleteSavedJobResponse(BaseModel):
    """Response for DELETE /unsave-job endpoint"""
    success: bool
    message: str
    error: Optional[str] = None


# ==================== Dropdown Lists Schemas ====================

class JobTitleResponse(BaseModel):
    """Response for GET /job-titles endpoint"""
    success: bool
    job_titles: List[str]
    error: Optional[str] = None


class CountryItem(BaseModel):
    """Single country item with code and name"""
    code: str
    name: str


class CountriesResponse(BaseModel):
    """Response for GET /countries endpoint"""
    success: bool
    countries: List[CountryItem]
    error: Optional[str] = None

class SaveMatchResultsRequest(BaseModel):
    results: List[Dict[str, Any]]


class MatchResultsResponse(BaseModel):
    """Response لـ GET /results"""
    success: bool
    results: List[Dict[str, Any]]
    error: Optional[str] = None