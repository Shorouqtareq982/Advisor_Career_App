from typing import Literal, Optional, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field
from schemas import JobData

class JobPosting(BaseModel):
    job_id: UUID
    raw_text: Optional[str] = None
    url: Optional[str] = None
    parsed_data: Optional[JobData] = None
    source_type: Optional[Literal["text", "api", "url"]] = None
    created_at: Optional[datetime] = None