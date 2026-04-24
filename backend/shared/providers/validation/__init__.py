"""
Shared Validation Module
Provides unified validation framework for entire platform

Usage:
    from shared.providers.validation import GenericValidator, CAREER_BUILDER_CONSTRAINTS
    
    validator = GenericValidator(CAREER_BUILDER_CONSTRAINTS)
    is_valid, warnings = validator.validate_dict({"selected_skills": 15, "available_hours": 8})
    
    # Or use feature-specific constraints
    from shared.providers.validation import FEATURE_VALIDATIONS
    
    for feature_name, config in FEATURE_VALIDATIONS.items():
        validator = GenericValidator(config)
"""

from shared.providers.validation.validation_models import (
    ValidationCaseType,
    ValidationWarning,
    ValidationResult,
    FieldConstraint,
    FeatureValidationConfig,
    COMMON_CONSTRAINTS,
    CAREER_BUILDER_CONSTRAINTS,
    JOB_MATCHING_CONSTRAINTS,
    MARKET_INSIGHTS_CONSTRAINTS,
    AI_PORTFOLIO_CONSTRAINTS,
    MOCK_INTERVIEW_CONSTRAINTS,
    CV_OPTIMIZATION_CONSTRAINTS,
    FEATURE_VALIDATIONS,
)

from shared.providers.validation.generic_edge_case_handler import (
    GenericValidator,
    CareerEdgeCaseValidator,
)

__all__ = [
    # Enums
    "ValidationCaseType",
    
    # Models
    "ValidationWarning",
    "ValidationResult",
    "FieldConstraint",
    "FeatureValidationConfig",
    
    # Common constraints
    "COMMON_CONSTRAINTS",
    
    # Feature-specific constraints
    "CAREER_BUILDER_CONSTRAINTS",
    "JOB_MATCHING_CONSTRAINTS",
    "MARKET_INSIGHTS_CONSTRAINTS",
    "AI_PORTFOLIO_CONSTRAINTS",
    "MOCK_INTERVIEW_CONSTRAINTS",
    "CV_OPTIMIZATION_CONSTRAINTS",
    
    # Registry
    "FEATURE_VALIDATIONS",
    
    # Validators
    "GenericValidator",
    "CareerEdgeCaseValidator",
]
