"""
Shared Metrics Collector - Unified metrics collection for entire platform
Used by: career_builder, job_matching, market_insights, ai_portfolio, mock_interview, cv_optimization

This replaces feature-specific metrics collection with a platform-wide solution.
"""
import logging
from typing import Dict, List, Optional
from dataclasses import asdict
from datetime import datetime
import json

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
)

logger = logging.getLogger(__name__)


class SharedMetricsCollector:
    """
    Unified metrics collection for entire platform.
    
    Replace with: backend/shared/providers/monitoring/metrics_collector.py
    
    Usage:
        from shared.providers.monitoring import SharedMetricsCollector
        
        collector = SharedMetricsCollector()
        collector.record_quality_metric(QualityMetric(...))
        collector.record_error(ErrorMetric(...))
        stats = collector.get_feature_stats(FeatureType.CAREER_BUILDER)
    """
    
    def __init__(self, feature: FeatureType = None):
        """
        Args:
            feature: Default feature for this collector instance.
                    Can be overridden per metric.
        """
        self.logger = logger
        self.default_feature = feature
        self.start_time = datetime.now()
        
        # Metrics storage (in production, use database)
        self.metrics = {
            GenericMetricType.DATA_QUALITY: [],
            GenericMetricType.PERFORMANCE: [],
            GenericMetricType.ACCURACY: [],
            GenericMetricType.COMPLETION: [],
            GenericMetricType.ERROR: [],
            GenericMetricType.USER_BEHAVIOR: [],
            GenericMetricType.SYSTEM_HEALTH: [],
        }
    
    # ========================================================================
    # RECORDING METHODS
    # ========================================================================
    
    def record_quality_metric(self, metric: QualityMetric):
        """Record quality assessment"""
        self.metrics[GenericMetricType.DATA_QUALITY].append(asdict(metric))
        self.logger.info(
            f"Quality metric recorded: {metric.feature} - {metric.entity_id} - "
            f"Score: {metric.quality_score}"
        )
    
    def record_performance_metric(self, metric: PerformanceMetric):
        """Record performance/timing data"""
        self.metrics[GenericMetricType.PERFORMANCE].append(asdict(metric))
        status = "✓ Success" if metric.success else "✗ Failed"
        self.logger.info(
            f"Performance metric recorded: {metric.feature} - {metric.operation} - "
            f"Duration: {metric.duration_ms}ms - {status}"
        )
    
    def record_accuracy_metric(self, metric: AccuracyMetric):
        """Record accuracy/confidence scores"""
        self.metrics[GenericMetricType.ACCURACY].append(asdict(metric))
        self.logger.info(
            f"Accuracy metric recorded: {metric.feature} - {metric.metric_name} - "
            f"Score: {metric.score:.1f}"
        )
    
    def record_completion_metric(self, metric: CompletionMetric):
        """Record completion/coverage statistics"""
        self.metrics[GenericMetricType.COMPLETION].append(asdict(metric))
        self.logger.info(
            f"Completion metric recorded: {metric.feature} - "
            f"{metric.completed_count}/{metric.target_count} ({metric.completion_percentage:.1f}%)"
        )
    
    def record_user_behavior(self, metric: UserBehaviorMetric):
        """Record user action"""
        self.metrics[GenericMetricType.USER_BEHAVIOR].append(asdict(metric))
        self.logger.info(
            f"User behavior recorded: {metric.feature} - {metric.user_id} - {metric.action}"
        )
    
    def record_system_health(self, metric: SystemHealthMetric):
        """Record system health snapshot"""
        self.metrics[GenericMetricType.SYSTEM_HEALTH].append(asdict(metric))
        self.logger.info(
            f"System health recorded: {metric.feature} - "
            f"Response: {metric.response_time_ms}ms, "
            f"Memory: {metric.memory_usage_mb}MB, "
            f"Errors: {metric.error_count}"
        )
    
    def record_error(self, metric: ErrorMetric):
        """Record error occurrence"""
        self.metrics[GenericMetricType.ERROR].append(asdict(metric))
        self.logger.error(
            f"Error recorded: {metric.feature} - {metric.error_type} - "
            f"Severity: {metric.severity} - {metric.message}"
        )
    
    # ========================================================================
    # STATISTICS METHODS
    # ========================================================================
    
    def get_feature_stats(self, feature: FeatureType) -> FeatureMetricsSummary:
        """Get statistics for a specific feature"""
        
        perf_metrics = [
            m for m in self.metrics[GenericMetricType.PERFORMANCE]
            if m.get("feature") == feature.value
        ]
        quality_metrics = [
            m for m in self.metrics[GenericMetricType.DATA_QUALITY]
            if m.get("feature") == feature.value
        ]
        error_metrics = [
            m for m in self.metrics[GenericMetricType.ERROR]
            if m.get("feature") == feature.value
        ]
        
        if not perf_metrics:
            return FeatureMetricsSummary(
                feature=feature,
                total_operations=0,
                successful_operations=0,
                success_rate=0,
                average_duration_ms=0,
                average_quality_score=0,
                error_count=0,
                critical_error_count=0,
            )
        
        successful = sum(1 for m in perf_metrics if m.get("success", False))
        durations = [m.get("duration_ms", 0) for m in perf_metrics]
        quality_scores = [m.get("quality_score", 0) for m in quality_metrics]
        critical_errors = sum(
            1 for m in error_metrics
            if m.get("severity") == "critical"
        )
        
        return FeatureMetricsSummary(
            feature=feature,
            total_operations=len(perf_metrics),
            successful_operations=successful,
            success_rate=(successful / len(perf_metrics) * 100) if perf_metrics else 0,
            average_duration_ms=sum(durations) / len(durations) if durations else 0,
            average_quality_score=sum(quality_scores) / len(quality_scores) if quality_scores else 0,
            error_count=len(error_metrics),
            critical_error_count=critical_errors,
        )
    
    def get_platform_health(self) -> PlatformHealthSnapshot:
        """Get overall platform health"""
        
        features_summary = {}
        total_errors = 0
        total_critical = 0
        total_operations = 0
        successful_operations = 0
        
        for feature in FeatureType:
            stats = self.get_feature_stats(feature)
            if stats.total_operations > 0:
                features_summary[feature] = stats
                total_errors += stats.error_count
                total_critical += stats.critical_error_count
                total_operations += stats.total_operations
                successful_operations += stats.successful_operations
        
        overall_success_rate = (
            (successful_operations / total_operations * 100)
            if total_operations > 0 else 0
        )
        
        # Determine overall status
        if total_critical > 0:
            status = "critical"
        elif total_errors > (total_operations * 0.1):  # >10% error rate
            status = "warning"
        else:
            status = "healthy"
        
        return PlatformHealthSnapshot(
            timestamp=datetime.now(),
            features_summary=features_summary,
            total_error_count=total_errors,
            total_critical_errors=total_critical,
            overall_success_rate=overall_success_rate,
            system_status=status,
        )
    
    # ========================================================================
    # ANALYSIS METHODS
    # ========================================================================
    
    def detect_anomalies(self) -> List[Dict]:
        """Detect unusual patterns"""
        anomalies = []
        
        # Check 1: High error rate
        health = self.get_platform_health()
        if health.total_error_count > 0:
            anomalies.append({
                "type": "high_error_rate",
                "severity": "warning",
                "errors": health.total_error_count,
                "message": f"Detected {health.total_error_count} errors in platform"
            })
        
        # Check 2: Critical errors
        if health.total_critical_errors > 0:
            anomalies.append({
                "type": "critical_errors",
                "severity": "critical",
                "count": health.total_critical_errors,
                "message": f"Detected {health.total_critical_errors} critical errors"
            })
        
        # Check 3: Per-feature anomalies
        for feature, stats in health.features_summary.items():
            if stats.success_rate < 50:
                anomalies.append({
                    "type": "low_success_rate",
                    "feature": feature.value,
                    "severity": "warning",
                    "rate": stats.success_rate,
                    "message": f"{feature.value} has {stats.success_rate:.1f}% success rate"
                })
            
            if stats.average_duration_ms > 5000:  # >5 seconds
                anomalies.append({
                    "type": "slow_operation",
                    "feature": feature.value,
                    "severity": "info",
                    "duration": stats.average_duration_ms,
                    "message": f"{feature.value} operations taking {stats.average_duration_ms:.0f}ms"
                })
        
        return anomalies
    
    # ========================================================================
    # REPORTING METHODS
    # ========================================================================
    
    def generate_daily_report(self) -> Dict:
        """Generate daily metrics report"""
        health = self.get_platform_health()
        anomalies = self.detect_anomalies()
        
        return {
            "report_type": "daily",
            "generated_at": datetime.now().isoformat(),
            "uptime": str(datetime.now() - self.start_time),
            "platform_health": asdict(health),
            "anomalies": anomalies,
            "features_summary": {
                f.value: asdict(s)
                for f, s in health.features_summary.items()
            },
            "total_metrics_collected": sum(
                len(metrics) for metrics in self.metrics.values()
            ),
        }
    
    def get_feature_insights(self, feature: FeatureType) -> Dict:
        """Get detailed insights for a specific feature"""
        stats = self.get_feature_stats(feature)
        
        perf_metrics = [
            m for m in self.metrics[GenericMetricType.PERFORMANCE]
            if m.get("feature") == feature.value
        ]
        
        quality_metrics = [
            m for m in self.metrics[GenericMetricType.DATA_QUALITY]
            if m.get("feature") == feature.value
        ]
        
        error_metrics = [
            m for m in self.metrics[GenericMetricType.ERROR]
            if m.get("feature") == feature.value
        ]
        
        return {
            "feature": feature.value,
            "summary": asdict(stats),
            "slowest_operations": sorted(
                perf_metrics,
                key=lambda x: x.get("duration_ms", 0),
                reverse=True
            )[:5],
            "lowest_quality_items": sorted(
                quality_metrics,
                key=lambda x: x.get("quality_score", 100)
            )[:5],
            "recent_errors": error_metrics[-10:],
            "recommendations": self._generate_recommendations(stats, error_metrics),
        }
    
    def export_metrics_json(self, filename: str) -> str:
        """Export all metrics to JSON"""
        report = {
            "exported_at": datetime.now().isoformat(),
            "platform_health": asdict(self.get_platform_health()),
            "raw_metrics": {
                k.value: v for k, v in self.metrics.items()
            }
        }
        
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        self.logger.info(f"Metrics exported to {filename}")
        return filename
    
    # ========================================================================
    # HELPER METHODS
    # ========================================================================
    
    def _generate_recommendations(self, stats: FeatureMetricsSummary, errors: List) -> List[str]:
        """Generate actionable recommendations"""
        recommendations = []
        
        if stats.success_rate < 90:
            recommendations.append(f"Investigate failures - success rate is {stats.success_rate:.1f}%")
        
        if stats.average_duration_ms > 1000:
            recommendations.append(f"Optimize performance - average duration is {stats.average_duration_ms:.0f}ms")
        
        if stats.average_quality_score < 70:
            recommendations.append(f"Improve data quality - average score is {stats.average_quality_score:.1f}")
        
        if len(errors) > 10:
            recommendations.append(f"High error count ({len(errors)}). Review and apply fixes.")
        
        return recommendations
    
    def reset_metrics(self):
        """Reset all collected metrics (for testing)"""
        for metric_type in self.metrics:
            self.metrics[metric_type] = []
        self.logger.info("All metrics reset")


# ============================================================================
# BACKWARD COMPATIBILITY (For career_builder migration)
# ============================================================================

class CareerMetricsCollector(SharedMetricsCollector):
    """
    Backward-compatible wrapper for career_builder.
    Gradually migrate to SharedMetricsCollector.
    """
    
    def __init__(self):
        super().__init__(feature=FeatureType.CAREER_BUILDER)
    
    def record_cv_quality(self, cv_id: str, quality_score: float, quality_level: str, issues_found: int):
        """Legacy method - maps to new approach"""
        metric = QualityMetric(
            timestamp=datetime.now(),
            feature=FeatureType.CAREER_BUILDER,
            entity_id=cv_id,
            quality_score=quality_score,
            quality_level=quality_level,
            issues_count=issues_found,
            issue_types={}
        )
        self.record_quality_metric(metric)


# ============================================================================
# EXPORTS
# ============================================================================

__all__ = [
    "SharedMetricsCollector",
    "CareerMetricsCollector",
    "GenericMetricType",
    "FeatureType",
]
