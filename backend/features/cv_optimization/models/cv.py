from typing import Optional, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field
from ..schemas import CVData

class CV(BaseModel):
    cv_id: Optional[UUID] = None
    user_id: Optional[UUID] = None
    file_url: str
    parsed_content: Optional[CVData] = None  # JSONB
    embedding: Optional[Any] = None       # Vector as JSON
    language: Optional[str] = None
    is_primary: Optional[bool] = True
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    text_content: Optional[str] = None