"""
Shared Monitoring Metrics - Generic metrics collection for all features
Used by: career_builder, job_matching, market_insights, ai_portfolio, mock_interview, cv_optimization
"""

from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Any
from enum import Enum


# ============================================================================
# GENERIC METRIC TYPES (Feature-agnostic)
# ============================================================================

class GenericMetricType(str, Enum):
    """Common metrics across all features"""
    DATA_QUALITY = "data_quality"
    PERFORMANCE = "performance"
    ACCURACY = "accuracy"
    COMPLETION = "completion"
    ERROR = "error"
    USER_BEHAVIOR = "user_behavior"
    SYSTEM_HEALTH = "system_health"


class FeatureType(str, Enum):
    """All available features in platform"""
    CAREER_BUILDER = "career_builder"
    JOB_MATCHING = "job_matching"
    MARKET_INSIGHTS = "market_insights"
    AI_PORTFOLIO = "ai_portfolio"
    MOCK_INTERVIEW = "mock_interview"
    CV_OPTIMIZATION = "cv_optimization"


# ============================================================================
# GENERIC DATACLASSES (Reusable across features)
# ============================================================================

@dataclass
class QualityMetric:
    """Generic quality assessment metric"""
    timestamp: datetime
    feature: FeatureType
    entity_id: str  # cv_id, job_id, etc.
    quality_score: float  # 0-100
    quality_level: str  # excellent, good, fair, poor
    issues_count: int
    issue_types: Dict[str, int]  # issue_type: count


@dataclass
class PerformanceMetric:
    """Generic performance metric"""
    timestamp: datetime
    feature: FeatureType
    operation: str  # analyze, generate, match, etc.
    duration_ms: float
    success: bool
    error_message: Optional[str] = None


@dataclass
class AccuracyMetric:
    """Generic accuracy/confidence metric"""
    timestamp: datetime
    feature: FeatureType
    entity_id: str
    metric_name: str  # extraction_accuracy, match_score, etc.
    score: float  # 0-100
    confidence: float  # 0-1
    breakdown: Dict[str, float] = None


@dataclass
class CompletionMetric:
    """Generic completion/coverage metric"""
    timestamp: datetime
    feature: FeatureType
    entity_id: str
    target_count: int  # expected items
    completed_count: int
    completion_percentage: float
    missing_items: Dict[str, int] = None


@dataclass
class UserBehaviorMetric:
    """Track user actions and patterns"""
    timestamp: datetime
    feature: FeatureType
    user_id: str
    action: str  # analyze, generate, confirm, etc.
    action_data: Dict[str, Any]
    duration_seconds: Optional[float] = None


@dataclass
class SystemHealthMetric:
    """System-wide health indicators"""
    timestamp: datetime
    feature: FeatureType
    response_time_ms: float
    memory_usage_mb: float
    db_connections: int
    cache_hit_rate: float
    error_count: int


@dataclass
class ErrorMetric:
    """Generic error tracking"""
    timestamp: datetime
    feature: FeatureType
    error_type: str
    severity: str  # info, warning, error, critical
    message: str
    context: Dict[str, Any]
    user_id: Optional[str] = None
    stacktrace: Optional[str] = None


# ============================================================================
# FEATURE-SPECIFIC METRIC TYPES (Optional extensions)
# ============================================================================

@dataclass
class CareerMetric:
    """Career builder specific metrics (extends generic)"""
    base_metric: QualityMetric
    cv_quality: float
    skill_count: int
    experience_count: int


@dataclass
class JobMatchingMetric:
    """Job matching specific metrics (extends generic)"""
    base_metric: AccuracyMetric
    match_score: float
    job_id: str
    candidate_id: str
    match_factors: Dict[str, float]


@dataclass
class MarketInsightMetric:
    """Market insights specific metrics (extends generic)"""
    base_metric: DataQualityMetric
    data_source: str
    data_freshness_hours: int
    coverage_percentage: float


# ============================================================================
# AGGREGATION MODELS (For reports)
# ============================================================================

@dataclass
class FeatureMetricsSummary:
    """Summary statistics for a feature"""
    feature: FeatureType
    total_operations: int
    successful_operations: int
    success_rate: float
    average_duration_ms: float
    average_quality_score: float
    error_count: int
    critical_error_count: int


@dataclass
class PlatformHealthSnapshot:
    """Overall platform health at a point in time"""
    timestamp: datetime
    features_summary: Dict[FeatureType, FeatureMetricsSummary]
    total_error_count: int
    total_critical_errors: int
    overall_success_rate: float
    system_status: str  # healthy, warning, critical


# ============================================================================
# CONSTRAINT VALIDATORS (For feature-specific validation)
# ============================================================================

@dataclass
class FeatureConstraints:
    """Configurable constraints per feature"""
    feature: FeatureType
    
    # Generic constraints
    min_items: int = 1
    max_items: int = 100
    min_duration_ms: float = 100
    max_duration_ms: float = 60000  # 60 seconds
    
    # Feature-specific (override in subclass)
    custom_constraints: Dict[str, Any] = None
    
    def validate(self, metric_name: str, value: float) -> tuple:
        """Generic validation logic"""
        if metric_name == "duration":
            if value < self.min_duration_ms:
                return False, f"Duration too short: {value}ms (min: {self.min_duration_ms}ms)"
            if value > self.max_duration_ms:
                return False, f"Duration too long: {value}ms (max: {self.max_duration_ms}ms)"
        return True, None


# ============================================================================
# OPTIONAL: Import this in features
# ============================================================================

__all__ = [
    "GenericMetricType",
    "FeatureType",
    "QualityMetric",
    "PerformanceMetric",
    "AccuracyMetric",
    "CompletionMetric",
    "UserBehaviorMetric",
    "SystemHealthMetric",
    "ErrorMetric",
    "CareerMetric",
    "JobMatchingMetric",
    "MarketInsightMetric",
    "FeatureMetricsSummary",
    "PlatformHealthSnapshot",
    "FeatureConstraints",
]
