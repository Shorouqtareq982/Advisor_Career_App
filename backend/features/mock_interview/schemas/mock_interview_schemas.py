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


class TechnicalStartSessionResponse(BaseModel):
    session_id: UUID
    questions: List[QuestionItem]
    sas_token: str
    blob_url: str
    sas_expires_at: datetime


class NotifyUploadRequest(BaseModel):
    session_id: UUID
    blob_url: str


class NotifyUploadResponse(BaseModel):
    session_id: UUID


class StatusResponse(BaseModel):
    status: str


class UploadStatusResponse(BaseModel):
    status: str


class BehavioralReportResponse(BaseModel):
    analysis_id: UUID
    behavioral_report: Optional[str] = None
    analysis_metrics: Dict[str, Any]
    analyzed_at: datetime


class TechnicalReportResponse(BaseModel):
    analysis_id: UUID
    technical_report: Optional[str] = None
    analyzed_at: datetime


class BehavioralGeminiFeedback(BaseModel):
    strengths: str
    weaknesses: str
    suggestions: str


class GeminiFeedback(BaseModel):
    strengths: str
    weaknesses: str
    suggestions: str