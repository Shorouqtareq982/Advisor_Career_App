from supabase import create_client, Client
from typing import List, Dict, Any
from datetime import datetime
import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)


# ========== saved jobs ==========
def save_job(user_id: str, job_data: Dict[str, Any]) -> Dict[str, Any]:
    response = (
        supabase.table("saved_jobs")
        .insert(
            {
                "user_id": user_id,
                "job_data": job_data,
                "saved_at": datetime.now().isoformat(),
            }
        )
        .execute()
    )
    return response.data[0] if response.data else {}


def get_saved_jobs(user_id: str) -> List[Dict[str, Any]]:
    response = (
        supabase.table("saved_jobs")
        .select("*")
        .eq("user_id", user_id)
        .order("saved_at", desc=True)
        .execute()
    )
    return response.data if response.data else []


def delete_saved_job(user_id: str, job_id: str) -> bool:
    response = (
        supabase.table("saved_jobs")
        .delete()
        .eq("id", job_id)
        .eq("user_id", user_id)
        .execute()
    )
    return len(response.data) > 0

def is_job_already_saved(user_id: str, job_link: str) -> bool:
    """Check if a job is already saved by this user."""
    response = (
        supabase.table("saved_jobs")
        .select("id")
        .eq("user_id", user_id)
        .eq("job_data->>link", job_link)
        .execute()
    )
    return len(response.data) > 0


# ========== job titles dropdown ==========
def get_all_job_titles() -> List[str]:
    response = supabase.table("jm_job_titles").select("title").order("title").execute()
    return [item["title"] for item in response.data] if response.data else []


# ========== countries dropdown ==========
def get_all_countries() -> List[Dict[str, str]]:
    response = (
        supabase.table("jm_countries").select("code", "name").order("name").execute()
    )
    return response.data if response.data else []

# ========== job match results (persistent) ==========

def save_match_results(user_id: str, results: List[Dict[str, Any]]) -> bool:
    try:
        supabase.table("job_match_results") \
            .delete() \
            .eq("user_id", user_id) \
            .execute()
        
        rows = [
            {
                "user_id": user_id,
                "job_data": job,
                "matched_at": datetime.now().isoformat(),
            }
            for job in results
        ]
        
        if rows:
            supabase.table("job_match_results").insert(rows).execute()
        
        return True
    except Exception as e:
        print(f"Error saving match results: {e}")
        return False


def get_match_results(user_id: str) -> List[Dict[str, Any]]:
    try:
        response = (
            supabase.table("job_match_results")
            .select("*")
            .eq("user_id", user_id)
            .order("matched_at", desc=False) 
            .execute()
        )
        return response.data if response.data else []
    except Exception as e:
        print(f"Error fetching match results: {e}")
        return []


def delete_match_results(user_id: str) -> bool:
    try:
        supabase.table("job_match_results") \
            .delete() \
            .eq("user_id", user_id) \
            .execute()
        return True
    except Exception as e:
        return False
