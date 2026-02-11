from typing import Optional, Any, Literal
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field

class CVOptimizationRequest(BaseModel):
    request_id: UUID
    cv_id: Optional[UUID] = None
    job_posting_id: Optional[UUID] = None
    user_id: Optional[UUID] = None
    status: Optional[Literal["pending", "processing", "completed", "failed"]] = None
    requested_at: Optional[datetime] = None


