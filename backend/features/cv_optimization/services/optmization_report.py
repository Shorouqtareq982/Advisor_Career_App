from typing import Dict, Optional

from features.cv_optimization.repositories.cv_optmization_repo import CVOptRepository


class OptmizationReportService:
    """Service layer for handling CV optimization reports."""
    def __init__(self, repo: CVOptRepository = None):
        self.repo = repo or CVOptRepository()
    
    def get_report_by_id(self, report_id: str) -> Optional[Dict]:
        """Fetch an optimization report by its ID."""
        return self.repo.get_optimization_report_by_id(report_id)
    
    def get_reports_by_user(self, user_id: str) -> list[Dict]:
        """Fetch all optimization reports for a given user."""
        return self.repo.get_optmization_reports_by_user(user_id)
    
    def delete_report(self, report_id: str):
        """Delete an optimization report by its ID."""
        return self.repo.delete_optimization_report(report_id)
    
def get_optimization_report_service() -> OptmizationReportService:
    """Dependency function to get an instance of OptmizationReportService."""
    return OptmizationReportService()