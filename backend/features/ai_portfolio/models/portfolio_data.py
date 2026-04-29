# app/models/portfolio.py

from fastapi import UploadFile
from pydantic import BaseModel, Field
from typing import List, Optional


class ExperienceItem(BaseModel):
    job_title: str = ""
    company: str = ""
    location: str = ""
    period: str = ""
    description: str = ""


class EducationItem(BaseModel):
    degree: str = ""
    field: str = ""
    institution: str = ""
    location: str = ""
    period: str = ""
    description: str = ""


class ProjectItem(BaseModel):
    name: str = ""
    description: str = ""
    technologies: str = ""
    link: str = ""


class PortfolioData(BaseModel):
    name: str = ""
    title: str = ""
    about: str = ""
    email: str = ""
    phone: str = ""
    location: str = ""
    github: str = ""
    linkedin: str = ""
    twitter: str = ""

    selected_template: int = 0

    skills: List[str] = Field(default_factory=list)
    languages: List[str] = Field(default_factory=list)

    experiences: List[ExperienceItem] = Field(default_factory=list)
    education: List[EducationItem] = Field(default_factory=list)
    projects: List[ProjectItem] = Field(default_factory=list)
    
    profile_image_url: Optional[str] = None