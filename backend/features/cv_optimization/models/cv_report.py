from typing import Optional, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field
from ..schemas import ATSAnalysisResponse

class CVOptimizationReport(BaseModel):
    report_id: Optional[UUID] = None
    request_id: Optional[UUID] = None
    cv_id: Optional[UUID] = None
    job_posting_id: Optional[UUID] = None
    analysis: Optional[ATSAnalysisResponse] = None
    generated_at: Optional[datetime] = None