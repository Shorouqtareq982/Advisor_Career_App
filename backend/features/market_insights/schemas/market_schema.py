from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime


class JobData(BaseModel):
    job_title: str
    source: str
    country: Optional[str] = None
    governorate: Optional[str] = None
    location: Optional[str] = None
    time_posted: Optional[str] = None
    min_experience: Optional[int] = None
    max_experience: Optional[int] = None
    avg_experience: Optional[float] = None
    experience_level: Optional[str] = None
    skills: Optional[str] = None
    salary_min: Optional[float] = None
    salary_max: Optional[float] = None
    job_url: str
    sheet: str
    company: Optional[str] = None


class CrawlerState(BaseModel):
    sheet: str
    state: Dict[str, Any]


class JobStatus(BaseModel):
    job_name: Optional[str] = None
    done: bool = False
    count: int = 0
    data: Optional[Dict[str, Any]] = None


class GlobalStatus(BaseModel):
    auto_running: bool = True
    scraping_running: bool = False
    jobs_processed: int = 0
    current_job: Optional[str] = None


class MarketInsights(BaseModel):
    total_jobs: int = 0
    jobs_by_source: Dict[str, int] = {}
    jobs_by_country: Dict[str, int] = {}
    jobs_by_experience_level: Dict[str, int] = {}
    avg_experience_by_level: Dict[str, float] = {}
    salary_ranges: Dict[str, Optional[float]] = {}
    top_skills: Dict[str, int] = {}
    recent_jobs: int = 0
    error: Optional[str] = None
