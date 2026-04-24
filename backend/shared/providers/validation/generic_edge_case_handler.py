"""
Shared Generic Edge Case Handler - Reusable validation for all features
Used by: career_builder, job_matching, market_insights, ai_portfolio, mock_interview, cv_optimization

Replaces feature-specific edge case handlers with a unified, configurable solution.
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import asdict

from shared.providers.validation.validation_models import (
    ValidationCaseType,
    ValidationWarning,
    ValidationResult,
    FieldConstraint,
    FeatureValidationConfig,
    FEATURE_VALIDATIONS,
)

logger = logging.getLogger(__name__)


class GenericValidator:
    """
    Generic validator that works with any feature's validation config.
    
    Usage:
        from shared.providers.validation import GenericValidator, CAREER_BUILDER_CONSTRAINTS
        
        validator = GenericValidator(CAREER_BUILDER_CONSTRAINTS)
        result = validator.validate_field("selected_skills", 25)
        
        if not result.is_valid:
            for warning in result.warnings:
                print(warning.message)
    """
    
    def __init__(self, config: FeatureValidationConfig):
        """
        Args:
            config: Feature validation configuration
        """
        self.logger = logger
        self.config = config
        self.warnings = []
    
    # ========================================================================
    # SINGLE FIELD VALIDATION
    # ========================================================================
    
    def validate_field(
        self,
        field_name: str,
        value: Any,
        auto_correct: Optional[bool] = None
    ) -> ValidationResult:
        """
        Validate single field against constraints
        
        Args:
            field_name: Name of field to validate
            value: Value to validate
            auto_correct: Auto-correct if possible (uses config default if None)
        
        Returns:
            ValidationResult with validation status and corrections
        """
        auto_correct = auto_correct if auto_correct is not None else self.config.allow_auto_correction
        
        if field_name not in self.config.constraints:
            return ValidationResult(
                is_valid=False,
                warnings=[],
                error_message=f"Unknown field: {field_name}"
            )
        
        constraint = self.config.constraints[field_name]
        
        # Type validation
        type_valid, type_msg = self._validate_type(constraint, value)
        if not type_valid:
            if auto_correct:
                corrected = self._auto_correct_type(constraint, value)
                if corrected is not None:
                    value = corrected
                else:
                    return ValidationResult(
                        is_valid=False,
                        warnings=[],
                        error_message=type_msg
                    )
            else:
                return ValidationResult(
                    is_valid=False,
                    warnings=[],
                    error_message=type_msg
                )
        
        # Range validation
        range_valid, range_msg, corrected = self._validate_range(constraint, value, auto_correct)
        if not range_valid:
            warning = ValidationWarning(
                case_type=ValidationCaseType.INVALID_RANGE,
                severity="error",
                message=range_msg,
                recommended_action=f"Correct {field_name} to valid range",
                allow_proceed=False,
                field_name=field_name,
                current_value=value,
                valid_range={
                    "min": constraint.minimum,
                    "max": constraint.maximum
                }
            )
            return ValidationResult(
                is_valid=False,
                warnings=[warning],
                error_message=range_msg
            )
        
        if corrected != value:
            value = corrected
        
        # Custom validation rule
        if constraint.validation_rule:
            custom_valid, custom_msg = constraint.validation_rule(value)
            if not custom_valid:
                return ValidationResult(
                    is_valid=False,
                    warnings=[],
                    error_message=custom_msg
                )
        
        self.logger.info(f"Field {field_name} validated successfully: {value}")
        
        return ValidationResult(
            is_valid=True,
            warnings=[],
            corrected_value=value,
            metadata={"constraint": asdict(constraint)}
        )
    
    def validate_dict(
        self,
        data: Dict[str, Any],
        auto_correct: Optional[bool] = None
    ) -> Tuple[bool, List[ValidationWarning], Dict[str, Any]]:
        """
        Validate entire dictionary against constraints
        
        Args:
            data: Dictionary to validate
            auto_correct: Auto-correct if possible
        
        Returns:
            (is_valid, warnings_list, corrected_data)
        """
        self.warnings = []
        corrected_data = data.copy()
        
        for field_name, constraint in self.config.constraints.items():
            if field_name not in data:
                if constraint.required:
                    self.warnings.append(ValidationWarning(
                        case_type=ValidationCaseType.MISSING_DATA,
                        severity="error",
                        message=f"Required field missing: {field_name}",
                        recommended_action=f"Provide {field_name}",
                        allow_proceed=False,
                        field_name=field_name
                    ))
                elif constraint.default_value is not None:
                    corrected_data[field_name] = constraint.default_value
                    self.warnings.append(ValidationWarning(
                        case_type=ValidationCaseType.MISSING_DATA,
                        severity="info",
                        message=f"Missing {field_name}, using default",
                        recommended_action="",
                        allow_proceed=True,
                        field_name=field_name
                    ))
                continue
            
            result = self.validate_field(field_name, data[field_name], auto_correct)
            if not result.is_valid:
                self.warnings.extend(result.warnings)
                if result.error_message and not auto_correct:
                    self.warnings.append(ValidationWarning(
                        case_type=ValidationCaseType.INVALID_FORMAT,
                        severity="error",
                        message=result.error_message,
                        recommended_action=f"Fix {field_name}",
                        allow_proceed=False,
                        field_name=field_name
                    ))
            else:
                corrected_data[field_name] = result.corrected_value or data[field_name]
        
        # Check total warning count
        critical_warnings = [w for w in self.warnings if w.severity == "error" and not w.allow_proceed]
        can_proceed = len(critical_warnings) == 0
        
        return can_proceed, self.warnings, corrected_data
    
    # ========================================================================
    # EDGE CASE DETECTION
    # ========================================================================
    
    def detect_edge_cases(
        self,
        data: Dict[str, Any]
    ) -> List[ValidationWarning]:
        """
        Detect common edge cases
        
        Args:
            data: Data to analyze for edge cases
        
        Returns:
            List of detected edge cases
        """
        edge_cases = []
        
        # Check 1: Empty/minimal data
        if not data or len(data) == 0:
            edge_cases.append(ValidationWarning(
                case_type=ValidationCaseType.MISSING_DATA,
                severity="error",
                message="No data provided",
                recommended_action="Provide required data",
                allow_proceed=False
            ))
        
        # Check 2: Count-based edge cases
        for field_name, value in data.items():
            if field_name not in self.config.constraints:
                continue
            
            constraint = self.config.constraints[field_name]
            
            # Check for insufficient count
            if isinstance(value, list):
                if constraint.minimum and len(value) < constraint.minimum:
                    edge_cases.append(ValidationWarning(
                        case_type=ValidationCaseType.INSUFFICIENT_COUNT,
                        severity="warning",
                        message=f"Too few {field_name}: {len(value)} (minimum: {constraint.minimum})",
                        recommended_action=f"Increase {field_name} or adjust expectations",
                        allow_proceed=True,
                        field_name=field_name,
                        current_value=len(value)
                    ))
                
                # Check for excessive count
                if constraint.maximum and len(value) > constraint.maximum:
                    edge_cases.append(ValidationWarning(
                        case_type=ValidationCaseType.EXCESSIVE_COUNT,
                        severity="warning",
                        message=f"Too many {field_name}: {len(value)} (maximum: {constraint.maximum})",
                        recommended_action=f"Reduce {field_name} or split into batches",
                        allow_proceed=True,
                        field_name=field_name,
                        current_value=len(value)
                    ))
        
        return edge_cases
    
    # ========================================================================
    # HELPER METHODS
    # ========================================================================
    
    def _validate_type(self, constraint: FieldConstraint, value: Any) -> Tuple[bool, str]:
        """Validate value type"""
        expected_type = constraint.field_type
        
        if expected_type == "int":
            is_valid = isinstance(value, int) or (isinstance(value, str) and value.isdigit())
        elif expected_type == "float":
            is_valid = isinstance(value, (int, float))
        elif expected_type == "str":
            is_valid = isinstance(value, str)
        elif expected_type == "bool":
            is_valid = isinstance(value, bool)
        elif expected_type == "list":
            is_valid = isinstance(value, list)
        elif expected_type == "dict":
            is_valid = isinstance(value, dict)
        else:
            is_valid = True  # Unknown type, skip check
        
        error_msg = "" if is_valid else f"Invalid type for {constraint.field_name}: expected {expected_type}, got {type(value).__name__}"
        return is_valid, error_msg
    
    def _auto_correct_type(self, constraint: FieldConstraint, value: Any) -> Optional[Any]:
        """Auto-correct type if possible"""
        try:
            if constraint.field_type == "int":
                return int(value)
            elif constraint.field_type == "float":
                return float(value)
            elif constraint.field_type == "str":
                return str(value)
            elif constraint.field_type == "bool":
                if isinstance(value, str):
                    return value.lower() in ["true", "yes", "1"]
                return bool(value)
        except (ValueError, TypeError):
            pass
        
        return None
    
    def _validate_range(
        self,
        constraint: FieldConstraint,
        value: Any,
        auto_correct: bool = False
    ) -> Tuple[bool, str, Any]:
        """Validate value range"""
        
        corrected = value
        
        # For lists, check length
        if isinstance(value, list):
            length = len(value)
            if constraint.minimum and length < constraint.minimum:
                return False, f"List too short: {length} < {constraint.minimum}", value
            if constraint.maximum and length > constraint.maximum:
                if auto_correct:
                    corrected = value[:constraint.maximum]
                    return True, "", corrected
                return False, f"List too long: {length} > {constraint.maximum}", value
        
        # For numbers, check value range
        elif isinstance(value, (int, float)):
            if constraint.minimum and value < constraint.minimum:
                if auto_correct:
                    corrected = constraint.minimum
                    return True, "", corrected
                return False, f"Value too low: {value} < {constraint.minimum}", value
            if constraint.maximum and value > constraint.maximum:
                if auto_correct:
                    corrected = constraint.maximum
                    return True, "", corrected
                return False, f"Value too high: {value} > {constraint.maximum}", value
        
        return True, "", corrected
    
    def get_summary(self) -> Dict:
        """Get summary of validation state"""
        error_count = sum(1 for w in self.warnings if w.severity == "error")
        warning_count = sum(1 for w in self.warnings if w.severity == "warning")
        
        return {
            "total_warnings": len(self.warnings),
            "errors": error_count,
            "warnings": warning_count,
            "can_proceed": error_count == 0,
            "config": self.config.feature_name,
        }


# ============================================================================
# BACKWARD COMPATIBILITY (For career_builder migration)
# ============================================================================

class CareerEdgeCaseValidator(GenericValidator):
    """Backward-compatible wrapper for career_builder"""
    
    def __init__(self):
        super().__init__(FEATURE_VALIDATIONS["career_builder"])
    
    async def validate_time_guidance_request(
        self,
        selected_skills: List[str],
        owned_skills: Dict,
        available_hours: float,
        requested_weeks: Optional[int] = None
    ) -> Tuple[bool, List[ValidationWarning]]:
        """Legacy method - maps to new approach"""
        
        data = {
            "selected_skills": selected_skills,
            "available_hours": available_hours,
            "requested_duration": requested_weeks or 8,
        }
        
        is_valid, warnings, _ = self.validate_dict(data, auto_correct=True)
        edge_cases = self.detect_edge_cases(data)
        
        return is_valid, warnings + edge_cases


# ============================================================================
# EXPORTS
# ============================================================================

__all__ = [
    "GenericValidator",
    "CareerEdgeCaseValidator",
]
