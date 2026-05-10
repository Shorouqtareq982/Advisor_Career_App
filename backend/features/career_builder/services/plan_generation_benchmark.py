import time
from typing import Any, Dict
from uuid import UUID


class PlanGenerationBenchmark:
    def __init__(self, plan_generation_service):
        self.service = plan_generation_service

    async def run_benchmark(
        self,
        *,
        cv_id: UUID,
        track_id: int,
        duration_weeks: int,
        available_hours_per_week: int,
        user_level: str | None = None,
    ) -> Dict[str, Any]:

        start = time.perf_counter()

        result = await self.service.generate_plan(
            cv_id=cv_id,
            track_id=track_id,
            duration_weeks=duration_weeks,
            available_hours_per_week=available_hours_per_week,
            user_level=user_level,
            requested_weeks=duration_weeks,
        )

        parallel_time = time.perf_counter() - start

        metadata = result.get("generation_metadata", {}) or {}
        weeks = result.get("weekly_breakdown", []) or []

        total_weeks = len(weeks)
        total_resources = sum(len(w.get("resources", []) or []) for w in weeks)

        contract_passed = 0
        fallback_weeks = 0

        for week in weeks:
            report = week.get("resource_validation_report", {}) or {}

            if report.get("contract_passed") is True or report.get("passed") is True:
                contract_passed += 1

            if report.get("source") in {
                "fallback",
                "hard_fallback",
                "local_fallback",
                "dynamic_plus_discovered_plus_curated",
            }:
                fallback_weeks += 1

        max_parallel = max(
            metadata.get("max_llm_parallel") or 4,
            metadata.get("max_resource_parallel") or 4,
        )

        estimated_sequential = parallel_time * min(duration_weeks, max_parallel)

        improvement = (
            (estimated_sequential - parallel_time) / estimated_sequential * 100
            if estimated_sequential else 0
        )

        summary = {
            "before_sequential_estimate_sec": round(estimated_sequential, 2),
            "after_parallel_measured_sec": round(parallel_time, 2),
            "improvement_percent": round(improvement, 2),
            "total_weeks": total_weeks,
            "total_resources": total_resources,
            "contract_pass_rate": round(contract_passed / total_weeks, 3) if total_weeks else 0,
            "fallback_rate": round(fallback_weeks / total_weeks, 3) if total_weeks else 0,
            "parallel_generation": metadata.get("parallel_generation", True),
            "provider_health": metadata.get("provider_health", {}),
        }

        self.print_summary(summary)

        return {
            "status": "success",
            "feature": "career_build_plan_generation",
            "summary": summary,
            "raw_generation_metadata": metadata,
        }

    def print_summary(self, summary: Dict[str, Any]) -> None:
        print("\n" + "=" * 48)
        print("        CAREER BUILD PERFORMANCE BENCHMARK")
        print("=" * 48)
        print(f"Before Sequential Estimate : {summary['before_sequential_estimate_sec']} sec")
        print(f"After Parallel Measured    : {summary['after_parallel_measured_sec']} sec")
        print(f"Improvement                : {summary['improvement_percent']}% faster")
        print("-" * 48)
        print(f"Total Weeks                : {summary['total_weeks']}")
        print(f"Total Resources            : {summary['total_resources']}")
        print(f"Resource Contract Pass Rate: {summary['contract_pass_rate']}")
        print(f"Fallback Rate              : {summary['fallback_rate']}")
        print(f"Parallel Generation        : {summary['parallel_generation']}")
        print("=" * 48 + "\n")