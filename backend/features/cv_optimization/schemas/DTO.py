from fastapi import UploadFile
from typing import Optional, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field


class CVOptRequest(BaseModel):
    cv_file: UploadFile
    job_description: str
    

#TODO: Add more fields to the request as needed, such as user_id, optimization parameters, etc.
class CVOptResponse(BaseModel):
    report_id: str
    report: Any
    generated_at: Optional[datetime] = None