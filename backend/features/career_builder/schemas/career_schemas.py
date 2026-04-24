"""
Career Planning Schemas
Draft-first version:
1) analyze
2) confirm skills
3) confirm time
4) generate plan (draft only)
5) regenerate plan (draft only)
6) save plan (final persistence)
"""

from pydantic import BaseModel, Field
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


class StudyIntensity(str, Enum):
    LIGHT = "light"
    MODERATE = "moderate"
    INTENSIVE = "intensive"


class PlanFeedbackIntent(str, Enum):
    MORE_ADVANCED = "more_advanced"
    MORE_PRACTICAL = "more_practical"
    LESS_REPETITION = "less_repetition"
    FOCUS_SELECTED = "focus_selected_skills"
    FASTER_PROGRESS = "faster_progress"
    SIMPLER_BASICS = "simpler_basics"


# =====================================================
# SKILL SCHEMAS
# =====================================================

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


class ReviewableSkill(BaseModel):
    skill_id: int
    skill_name: str
    status: SkillStatus
    detected_level: Optional[CurrentLevel] = None
    confidence: float = Field(..., ge=0.0, le=1.0)
    needs_user_input: bool
    required_level: LevelEnum
    selected_by_default: bool


class SuggestedTarget(BaseModel):
    skill_id: int
    skill_name: str
    current_level: CurrentLevel
    suggested_target_level: LevelEnum
    target_reason: str
    learning_mode: str
    status: Optional[SkillStatus] = None
    is_core: Optional[bool] = True
    selected_by_user: bool = False


class LearningTarget(BaseModel):
    skill_id: int
    skill_name: str
    current_level: CurrentLevel
    target_level: LevelEnum
    required_level: LevelEnum
    required_weeks: int
    importance_weight: int
    learning_mode: str
    status: Optional[SkillStatus] = None
    is_core: Optional[bool] = True
    selected_by_user: bool = False


class AnalysisMetadata(BaseModel):
    match_percentage: float = Field(..., ge=0.0, le=100.0)
    matching_method: str
    analysis_quality: float = Field(..., ge=0.0, le=1.0)


# =====================================================
# CONFIRM SKILLS
# =====================================================

class ConfirmSkillsRequest(BaseModel):
    cv_id: UUID
    track_id: int
    selected_skill_ids: List[int] = Field(default_factory=list)
    skill_overrides: List[SkillOverride] = Field(default_factory=list)


class ConfirmSkillsResponse(BaseModel):
    status: str = "success"
    cv_id: UUID
    track_id: int
    track_name: str
    detected_level: LevelEnum
    selected_skill_ids: List[int] = Field(default_factory=list)
    reviewable_skills: List[ReviewableSkill] = Field(default_factory=list)
    skill_gaps: List[SkillGap] = Field(default_factory=list)
    detected_skill_levels: Dict[str, CurrentLevel] = Field(default_factory=dict)
    fit_analysis: Optional[FitAnalysis] = None
    metadata: Optional[AnalysisMetadata] = None


# =====================================================
# TIME GUIDANCE
# =====================================================

class TimeGuidanceInfo(BaseModel):
    minimum_weeks: int
    suitable_weeks: int
    maximum_weeks: int
    study_intensity: StudyIntensity
    minimum_weeks_breakdown: Dict[str, int] = Field(default_factory=dict)
    suitable_weeks_breakdown: Dict[str, int] = Field(default_factory=dict)
    maximum_weeks_breakdown: Dict[str, int] = Field(default_factory=dict)


class EnhancedRealismCheckInfo(BaseModel):
    is_realistic: bool
    adjustment: str
    zone: str
    requested_weeks: int
    available_hours_per_week: int
    study_intensity: StudyIntensity
    calculated_minimum_weeks: int
    calculated_suitable_weeks: int
    calculated_maximum_weeks: int
    warnings: List[str] = Field(default_factory=list)
    suggestions: List[str] = Field(default_factory=list)


class ConfirmTimeRequest(BaseModel):
    cv_id: UUID
    track_id: int
    requested_weeks: int = Field(..., ge=1, le=104)
    available_hours_per_week: int = Field(..., ge=1, le=80)


class ConfirmTimeResponse(BaseModel):
    status: str = "success"
    cv_id: UUID
    track_id: int
    track_name: str
    detected_level: LevelEnum
    available_hours_per_week: int
    requested_weeks: int
    selected_skill_ids: List[int] = Field(default_factory=list)
    suggested_targets: List[SuggestedTarget] = Field(default_factory=list)
    confirmed_learning_targets: List[LearningTarget] = Field(default_factory=list)
    realism: EnhancedRealismCheckInfo
    time_guidance: Optional[TimeGuidanceInfo] = None
    reviewable_skills: List[ReviewableSkill] = Field(default_factory=list)
    skill_gaps: List[SkillGap] = Field(default_factory=list)
    fit_analysis: Optional[FitAnalysis] = None
    metadata: Optional[AnalysisMetadata] = None


# =====================================================
# PLAN GENERATION
# =====================================================

class PlanGenerateRequest(BaseModel):
    cv_id: UUID
    track_id: int
    duration_weeks: int = Field(..., ge=1, le=104)
    available_hours_per_week: int = Field(..., ge=1, le=80)


class PlanRegenerateRequest(BaseModel):
    cv_id: Optional[UUID] = None
    track_id: Optional[int] = None
    previous_plan: Dict[str, Any]
    feedback_intents: List[PlanFeedbackIntent] = Field(..., min_length=1)
    regeneration_mode: str = Field(default="full")


class ResourceItem(BaseModel):
    title: str
    url: str
    type: str
    snippet: Optional[str] = None
    duration: Optional[str] = None
    score: Optional[float] = None
    youtube_duration_minutes: Optional[int] = None
    channel_title: Optional[str] = None
    query_context: Optional[str] = None


class WeeklyContent(BaseModel):
    week_number: int
    focus_skills: List[str] = Field(default_factory=list)
    topic: str
    description: str
    learning_outcomes: List[str] = Field(default_factory=list)
    expected_level_after_week: CurrentLevel
    study_guide: Optional[Dict[str, Any]] = None
    resources: List[ResourceItem] = Field(default_factory=list)
    resource_validation_report: Optional[Dict[str, Any]] = None


class DraftPlanResponse(BaseModel):
    status: str = "success"
    cv_id: Optional[UUID] = None
    track_id: int
    track_name: str
    duration_weeks: int
    available_hours_per_week: int
    planning_mode: str
    study_intensity: StudyIntensity
    current_average_level: CurrentLevel
    final_expected_level: CurrentLevel
    latest_detected_skill_levels: Dict[str, CurrentLevel] = Field(default_factory=dict)
    used_learning_targets: List[LearningTarget] = Field(default_factory=list)
    deferred_learning_targets: List[Dict[str, Any]] = Field(default_factory=list)
    generation_metadata: Dict[str, Any] = Field(default_factory=dict)
    plan_summary: str
    improvement_summary: str
    weekly_breakdown: List[WeeklyContent] = Field(default_factory=list)


# =====================================================
# SAVE PLAN
# =====================================================

class SavePlanRequest(BaseModel):
    user_id: UUID
    cv_id: UUID
    track_id: int


class SavePlanResponse(BaseModel):
    plan_id: int
    message: str
    created_at: datetime


# =====================================================
# ERRORS
# =====================================================

class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    error_code: Optional[str] = None