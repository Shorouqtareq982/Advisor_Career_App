from typing import Dict, Optional
from supabase import create_async_client, AsyncClient
from core.config import get_settings

# Create client once at module level
_db_client: Optional[AsyncClient] = None

async def get_db_client() -> AsyncClient:
    global _db_client
    if _db_client is None:
        settings = get_settings()
        _db_client = await create_async_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    return _db_client

class CVOptRepository:
    """Repository for CV optimization related database operations."""
    
    def __init__(self):
        self.db_client = None
    
    async def _get_client(self):
        if self.db_client is None:
            self.db_client = await get_db_client()
        return self.db_client
    
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

    async def create_jd_record(self, job_data: Dict) -> str:
        """Create a new Job Description record in the database and return its ID."""
        db = await self._get_client()
        response = await db.table("job_postings").insert(job_data).execute()
        if not response.data:
            raise Exception(f"Failed to create JD record: {response}")
        return response.data[0]["job_id"]
    
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
    
    async def create_optimization_report(self, report_data: Dict) -> str:
        """Create a new optimization result record in the database and return its ID."""
        db = await self._get_client()
        response = await db.table("cv_optimization_reports").insert(report_data).execute()
        if not response.data:
            raise Exception(f"Failed to create optimization result: {response}")
        return response.data[0]["report_id"]
    
    async def update_optimization_request_status(self, request_id: str, new_status: str):
        """Update the status of an existing optimization request."""
        db = await self._get_client()
        response = await db.table("cv_optimization_requests").update({"status": new_status}).eq("request_id", request_id).execute()
        if not response.data:
            raise Exception(f"Failed to update optimization request status: {response}")