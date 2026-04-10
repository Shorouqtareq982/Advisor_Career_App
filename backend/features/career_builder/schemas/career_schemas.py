"""
Career Planning Schemas
Pydantic models for request/response validation
"""

from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
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


class FitStatus(str, Enum):
    GOOD_FIT = "good_fit"
    MODERATE_FIT = "moderate_fit"
    POOR_FIT = "poor_fit"


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
    is_core: Optional[bool] = True


class FitAnalysis(BaseModel):
    fit_status: FitStatus
    fit_score: float = Field(..., ge=0.0, le=100.0)
    missing_core_skills: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)
    can_generate_plan: bool


class SkillOverride(BaseModel):
    skill_id: int
    level: CurrentLevel


class SkillTarget(BaseModel):
    skill_id: int
    target_level: LevelEnum


class ReviewableSkill(BaseModel):
    skill_id: int
    skill_name: str
    status: SkillStatus
    detected_level: Optional[CurrentLevel] = None
    confidence: float = Field(..., ge=0.0, le=1.0)
    needs_user_input: bool
    required_level: LevelEnum
    selected_by_default: bool


class LearningTarget(BaseModel):
    skill_id: int
    skill_name: str
    current_level: CurrentLevel
    target_level: LevelEnum
    required_level: LevelEnum
    required_weeks: int
    importance_weight: int
    learning_mode: str  # learn_from_scratch | level_up


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


class TrackDropdownItem(BaseModel):
    track_id: int
    track_name: str
    description: Optional[str] = None


class TrackListResponse(BaseModel):
    tracks: List[TrackDropdownItem]
    total: int


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
    reviewable_skills: List[ReviewableSkill] = Field(default_factory=list)
    fit_analysis: Optional[FitAnalysis] = None


# =====================================================
# CONFIRM FLOW
# =====================================================

class ConfirmRequest(BaseModel):
    cv_id: UUID
    track_id: int
    requested_weeks: int = Field(..., ge=1, le=104)
    available_hours_per_week: int = Field(..., ge=1, le=80)
    user_level: Optional[LevelEnum] = None

    selected_skill_ids: List[int] = Field(default_factory=list)
    skill_overrides: List[SkillOverride] = Field(default_factory=list)
    skill_targets: List[SkillTarget] = Field(default_factory=list)


# =====================================================
# PLAN GENERATION
# =====================================================

class PlanGenerateRequest(BaseModel):
    cv_id: UUID
    track_id: int
    duration_weeks: int = Field(..., ge=1, le=104)
    available_hours_per_week: Optional[int] = Field(default=None, ge=1, le=80)
    user_level: Optional[str] = None

    selected_skill_ids: Optional[List[int]] = None
    skill_targets: List[SkillTarget] = Field(default_factory=list)

    @validator("user_level")
    def validate_user_level(cls, v):
        if v is not None and v not in ("beginner", "intermediate", "advanced"):
            raise ValueError("user_level must be beginner, intermediate, or advanced")
        return v


class PlanRegenerateRequest(BaseModel):
    previous_plan: Dict[str, Any]
    feedback: str
    regeneration_mode: str = "full"


class ResourceItem(BaseModel):
    title: str
    url: str
    type: str


class WeeklyContent(BaseModel):
    week_number: int
    skill_id: int
    skill_name: str
    topic: str
    description: str
    resources: List[Any]


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
    available_hours_per_week: Optional[int] = Field(default=None, ge=1, le=80)
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
    track_relevance: List[str]


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