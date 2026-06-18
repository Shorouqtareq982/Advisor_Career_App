from fastapi import APIRouter, HTTPException, Request, Depends
from fastapi.security import HTTPBearer
from typing import List, Dict, Any
from ..repositories.job_matching_repository import ( save_job, get_saved_jobs, delete_saved_job, is_job_already_saved, save_match_results, get_match_results)
from ..schemas.job_matching import (
    SavedJob, SaveJobRequest, SavedJobsResponse, DeleteSavedJobResponse,
    MatchResultsResponse, SaveMatchResultsRequest
)

router = APIRouter(
    prefix="/job-matching",
    tags=["Job Matching"],
    dependencies=[Depends(HTTPBearer())]  
)

def get_user_id(request: Request) -> str:
    user = getattr(request.state, "user", None)

    print("USER =", user)

    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")

    user_id = user.get("sub")

    print("USER ID =", user_id)

    return user_id


@router.post("/", response_model=SavedJob)
async def create_saved_job(
    request: Request,
    save_request: SaveJobRequest
):
    user_id = get_user_id(request)
    
    # Check if already saved
    job_link = save_request.job_data.get("link")
    if job_link and is_job_already_saved(user_id, job_link):
        raise HTTPException(status_code=400, detail="Job already saved")
    
    saved = save_job(user_id, save_request.job_data)
    if not saved:
        raise HTTPException(status_code=400, detail="Failed to save job")
    return saved


@router.get("/", response_model=SavedJobsResponse)
async def list_saved_jobs(
    request: Request
):
    user_id = get_user_id(request)
    jobs = get_saved_jobs(user_id)
    return SavedJobsResponse(success=True, saved_jobs=jobs, error=None)


@router.delete("/{job_id}", response_model=DeleteSavedJobResponse)
async def remove_saved_job(
    request: Request,
    job_id: str
):
    user_id = get_user_id(request)
    deleted = delete_saved_job(user_id, job_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Saved job not found")
    return DeleteSavedJobResponse(success=True, message="Job removed from saved list", error=None)

# ────── Match Results Endpoints ──────

@router.post("/results", response_model=dict)
async def save_results(
    request: Request,
    body: SaveMatchResultsRequest
):
    user_id = get_user_id(request)
    success = save_match_results(user_id, body.results)
    return {"success": success}


@router.get("/results", response_model=MatchResultsResponse)
async def get_results(request: Request):
    user_id = get_user_id(request)
    results = get_match_results(user_id)
    return MatchResultsResponse(success=True, results=results, error=None)