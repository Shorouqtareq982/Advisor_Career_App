from typing import Dict, Optional
from supabase import create_async_client, AsyncClient
from core.config import get_settings

# Create client once at module level
_db_async_client: Optional[AsyncClient] = None

async def get_db_client() -> AsyncClient:
    global _db_async_client
    if _db_async_client is None:
        settings = get_settings()
        _db_async_client = await create_async_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    return _db_async_client

class CVOptRepository:
    """Repository for CV optimization related database operations."""
    
    def __init__(self):
        self.db_client = None
    
    async def _get_client(self):
        if self.db_client is None:
            self.db_client = await get_db_client()
        return self.db_client
    
    # ======================== CV Table Methods ========================
    async def create_cv_record(self, user_id: str, file_url: str, text_content: Optional[str] = None, parsed_content: Optional[Dict] = None, is_primary: bool = False) -> str:
        """Create a new CV record in the database and return its ID."""
        db = await self._get_client()
        language = "ar" if text_content and any(
            char in text_content for char in "ابتثجحخدذرزسشصضطظعغفقكلمنهوي"
        ) else "en"

        if is_primary:
            await db.table("cv").update({"is_primary": False}).eq("user_id", user_id).execute()

        response = await db.table("cv").insert({
            "user_id": user_id,
            "file_url": file_url,
            "text_content": text_content,
            "parsed_content": parsed_content,
            "is_primary": is_primary,
            "language": language
        }).execute()
        if not response.data:
            raise Exception(f"Failed to create CV record: {response}")
        return response.data[0]["cv_id"]

    async def get_cv_by_id(self, cv_id: str) -> Optional[Dict]:
        """Fetch a CV record by its ID."""
        db = await self._get_client()
        response = await db.table("cv").select("*").eq("cv_id", cv_id).execute()
        return response.data[0] if response.data else None
    
    async def get_primary_cv_by_user(self, user_id: str) -> Optional[Dict]:
        """Fetch the primary CV record for a given user."""
        db = await self._get_client()
        response = await db.table("cv").select("*").eq("user_id", user_id).eq("is_primary", True).execute()
        return response.data[0] if response.data else None
    
    async def get_all_cvs_by_user(self, user_id: str) -> list[Dict]:
        """Fetch all CV records for a given user."""
        db = await self._get_client()
        response = await db.table("cv").select("*").eq("user_id", user_id).order("updated_at", desc=True).execute()
        return response.data if response.data else []

    # ======================== Job Postings Table Methods ========================
    async def create_jd_record(self, job_data: Dict) -> str:
        """Create a new Job Description record in the database and return its ID."""
        db = await self._get_client()
        response = await db.table("job_postings").insert(job_data).execute()
        if not response.data:
            raise Exception(f"Failed to create JD record: {response}")
        return response.data[0]["job_id"]
    
    async def get_jd_by_id(self, jd_id: str) -> Optional[Dict]:
        """Fetch a Job Description record by its ID."""
        db = await self._get_client()
        response = await db.table("job_postings").select("*").eq("job_id", jd_id).execute()
        return response.data[0] if response.data else None

    # ======================== CV Optimization Requests Table Methods ========================
    async def create_optimization_request(self, user_id: str, cv_id: str, jd_id: Optional[str] = None, status: str = "processing") -> str:
        """Create a new optimization request record in the database and return its ID."""
        db = await self._get_client()
        response = await db.table("cv_optimization_requests").insert({
            "user_id": user_id,
            "cv_id": cv_id,
            "job_posting_id": jd_id,
            "status": status
        }).execute()
        if not response.data:
            raise Exception(f"Failed to create optimization request: {response}")
        return response.data[0]["request_id"]
    
    async def update_optimization_request_status(self, request_id: str, new_status: str):
        """Update the status of an existing optimization request."""
        db = await self._get_client()
        response = await db.table("cv_optimization_requests").update({"status": new_status}).eq("request_id", request_id).execute()
        if not response.data:
            raise Exception(f"Failed to update optimization request status: {response}")

    async def get_optimization_request_by_id(self, request_id: str) -> Optional[Dict]:
        """Fetch an optimization request by its ID."""
        db = await self._get_client()
        response = await db.table("cv_optimization_requests").select("*").eq("request_id", request_id).execute()
        return response.data[0] if response.data else None

    async def get_optimization_requests_by_user(self, user_id: str) -> list[Dict]:
        """Fetch all optimization requests for a given user."""
        db = await self._get_client()
        response = await db.table("cv_optimization_requests").select("*").eq("user_id", user_id).order("requested_at", desc=True).execute()
        return response.data if response.data else []
    
    # ======================== CV Optimization Reports Table Methods ========================
    async def create_optimization_report(self, report_data: Dict):
        """Create a new optimization result record in the database and return its ID."""
        db = await self._get_client()
        response = await db.table("cv_optimization_reports").insert(report_data).execute()
        if not response.data:
            raise Exception(f"Failed to create optimization result: {response}")
        return response.data[0]
    
    async def delete_optimization_report(self, report_id: str):
        """Delete an optimization report by its ID."""
        db = await self._get_client()
        response = await db.table("cv_optimization_reports").delete().eq("report_id", report_id).execute()
        if not response.data:
            raise Exception(f"Failed to delete optimization report: {response}")
    
    async def get_optimization_report_by_id(self, report_id: str) -> Optional[Dict]:
        """Fetch an optimization report by its ID."""
        db = await self._get_client()
        response = await db.table("cv_optimization_reports").select("*").eq("report_id", report_id).execute()
        return response.data[0] if response.data else None

    async def get_optmization_reports_by_user(self, user_id: str) -> list[Dict]:
        """Fetch all optimization reports for a given user."""
        db = await self._get_client()
        response = await db.table("cv_optimization_reports").select("*, cv_optimization_requests!inner(user_id)").eq("cv_optimization_requests.user_id", user_id).order("generated_at", desc=True).execute()
        return response.data if response.data else []
    
    async def get_optmization_report_by_request_id(self, request_id: str) -> Optional[Dict]:
        """Fetch an optimization report by its associated request ID."""
        db = await self._get_client()
        response = await db.table("cv_optimization_reports").select("*").eq("request_id", request_id).execute()
        return response.data[0] if response.data else None
    
    async def get_optmization_report_by_cv_id(self, cv_id: str, jd_id: str = None, no_jd: bool = False) -> list[Dict]:
        """Fetch an optimization report by its associated CV ID."""
        db = await self._get_client()
        if jd_id:
            response = await db.table("cv_optimization_reports").select("*").eq("cv_id", cv_id).eq("job_posting_id", jd_id).order("generated_at", desc=True).execute()
        elif no_jd:
            response = await db.table("cv_optimization_reports").select("*").eq("cv_id", cv_id).is_("job_posting_id", None).order("generated_at", desc=True).execute()
        else:
            response = await db.table("cv_optimization_reports").select("*").eq("cv_id", cv_id).order("generated_at", desc=True).execute()
        return response.data if response.data else []