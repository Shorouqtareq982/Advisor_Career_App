from pydantic import BaseModel
from typing import List, Optional

class TrackSchema(BaseModel):
    track_id: int
    track_name: str
    description: Optional[str] = None

class CareerPlanCreateSchema(BaseModel):
    user_id: str
    track_id: int
    duration_months: int = 6

class CareerPlanResponseSchema(BaseModel):
    plan_id: int
    user_id: str
    track_id: int
    duration_months: int
    duration_weeks: int
    created_at: str
    saved: bool

class PlanContentSchema(BaseModel):
    week_number: int
    skill_name: str
    goal: str
    course_link: Optional[str] = None

class SkillSchema(BaseModel):
    skill_id: int
    skill_name: str
    description: Optional[str] = None