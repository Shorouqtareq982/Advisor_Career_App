"""
Shared Validation Models - Generic validation for all features
Used by: career_builder, job_matching, market_insights, ai_portfolio, mock_interview, cv_optimization
"""

from dataclasses import dataclass
from typing import Dict, Optional, Any, List
from enum import Enum


class ValidationCaseType(str, Enum):
    """Generic validation case types"""
    MISSING_DATA = "missing_data"
    INVALID_RANGE = "invalid_range"
    INVALID_FORMAT = "invalid_format"
    INSUFFICIENT_COUNT = "insufficient_count"
    EXCESSIVE_COUNT = "excessive_count"
    CONFLICTING_DATA = "conflicting_data"
    EXTREME_VALUE = "extreme_value"
    TIMEOUT = "timeout"
    RESOURCE_LIMIT = "resource_limit"


@dataclass
class ValidationWarning:
    """Generic validation warning/error"""
    case_type: ValidationCaseType
    severity: str  # "info", "warning", "error", "critical"
    message: str
    recommended_action: str
    allow_proceed: bool
    field_name: Optional[str] = None
    current_value: Optional[Any] = None
    valid_range: Optional[Dict[str, Any]] = None


@dataclass
class ValidationResult:
    """Result of validation check"""
    is_valid: bool
    warnings: List[ValidationWarning]
    corrected_value: Optional[Any] = None
    error_message: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


@dataclass
class FieldConstraint:
    """Single field constraint definition"""
    field_name: str
    field_type: str  # "int", "float", "str", "bool", "list", "dict"
    required: bool = True
    minimum: Optional[float] = None
    maximum: Optional[float] = None
    default_value: Optional[Any] = None
    description: str = ""
    validation_rule: Optional[callable] = None


@dataclass
class FeatureValidationConfig:
    """Configuration for feature-specific validations"""
    feature_name: str
    constraints: Dict[str, FieldConstraint]
    allow_auto_correction: bool = True
    allow_partial_data: bool = False
    max_warnings_allowed: int = 10
    fail_on_critical: bool = True


# ============================================================================
# COMMON CONSTRAINT DEFINITIONS (Reusable across features)
# ============================================================================

COMMON_CONSTRAINTS = {
    "item_count": FieldConstraint(
        field_name="item_count",
        field_type="int",
        minimum=1,
        maximum=500,
        description="Number of items to process"
    ),
    
    "availability_hours": FieldConstraint(
        field_name="availability_hours",
        field_type="float",
        minimum=0.5,
        maximum=80.0,
        description="Available hours per week"
    ),
    
    "duration_days": FieldConstraint(
        field_name="duration_days",
        field_type="int",
        minimum=1,
        maximum=730,  # 2 years
        description="Duration in days"
    ),
    
    "confidence_score": FieldConstraint(
        field_name="confidence_score",
        field_type="float",
        minimum=0.0,
        maximum=1.0,
        description="Confidence score (0-1)"
    ),
    
    "quality_score": FieldConstraint(
        field_name="quality_score",
        field_type="float",
        minimum=0.0,
        maximum=100.0,
        description="Quality score (0-100)"
    ),
    
    "importance_weight": FieldConstraint(
        field_name="importance_weight",
        field_type="int",
        minimum=1,
        maximum=5,
        description="Importance weight (1-5)"
    ),
    
    "percentage": FieldConstraint(
        field_name="percentage",
        field_type="float",
        minimum=0.0,
        maximum=100.0,
        description="Percentage value (0-100)"
    ),
}


# ============================================================================
# FEATURE-SPECIFIC CONSTRAINT PRESETS
# ============================================================================

CAREER_BUILDER_CONSTRAINTS = FeatureValidationConfig(
    feature_name="career_builder",
    constraints={
        "selected_skills": FieldConstraint(
            field_name="selected_skills",
            field_type="list",
            minimum=1,
            maximum=20,
            description="Selected skills count"
        ),
        "available_hours": COMMON_CONSTRAINTS["availability_hours"],
        "requested_duration": FieldConstraint(
            field_name="requested_duration",
            field_type="int",
            minimum=1,
            maximum=104,  # 2 years
            description="Requested duration in weeks"
        ),
    }
)

