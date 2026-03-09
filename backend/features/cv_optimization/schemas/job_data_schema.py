from typing import List
from pydantic import BaseModel, Field

class JobData(BaseModel):
    job_title: str = Field(...,description="The specific role, its level, and scope within the organization.")
    job_purpose: str = Field(...,description="A high-level overview of the role and why it exists in the organization.")
    keywords: List[str] = Field(...,description="Key expertise, skills, and requirements the job demands.")
    required_skills: List[str] = Field(...,description="The essential skills and competencies mentioned in the job description that are necessary to perform the job effectively.")
    preferred_skills: List[str] = Field(...,description="Additional skills and competencies that are not strictly required but are highly desirable for the job.")
    minimum_experience: str = Field(...,description="The minimum level of experience required for the job, such as years of experience or specific types of prior roles.")
    maximum_experience: str = Field(...,description="The maximum level of experience that the job is suitable for, if applicable.")
    education_requirements: List[str] = Field(...,description="The educational qualifications required for the job, such as specific degrees, certifications, or fields of study.")
    job_duties_and_responsibilities: List[str] = Field(...,description="Focus on essential functions, their frequency and importance, level of decision-making, areas of accountability, and any supervisory responsibilities.")
    company_name: str = Field(...,description="The name of the hiring organization.")
    company_details: str = Field(...,description="Overview, mission, values, or way of working that could be relevant for tailoring a resume or cover letter.")