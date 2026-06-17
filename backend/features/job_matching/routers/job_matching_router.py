from fastapi import APIRouter, UploadFile, File, Form, Depends
from typing import List
import sys
from pathlib import Path

# Add backend to path if needed
backend_path = Path(__file__).parent.parent.parent
sys.path.append(str(backend_path))

from features.job_matching.services.cv_parser import extract_text_from_cv
from features.job_matching.services.llm_extractor import extract_cv_info
from features.job_matching.services.job_fetcher import fetch_jobs_from_jsearch
from features.job_matching.services.job_matcher import calculate_total_match_score
from features.job_matching.services.summary_builder import build_cv_summary
from features.job_matching.services.llm_explainer import explain_top_jobs
from features.job_matching.schemas.job_matching import (
    MatchJobsResponse, JobMatch, JobTitleResponse, CountriesResponse
)
from features.job_matching.repositories.job_matching_repository import (
    get_all_job_titles, get_all_countries
)

router = APIRouter(prefix="/job-matching", tags=["Job Matching"])


# ==================== Dropdown Lists Endpoints (NEW) ====================

@router.get("/job-titles", response_model=JobTitleResponse)
async def get_job_titles():
    """
    Get list of all job titles for frontend dropdown.
    """
    try:
        titles = get_all_job_titles()
        return JobTitleResponse(success=True, job_titles=titles, error=None)
    except Exception as e:
        return JobTitleResponse(success=False, job_titles=[], error=str(e))


@router.get("/countries", response_model=CountriesResponse)
async def get_countries():
    """
    Get list of all countries (code + name) for frontend dropdown.
    """
    try:
        countries = get_all_countries()
        return CountriesResponse(success=True, countries=countries, error=None)
    except Exception as e:
        return CountriesResponse(success=False, countries=[], error=str(e))


# ==================== Main Matching Endpoint ====================

@router.post("/match-jobs", response_model=MatchJobsResponse)
async def match_jobs(
    job_title: str = Form(...),
    job_type: str = Form(...),
    country: str = Form(...),
    work_mode: str = Form(...),
    cv_file: UploadFile = File(...)
):
    """
    Main endpoint for job matching.
    User selects filters and uploads CV, returns top 5 matched jobs with explanations.
    """
    try:
        # 1. Extract text from CV
        cv_text = await extract_text_from_cv(cv_file)
        
        # 2. Extract structured data from CV using LLM
        cv_data = extract_cv_info(cv_text, job_title)
        
        # 3. Build CV summary for LLM explanations
        cv_summary = build_cv_summary(cv_data)
        
        # 4. Fetch jobs from JSearch API
        jobs = await fetch_jobs_from_jsearch(
            job_title=job_title,
            country_name=country,
            job_type=job_type,
            work_mode=work_mode
        )
        
        if not jobs:
            return MatchJobsResponse(
                success=False,
                cv_info=cv_data,
                matches=[],
                message="No jobs found matching your criteria. Try different filters.",
                error=None
            )
        
        # 5. Calculate match score for each job
        for job in jobs:
            score = calculate_total_match_score(
                cv_data=cv_data,
                job_text=job.get("description_full", ""),
                matches_preferences=job.get("matches_preferences", False),
                is_fallback=job.get("is_fallback", False)
            )
            job["match_score"] = score
        
        # 6. Sort and get top 5
        sorted_jobs = sorted(jobs, key=lambda x: x.get("match_score", 0), reverse=True)
        top_5 = sorted_jobs[:5]
        
        # 7. Generate explanations for top 5 jobs using LLM
        explained_jobs = explain_top_jobs(cv_summary, top_5)
        
        # 8. Prepare response matches
        matches = []
        for i, job in enumerate(explained_jobs, 1):
            matches.append(JobMatch(
                rank=i,
                job_title=job.get("title", ""),
                company=job.get("company", ""),
                location=job.get("location", ""),
                work_mode=job.get("work_mode", ""),
                job_type=job.get("job_type", ""),
                link=job.get("link", ""),
                description_preview=job.get("description_preview", ""),
                match_score=job.get("match_score", 0),
                explanation=job.get("explanation", ""),
                common_skills=[],
                common_domains=[]
            ))
        
        # 9. Prepare message
        if len(jobs) < 5:
            message = f"⚠️ Only {len(jobs)} jobs found matching your criteria."
        else:
            message = "✅ Top 5 jobs based on your CV and preferences."
        
        return MatchJobsResponse(
            success=True,
            cv_info=cv_data,
            matches=matches,
            message=message,
            error=None
        )
        
    except Exception as e:
        return MatchJobsResponse(
            success=False,
            cv_info={},
            matches=[],
            message=None,
            error=str(e)
        )