JOB_MATCHING_CONSTRAINTS = FeatureValidationConfig(
    feature_name="job_matching",
    constraints={
        "job_ids": FieldConstraint(
            field_name="job_ids",
            field_type="list",
            minimum=1,
            maximum=100,
            description="Number of jobs to match"
        ),
        "skill_importance": COMMON_CONSTRAINTS["importance_weight"],
        "match_threshold": COMMON_CONSTRAINTS["percentage"],
    }
)

MARKET_INSIGHTS_CONSTRAINTS = FeatureValidationConfig(
    feature_name="market_insights",
    constraints={
        "data_freshness_hours": FieldConstraint(
            field_name="data_freshness_hours",
            field_type="int",
            minimum=1,
            maximum=8760,  # 1 year
            description="How fresh the data should be"
        ),
        "sample_size": FieldConstraint(
            field_name="sample_size",
            field_type="int",
            minimum=10,
            maximum=100000,
            description="Number of data points to analyze"
        ),
    }
)

AI_PORTFOLIO_CONSTRAINTS = FeatureValidationConfig(
    feature_name="ai_portfolio",
    constraints={
        "projects_count": FieldConstraint(
            field_name="projects_count",
            field_type="int",
            minimum=0,
            maximum=50,
            description="Number of projects"
        ),
        "bio_length": FieldConstraint(
            field_name="bio_length",
            field_type="int",
            minimum=10,
            maximum=1000,
            description="Bio character length"
        ),
    }
)

MOCK_INTERVIEW_CONSTRAINTS = FeatureValidationConfig(
    feature_name="mock_interview",
    constraints={
        "duration_minutes": FieldConstraint(
            field_name="duration_minutes",
            field_type="int",
            minimum=15,
            maximum=120,
            description="Interview duration in minutes"
        ),
        "difficulty_level": FieldConstraint(
            field_name="difficulty_level",
            field_type="str",
            description="Difficulty: beginner, intermediate, advanced"
        ),
    }
)

CV_OPTIMIZATION_CONSTRAINTS = FeatureValidationConfig(
    feature_name="cv_optimization",
    constraints={
        "cv_length_words": FieldConstraint(
            field_name="cv_length_words",
            field_type="int",
            minimum=100,
            maximum=2000,
            description="CV length in words"
        ),
        "optimization_level": FieldConstraint(
            field_name="optimization_level",
            field_type="str",
            description="Optimization level: basic, advanced, premium"
        ),
    }
)

# Registry of all feature configs
FEATURE_VALIDATIONS = {
    "career_builder": CAREER_BUILDER_CONSTRAINTS,
    "job_matching": JOB_MATCHING_CONSTRAINTS,
    "market_insights": MARKET_INSIGHTS_CONSTRAINTS,
    "ai_portfolio": AI_PORTFOLIO_CONSTRAINTS,
    "mock_interview": MOCK_INTERVIEW_CONSTRAINTS,
    "cv_optimization": CV_OPTIMIZATION_CONSTRAINTS,
}


__all__ = [
    "ValidationCaseType",
    "ValidationWarning",
    "ValidationResult",
    "FieldConstraint",
    "FeatureValidationConfig",
    "COMMON_CONSTRAINTS",
    "CAREER_BUILDER_CONSTRAINTS",
    "JOB_MATCHING_CONSTRAINTS",
    "MARKET_INSIGHTS_CONSTRAINTS",
    "AI_PORTFOLIO_CONSTRAINTS",
    "MOCK_INTERVIEW_CONSTRAINTS",
    "CV_OPTIMIZATION_CONSTRAINTS",
    "FEATURE_VALIDATIONS",
]
