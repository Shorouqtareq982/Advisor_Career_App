import io
import logging
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import StreamingResponse

from features.mock_interview.schemas.mock_interview_schemas import (
    StartSessionRequest,
    StartSessionResponse,
    TechnicalStartSessionResponse,
    NotifyUploadRequest,
    UploadStatusResponse,
)
from features.mock_interview.repositories.mock_interview_repository import MockInterviewRepository
from features.mock_interview.services.interview_service import MockInterviewService
from shared.providers.supabase.database import db as supabase_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/mock-interview", tags=["mock-interview"])


def get_repository() -> MockInterviewRepository:
    return MockInterviewRepository(supabase_db)


def get_service(repo: MockInterviewRepository = Depends(get_repository)) -> MockInterviewService:
    return MockInterviewService(repository=repo)


# ------------------------------------------------------------------ #
#  Session creation                                                    #
# ------------------------------------------------------------------ #

@router.post("/sessions/start/behavioral", response_model=StartSessionResponse)
async def start_behavioral_session(
    payload: StartSessionRequest,
    service: MockInterviewService = Depends(get_service),
):
    return await service.start_behavioral_session(payload.role_name, payload.user_id)


@router.post("/sessions/start/technical", response_model=TechnicalStartSessionResponse)
async def start_technical_session(
    payload: StartSessionRequest,
    service: MockInterviewService = Depends(get_service),
):
    return await service.start_technical_session(payload.role_name, payload.user_id)


# ------------------------------------------------------------------ #
#  Audio TTS                                                           #
# ------------------------------------------------------------------ #

@router.get("/questions/{question_id}/audio-stream")
async def stream_question_audio(
    question_id: UUID,
    service: MockInterviewService = Depends(get_service),
):
    audio_bytes = await service.get_question_audio_bytes(question_id)
    return StreamingResponse(io.BytesIO(audio_bytes), media_type="audio/mpeg")


# ------------------------------------------------------------------ #
#  Upload notify (behavioral or technical)                             #
# ------------------------------------------------------------------ #

@router.post("/notify-upload", response_model=UploadStatusResponse, status_code=202)
async def notify_upload(
    payload: NotifyUploadRequest,
    background_tasks: BackgroundTasks,
    service: MockInterviewService = Depends(get_service),
):
    session = await service.repo.get_session(payload.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.get("_session_table") == "technical_session":
        background_tasks.add_task(
            service.queue_technical_upload,
            payload.session_id,
            payload.blob_url,
        )
    else:
        background_tasks.add_task(
            service.queue_behavioral_upload,
            payload.session_id,
            payload.blob_url,
        )

    return UploadStatusResponse(status="processing")


# ------------------------------------------------------------------ #
#  Report retrieval                                                    #
# ------------------------------------------------------------------ #

@router.get("/analysis/{session_id}/behavioral-report", response_model=str)
async def get_behavioral_report(
    session_id: UUID,
    service: MockInterviewService = Depends(get_service),
):
    analysis = await service.get_analysis(session_id)
    # Return only the report string
    return analysis.get("behavioral_report") or ""


@router.get("/analysis/{session_id}/technical-report", response_model=str)
async def get_technical_report(
    session_id: UUID,
    service: MockInterviewService = Depends(get_service),
):
    analysis = await service.get_analysis(session_id)
    # Return only the report string
    return analysis.get("technical_report") or ""