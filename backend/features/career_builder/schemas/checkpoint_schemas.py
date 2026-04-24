"""
Checkpoint Assessment Schemas
Supports the 32-week optimized plan with 9 assessment checkpoints
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from uuid import UUID
from datetime import datetime
from enum import Enum


# =====================================================
# ENUMS
# =====================================================

class CheckpointStatus(str, Enum):
    """Status of a checkpoint assessment"""
    NOT_STARTED = "not_started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    PASSED = "passed"
    NEEDS_REVIEW = "needs_review"


class AssessmentType(str, Enum):
    """Types of assessments at checkpoints"""
    THEORY_QUIZ = "theory_quiz"
    PRACTICAL_EXERCISE = "practical_exercise"
    PROJECT_SUBMISSION = "project_submission"
    MIXED = "mixed"


class LearningPhase(str, Enum):
    """8 Learning phases in the 32-week optimized plan"""
    FOUNDATION_1 = "foundation_1"          # Weeks 1-7: Fundamentals & Core Concepts
    FOUNDATION_2 = "foundation_2"          # Weeks 8-10: Building on Fundamentals
    INTERMEDIATE_1 = "intermediate_1"      # Weeks 11-17: Intermediate Techniques
    INTERMEDIATE_2 = "intermediate_2"      # Weeks 18-20: Advanced Intermediate
    INTEGRATION_1 = "integration_1"        # Weeks 21-26: Integration & Pattern Recognition
    INTEGRATION_2 = "integration_2"        # Weeks 27-28: Advanced Integration
    CAPSTONE_1 = "capstone_1"              # Weeks 29-30: Project Design & Preparation
    CAPSTONE_2 = "capstone_2"              # Weeks 31-32: Project Implementation & Portfolio


# =====================================================
# CHECKPOINT DEFINITIONS
# =====================================================

class CheckpointDefinition(BaseModel):
    """Definition of a checkpoint assessment"""
    checkpoint_id: int
    checkpoint_number: int  # 1-9
    week_number: int       # The week when checkpoint occurs
    phase: LearningPhase
    assessment_type: AssessmentType
    title: str
    description: str
    skills_assessed: List[int]  # skill_ids
    learning_outcomes: List[str]
    passing_score: float = Field(..., ge=0.0, le=100.0)
    estimated_duration_minutes: int
    instructions: str
    rubric: Optional[Dict[str, Any]] = None


# =====================================================
# OPTIMIZED PLAN STRUCTURE (32 WEEKS)
# =====================================================

class OptimizedPlanInfo(BaseModel):
    """Metadata for 32-week optimized plan"""
    plan_version: str = "32-week-optimized"
    total_weeks: int = 32
    total_phases: int = 8
    checkpoints_count: int = 9
    capstone_projects: int = 2
    study_intensity: str = "moderate"
    weekly_hours: int = 14  # Recommended: 5h(Mon-Wed) + 4h(Thu-Fri) + 5h(Sat)
    checkpoints: List[int]  # [7, 10, 14, 17, 20, 23, 26, 30, 32]


class PhasedWeekly(BaseModel):
    """Weekly content with phase and checkpoint metadata"""
    week_number: int
    phase: LearningPhase
    is_checkpoint_week: bool
    checkpoint_id: Optional[int] = None
    focus_skills: List[str] = Field(default_factory=list)
    topic: str
    description: str
    learning_outcomes: List[str] = Field(default_factory=list)
    expected_level_after_week: str  # "beginner", "intermediate", "advanced"
    study_guide: Optional[Dict[str, Any]] = None
    resources: List[Dict[str, Any]] = Field(default_factory=list)


class OptimizedGeneratedPlan(BaseModel):
    """Full 32-week optimized plan structure"""
    track_id: int
    track_name: str
    duration_weeks: int = 32
    planning_mode: str = "optimized_32_week"
    current_average_level: str
    final_expected_level: str
    plan_summary: str
    improvement_summary: str
    optimized_plan_info: OptimizedPlanInfo
    weekly_breakdown: List[PhasedWeekly] = Field(default_factory=list)
    phase_summaries: Dict[str, str] = Field(default_factory=dict)  # phase -> summary


# =====================================================
# CHECKPOINT ASSESSMENT TRACKING
# =====================================================

class CheckpointAttempt(BaseModel):
    """Single attempt at a checkpoint assessment"""
    attempt_id: UUID
    checkpoint_id: int
    user_id: UUID
    plan_id: int
    attempt_number: int
    submitted_at: datetime
    score: Optional[float] = Field(None, ge=0.0, le=100.0)
    feedback: Optional[str] = None
    status: CheckpointStatus
    submission_data: Optional[Dict[str, Any]] = None  # Quiz answers, project links, etc.


class CheckpointProgress(BaseModel):
    """Progress tracking for a single checkpoint"""
    checkpoint_id: int
    checkpoint_number: int
    week_number: int
    status: CheckpointStatus
    best_score: Optional[float] = None
    attempts: int = 0
    completed_at: Optional[datetime] = None
    next_review_date: Optional[datetime] = None
    feedback_received: bool = False


class PlanCheckpointProgress(BaseModel):
    """Complete checkpoint progress for a plan"""
    plan_id: int
    user_id: UUID
    total_checkpoints: int
    completed_checkpoints: int
    passed_checkpoints: int
    average_checkpoint_score: Optional[float] = None
    progress_percentage: float  # 0-100
    checkpoints: List[CheckpointProgress] = Field(default_factory=list)
    overall_status: str  # "on_track", "behind", "ahead"


# =====================================================
# CHECKPOINT SUBMISSION & EVALUATION
# =====================================================

class CheckpointSubmission(BaseModel):
    """Submission for checkpoint assessment"""
    checkpoint_id: int
    user_id: UUID
    plan_id: int
    submission_type: AssessmentType
    # For quiz
    quiz_answers: Optional[Dict[int, str]] = None
    # For practical exercise
    code_submission: Optional[str] = None
    exercise_file_url: Optional[str] = None
    # For project submission
    project_url: Optional[str] = None
    project_description: Optional[str] = None
    github_repo_url: Optional[str] = None
    project_demo_url: Optional[str] = None
    # Common
    submitted_at: datetime = Field(default_factory=datetime.now)
    additional_notes: Optional[str] = None


class CheckpointEvaluation(BaseModel):
    """Evaluation of checkpoint submission"""
    attempt_id: UUID
    checkpoint_id: int
    score: float = Field(..., ge=0.0, le=100.0)
    passed: bool
    evaluator_notes: str
    strengths: List[str] = Field(default_factory=list)
    areas_for_improvement: List[str] = Field(default_factory=list)
    recommendations: Optional[str] = None
    next_steps: List[str] = Field(default_factory=list)


class CheckpointSubmissionResponse(BaseModel):
    """Response after submitting checkpoint"""
    status: str = "submitted"
    attempt_id: UUID
    checkpoint_id: int
    message: str
    next_review_date: Optional[datetime] = None


# =====================================================
# CAPSTONE PROJECT SCHEMAS
# =====================================================

class CapstoneProject(BaseModel):
    """Capstone project definition"""
    project_id: int
    project_number: int  # 1 or 2
    phase: LearningPhase  # CAPSTONE_1 or CAPSTONE_2
    weeks: int  # 2 or 2
    title: str
    description: str
    learning_objectives: List[str]
    required_skills: List[int]  # skill_ids
    project_type: str  # "portfolio_piece", "real_world_app", "research_project"
    deliverables: List[str]
    evaluation_criteria: Dict[str, int]  # criterion -> weight %
    github_portfolio_requirements: List[str]
    estimated_hours: int


class CapstoneSubmission(BaseModel):
    """Capstone project submission"""
    submission_id: UUID
    plan_id: int
    user_id: UUID
    project_id: int
    project_number: int
    github_repo_url: str
    project_live_url: Optional[str] = None
    project_description: str
    key_features: List[str]
    technologies_used: List[str]
    challenges_overcome: str
    what_you_learned: str
    submitted_at: datetime = Field(default_factory=datetime.now)
    portfolio_ready: bool = False


class CapstoneEvaluation(BaseModel):
    """Evaluation of capstone project"""
    submission_id: UUID
    project_id: int
    project_number: int
    overall_score: float = Field(..., ge=0.0, le=100.0)
    criteria_scores: Dict[str, float]  # criterion -> score
    passed: bool
    strengths: List[str]
    areas_for_improvement: List[str]
    portfolio_recommendations: List[str]
    feedback: str
    ready_for_portfolio: bool


# =====================================================
# PROGRESS REPORTING
# =====================================================

class SkillProgressSnapshot(BaseModel):
    """Snapshot of skill progress at checkpoint"""
    skill_id: int
    skill_name: str
    week_number: int
    expected_level: str
    estimated_current_level: str
    progress_percentage: float
    confidence: float = Field(..., ge=0.0, le=1.0)


class CheckpointReport(BaseModel):
    """Comprehensive checkpoint report"""
    checkpoint_id: int
    checkpoint_number: int
    week_number: int
    phase: LearningPhase
    completed: bool
    score: Optional[float] = None
    passed: bool
    submitted_at: Optional[datetime] = None
    evaluated_at: Optional[datetime] = None
    skill_snapshots: List[SkillProgressSnapshot] = Field(default_factory=list)
    feedback_summary: Optional[str] = None


class PlanProgressReport(BaseModel):
    """Full progress report for user's plan"""
    plan_id: int
    user_id: UUID
    current_week: int
    total_weeks: int
    progress_percentage: float
    current_phase: LearningPhase
    checkpoint_progress: PlanCheckpointProgress
    recent_checkpoint_reports: List[CheckpointReport] = Field(default_factory=list)
    overall_assessment: str
    recommendations: List[str]
    estimated_completion_date: Optional[datetime] = None


