import time
from typing import Dict, Any


class GenerationMetricsTracker:
    def __init__(self):
        self.start_time = time.time()
        self.total_weeks = 0
        self.contract_passed_weeks = 0
        self.fallback_weeks = 0
        self.total_resources = 0
        self.duplicate_urls_removed = 0
        self.llm_fallback_used = False
        self.resource_fallback_used = False

    def mark_week(
        self,
        *,
        resources_count: int = 0,
        contract_passed: bool = False,
        used_fallback: bool = False,
    ):
        self.total_weeks += 1
        self.total_resources += resources_count

        if contract_passed:
            self.contract_passed_weeks += 1

        if used_fallback:
            self.fallback_weeks += 1
            self.resource_fallback_used = True

    def mark_duplicate_removed(self, count: int = 1):
        self.duplicate_urls_removed += max(0, count)

    def mark_llm_fallback(self):
        self.llm_fallback_used = True

    def finalize(self) -> Dict[str, Any]:
        total_time = round(time.time() - self.start_time, 2)

        return {
            "generation_time_seconds": total_time,
            "total_weeks": self.total_weeks,
            "total_resources": self.total_resources,
            "contract_pass_rate": round(
                self.contract_passed_weeks / self.total_weeks,
                3,
            ) if self.total_weeks else 0,
            "fallback_rate": round(
                self.fallback_weeks / self.total_weeks,
                3,
            ) if self.total_weeks else 0,
            "duplicate_urls_removed": self.duplicate_urls_removed,
            "llm_fallback_used": self.llm_fallback_used,
            "resource_fallback_used": self.resource_fallback_used,
        }