"""
Market Insights Feature
- Job market crawling and analysis
- Career trend analysis
- Salary insights
"""

from .services import MarketInsightsService
from .repositories import MarketInsightsRepository
from .schemas import JobData, CrawlerState, JobStatus, GlobalStatus, MarketInsights

__all__ = [
    "MarketInsightsService",
    "MarketInsightsRepository",
    "JobData",
    "CrawlerState",
    "JobStatus",
    "GlobalStatus",
    "MarketInsights"
]
