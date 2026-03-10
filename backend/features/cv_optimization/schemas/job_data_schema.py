from typing import List
from pydantic import BaseModel, Field

class JobData(BaseModel):
    job_title: str = Field(...,description="The specific role, its level, and scope within the organization.")
    job_purpose: str = Field(...,description="A high-level overview of the role and why it exists in the organization.")
    keywords: List[str] = Field(
        ...,
        description=(
            "Key expertise, skills, and requirements the job demands. "
            "IMPORTANT: Extract ONLY specific, concise terms (1-4 words max per item). "
            "Do NOT use full sentences or descriptions. "
            "Examples of CORRECT format: 'Python', 'Machine Learning', 'AWS', 'Team Leadership', 'Agile Methodology'. "
            "Examples of INCORRECT format: 'Experience with Python programming', 'Must have strong communication skills', 'Knowledge of cloud platforms'."
        )
    )
    required_skills: List[str] = Field(
        ...,
        description=(
            "The essential skills mentioned in the job description. "
            "CRITICAL: Each item must be a SINGLE SKILL NAME (1-4 words max), NOT a sentence or description. "
            "CORRECT examples: 'Python', 'Docker', 'SQL', 'Project Management', 'REST API Design'. "
            "INCORRECT examples: 'Must have experience with Python', 'Strong knowledge of Docker containers', 'Ability to write SQL queries'."
        )
    )
    preferred_skills: List[str] = Field(
        ...,
        description=(
            "Additional desirable skills mentioned in the job description. "
            "CRITICAL: Each item must be a SINGLE SKILL NAME (1-4 words max), NOT a sentence or description. "
            "CORRECT examples: 'Kubernetes', 'GraphQL', 'TypeScript', 'Scrum Master Certification'. "
            "INCORRECT examples: 'Experience with Kubernetes is a plus', 'Familiarity with GraphQL preferred'."
        )
    )
    minimum_experience: str = Field(...,description="The minimum level of experience required for the job, such as years of experience or specific types of prior roles.")
    maximum_experience: str = Field(...,description="The maximum level of experience that the job is suitable for, if applicable.")
    education_requirements: List[str] = Field(
        ...,
        description=(
            "The educational qualifications required for the job. "
            "CRITICAL: Each item must be CONCISE (1-6 words max). Extract the core requirement only. "
            "CORRECT examples: 'Bachelor in Computer Science', 'MBA', 'Master in Data Science', 'High School Diploma'. "
            "INCORRECT examples: 'Must have a Bachelor degree in Computer Science', 'Candidate should possess an MBA', 'Masters degree preferred'."
        )
    )
    job_duties_and_responsibilities: List[str] = Field(
        ...,
        description=(
            "Essential functions, their frequency and importance, level of decision-making, areas of accountability, and any supervisory responsibilities. "
            "Each item should be a clear, concise responsibility statement (typically 5-15 words). "
            "Focus on action verbs and measurable outcomes where possible."
        )
    )
    required_qualifications: List[str] = Field(
        ...,
        description=(
            "Essential qualifications including education, minimum experience, specific knowledge, skills, abilities, and any required licenses or certifications. "
            "CRITICAL: Each item must be CONCISE (1-8 words max). Extract the core qualification only. "
            "CORRECT examples: '5+ years Python development', 'AWS Certified Solutions Architect', 'Bachelor in Engineering', 'Fluent in Spanish'. "
            "INCORRECT examples: 'Candidate must have at least 5 years of Python development experience', 'Should be AWS Certified Solutions Architect', 'Bachelor degree in Engineering required'."
        )
    )
    preferred_qualifications: List[str] = Field(
        ...,
        description=(
            "Additional 'nice-to-have' qualifications that could set a candidate apart. "
            "CRITICAL: Each item must be CONCISE (1-8 words max). Extract the core qualification only. "
            "CORRECT examples: 'Master degree preferred', 'Experience with Kubernetes', 'Published research papers', 'Startup experience'. "
            "INCORRECT examples: 'Master degree would be a plus', 'Previous experience with Kubernetes is beneficial', 'Having published research papers is desirable'."
        )
    )
    company_name: str = Field(...,description="The name of the hiring organization.")
    company_details: str = Field(...,description="Overview, mission, values, or way of working that could be relevant for tailoring a resume or cover letter.")