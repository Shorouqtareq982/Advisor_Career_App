from datetime import datetime
from typing import Optional, List, Dict, Any
from uuid import UUID

from pydantic import BaseModel


class StartSessionRequest(BaseModel):
    role_name: str
    user_id: UUID


class QuestionItem(BaseModel):
    question_id: UUID
    question_text: str


class StartSessionResponse(BaseModel):
    session_id: UUID
    questions: List[QuestionItem]
    sas_token: str
    blob_url: str
    sas_expires_at: datetime


class NotifyUploadRequest(BaseModel):
    session_id: UUID
    blob_url: str


class StatusResponse(BaseModel):
    status: str


class AnalysisResponse(BaseModel):
    analysis_id: UUID
    behavioral_report: Optional[str] = None
    technical_report: Optional[str] = None
    analysis_metrics: Dict[str, Any]
    overall_score: Optional[float] = None
    analyzed_at: datetime


class GeminiFeedback(BaseModel):
    strengths: str
    weaknesses: str
    suggestions: str
