import pandas as pd
from typing import Optional, Dict, Any
from shared.providers import supabase_client


class MarketInsightsRepository:
    def __init__(self):
        self.supabase = supabase_client.get_client()

    def load_state(self, sheet: str) -> Dict[str, Any]:
        """Load crawler state for a sheet."""
        try:
            res = self.supabase.table("crawler_state") \
                .select("state") \
                .eq("sheet", sheet) \
                .execute()

            if res.data and len(res.data) > 0:
                return res.data[0].get("state") or {}

            return {}
        except Exception as e:
            print(f"⚠️ Warning: Could not load state from Supabase: {e}")
            return {}

    def save_state(self, sheet: str, state: Dict[str, Any]):
        """Save crawler state for a sheet."""
        try:
            self.supabase.table("crawler_state").upsert({
                "sheet": sheet,
                "state": state
            }, on_conflict="sheet").execute()
        except Exception as e:
            print(f"⚠️ Warning: Could not save state to Supabase: {e}")

    def load_jobs(self, sheet: str) -> pd.DataFrame:
        """Load jobs data for a sheet."""
        try:
            res = self.supabase.table("jobs_market_insight").select("*").ilike("sheet", sheet).execute()

            if res.data:
                return pd.DataFrame(res.data)

            return pd.DataFrame()

        except Exception as e:
            print("Error loading from Supabase:", e)
            return pd.DataFrame()

    def save_jobs(self, jobs: list, conflict_columns: str = "job_url,sheet"):
        """Save jobs data to Supabase."""
        try:
            if jobs:
                self.supabase.table("jobs_market_insight").upsert(
                    jobs,
                    on_conflict=conflict_columns
                ).execute()
                print(f"✅ Saved {len(jobs)} jobs to Supabase")
        except Exception as e:
            print(f"⚠️ Warning: Could not save jobs to Supabase: {e}")

    def get_jobs_count(self, sheet: str) -> int:
        """Get count of jobs for a sheet."""
        try:
            res = self.supabase.table("jobs_market_insight") \
                .select("id", count="exact") \
                .ilike("sheet", sheet) \
                .execute()

            return res.count or 0
        except Exception as e:
            print(f"Error getting jobs count: {e}")
            return 0

    def get_all_jobs(self, limit: int = 1000) -> pd.DataFrame:
        """Get all jobs for market insights analysis."""
        try:
            res = self.supabase.table("jobs_market_insight").select("*").limit(limit).execute()
            if res.data:
                return pd.DataFrame(res.data)
            return pd.DataFrame()
        except Exception as e:
            print(f"Error loading all jobs: {e}")
            return pd.DataFrame()