# =====================================================
# SKILL SEQUENCING (CORRECTED)
# =====================================================

class SkillSequenceInfo(BaseModel):
    """Correct skill sequence information for 32-week plan"""
    sequence_number: int
    skill_id: int
    skill_name: str
    start_week: int
    end_week: int
    phase: LearningPhase
    prerequisites: List[int] = Field(default_factory=list)  # skill_ids
    recommended_order: str  # Description of why this order
    is_core_skill: bool


class CurriculumSequence(BaseModel):
    """Complete correct curriculum sequence for track"""
    track_id: int
    track_name: str
    plan_version: str = "32-week-optimized"
    total_skills: int
    skill_sequence: List[SkillSequenceInfo] = Field(default_factory=list)
    # Corrected sequence example:
    # 1. NumPy (Weeks 5-7) - Foundation for data structures
    # 2. Pandas (Weeks 8-10) - Build on NumPy
    # 3. Data Visualization (Weeks 11-14) - Matplotlib, Seaborn
    # 4. Model Evaluation & Metrics (Week 20) - Critical missing skill
    # 5. Advanced ML (Weeks 21-26) - After foundational skills
    # ... etc


# =====================================================
# API RESPONSES
# =====================================================

class CheckpointListResponse(BaseModel):
    """List all checkpoints for a plan"""
    plan_id: int
    total_checkpoints: int
    checkpoints: List[CheckpointProgress]
    phase_breakdown: Dict[str, int]  # phase -> checkpoint count


class SkillSequenceResponse(BaseModel):
    """Skill sequence for a track"""
    track_id: int
    curriculum: CurriculumSequence
    notes: str = "Corrected sequence ensures foundation before advanced topics"
