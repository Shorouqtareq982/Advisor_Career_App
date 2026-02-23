"""
Career Planning Schemas
Pydantic models for request/response validation
"""
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any, Literal
from uuid import UUID
from datetime import datetime
from enum import Enum


# =====================================================
# ENUMS
# =====================================================

class LevelEnum(str, Enum):
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"


class SkillStatus(str, Enum):
    HAS = "has"
    MISSING = "missing"
    PARTIAL = "partial"


class CurrentLevel(str, Enum):
    NONE = "none"
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"


# =====================================================
# SKILL SCHEMAS
# =====================================================

class SkillBase(BaseModel):
    skill_id: int
    skill_name: str
    category: str


class SkillDetail(SkillBase):
    importance_weight: int
    beginner_weeks: int
    intermediate_weeks: int
    advanced_weeks: int


class SkillGap(BaseModel):
    skill_id: int
    skill_name: str
    status: SkillStatus
    current_level: CurrentLevel
    required_level: LevelEnum
    gap_score: float = Field(..., ge=0.0, le=1.0)
    importance_weight: int
    required_weeks: int


# =====================================================
# TRACK SCHEMAS
# =====================================================

class TrackBase(BaseModel):
    track_id: int
    track_name: str
    description: str


class TrackSummary(TrackBase):
    total_skills: int
    min_beginner_weeks: int
    min_intermediate_weeks: int
    min_advanced_weeks: int
    avg_importance: float


class TrackWithSkills(TrackBase):
    skills: List[SkillDetail]


# =====================================================
# CV ANALYSIS REQUEST/RESPONSE
# =====================================================

class CVAnalysisRequest(BaseModel):
    cv_id: UUID
    track_id: int
    
    class Config:
        json_schema_extra = {
            "example": {
                "cv_id": "123e4567-e89b-12d3-a456-426614174000",
                "track_id": 1
            }
        }


class ExtractedSkill(BaseModel):
    skill_name: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    matched_skill_id: Optional[int] = None


class CVAnalysisResponse(BaseModel):
    cv_id: UUID
    track_id: int
    track_name: str
    detected_level: LevelEnum
    extracted_skills: List[ExtractedSkill]
    matched_skills_count: int
    skill_gaps: List[SkillGap]
    realism_check: Dict[str, Any]
    
    class Config:
        json_schema_extra = {
            "example": {
                "cv_id": "123e4567-e89b-12d3-a456-426614174000",
                "track_id": 1,
                "track_name": "Backend Development",
                "detected_level": "intermediate",
                "extracted_skills": [
                    {"skill_name": "Python", "confidence": 0.95, "matched_skill_id": 1},
                    {"skill_name": "SQL", "confidence": 0.88, "matched_skill_id": 2}
                ],
                "matched_skills_count": 3,
                "skill_gaps": [],
                "realism_check": {
                    "is_realistic": True,
                    "min_weeks_required": 20,
                    "compression_ratio": 0.85
                }
            }
        }


# =====================================================
# PLAN GENERATION
# =====================================================

class PlanGenerationRequest(BaseModel):
    user_id: UUID
    cv_id: UUID
    track_id: int
    confirmed_level: LevelEnum
    duration_weeks: int
    selected_skill_ids: Optional[List[int]] = None  # If user wants to focus on specific skills
    
    @validator('duration_weeks')
    def validate_duration(cls, v):
        if v < 4 or v > 104:  # 1 month to 2 years
            raise ValueError('Duration must be between 4 and 104 weeks')
        return v


class WeeklyContent(BaseModel):
    week_number: int
    skill_id: int
    skill_name: str
    topic: str
    description: str
    resources: List[str]


class GeneratedPlan(BaseModel):
    track_id: int
    track_name: str
    level: LevelEnum
    duration_weeks: int
    total_skills: int
    weekly_breakdown: List[WeeklyContent]


class PlanGenerationResponse(BaseModel):
    plan: GeneratedPlan
    metadata: Dict[str, Any]
    warnings: Optional[List[str]] = None


# =====================================================
# SAVE PLAN
# =====================================================

class SavePlanRequest(BaseModel):
    user_id: UUID
    cv_id: UUID
    track_id: int
    detected_level: LevelEnum
    confirmed_level: LevelEnum
    duration_weeks: int
    skill_gaps: List[SkillGap]
    weekly_content: List[WeeklyContent]


class SavePlanResponse(BaseModel):
    plan_id: int
    message: str
    created_at: datetime


# =====================================================
# GET USER PLANS
# =====================================================

class UserPlanSummary(BaseModel):
    plan_id: int
    track_name: str
    level: LevelEnum
    duration_weeks: int
    progress_percentage: float
    created_at: datetime
    updated_at: datetime


class UserPlansResponse(BaseModel):
    user_id: UUID
    plans: List[UserPlanSummary]
    total_plans: int


# =====================================================
# REALISM CHECK
# =====================================================

class RealismCheckRequest(BaseModel):
    track_id: int
    level: LevelEnum
    requested_weeks: int


class RealismCheckResponse(BaseModel):
    is_realistic: bool
    min_weeks_required: int
    suggested_min_weeks: int
    requested_weeks: int
    compression_ratio: float
    message: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "is_realistic": False,
                "min_weeks_required": 24,
                "suggested_min_weeks": 20,
                "requested_weeks": 12,
                "compression_ratio": 0.50,
                "message": "Duration too short. Minimum 20 weeks required (80% compression)."
            }
        }


# =====================================================
# SKILL MATCHING
# =====================================================

class SkillMatchRequest(BaseModel):
    cv_text: str
    track_id: Optional[int] = None


class MatchedSkill(BaseModel):
    skill_id: int
    skill_name: str
    category: str
    confidence: float
    track_relevance: List[str]  # Which tracks use this skill


class SkillMatchResponse(BaseModel):
    detected_skills: List[MatchedSkill]
    total_matched: int
    suggested_tracks: List[TrackSummary]


# =====================================================
# ERROR RESPONSES
# =====================================================

class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    error_code: Optional[str] = None