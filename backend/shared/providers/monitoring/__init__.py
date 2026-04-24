"""
Shared Monitoring Module
Provides unified metrics collection for entire platform

Usage:
    from shared.providers.monitoring import SharedMetricsCollector, FeatureType, QualityMetric
    
    collector = SharedMetricsCollector()
    collector.record_quality_metric(QualityMetric(...))
    health = collector.get_platform_health()
"""

from shared.providers.monitoring.metrics_models import (
    GenericMetricType,
    FeatureType,
    QualityMetric,
    PerformanceMetric,
    AccuracyMetric,
    CompletionMetric,
    UserBehaviorMetric,
    SystemHealthMetric,
    ErrorMetric,
    FeatureMetricsSummary,
    PlatformHealthSnapshot,
    FeatureConstraints,
)

from shared.providers.monitoring.metrics_collector import (
    SharedMetricsCollector,
    CareerMetricsCollector,
)

__all__ = [
    # Enums
    "GenericMetricType",
    "FeatureType",
    
    # Models
    "QualityMetric",
    "PerformanceMetric",
    "AccuracyMetric",
    "CompletionMetric",
    "UserBehaviorMetric",
    "SystemHealthMetric",
    "ErrorMetric",
    "FeatureMetricsSummary",
    "PlatformHealthSnapshot",
    "FeatureConstraints",
    
    # Collectors
    "SharedMetricsCollector",
    "CareerMetricsCollector",
]
