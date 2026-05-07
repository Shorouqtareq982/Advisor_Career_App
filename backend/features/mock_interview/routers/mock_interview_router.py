import io
import logging
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import StreamingResponse

from features.mock_interview.schemas.mock_interview_schemas import (
    StartSessionRequest,
    StartSessionResponse,
    NotifyUploadRequest,
    StatusResponse,
    AnalysisResponse,
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


@router.post("/sessions/start", response_model=StartSessionResponse)
async def start_session(
    payload: StartSessionRequest,
    service: MockInterviewService = Depends(get_service),
):
    return await service.start_session(payload.role_name, payload.user_id)


@router.get("/questions/{question_id}/audio-stream")
async def stream_question_audio(
    question_id: UUID,
    service: MockInterviewService = Depends(get_service),
):
    audio_bytes = await service.get_question_audio_bytes(question_id)
    return StreamingResponse(io.BytesIO(audio_bytes), media_type="audio/mpeg")


@router.post("/behavioural/notify-upload", response_model=StatusResponse)
async def notify_behavioral_upload(
    payload: NotifyUploadRequest,
    background_tasks: BackgroundTasks,
    service: MockInterviewService = Depends(get_service),
):
    session = await service.repo.get_session(payload.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    await service.verify_blob_ready(payload.blob_url)

    background_tasks.add_task(
        service.process_behavioral_upload,
        payload.session_id,
        payload.blob_url,
    )
    return StatusResponse(status="processing")


@router.get("/analysis/{session_id}", response_model=AnalysisResponse)
async def get_analysis(
    session_id: UUID,
    service: MockInterviewService = Depends(get_service),
):
    analysis = await service.get_analysis(session_id)
    return AnalysisResponse(
        analysis_id=UUID(analysis["analysis_id"]),
        behavioral_report=analysis.get("behavioral_report"),
        technical_report=analysis.get("technical_report"),
        analysis_metrics=analysis.get("analysis_metrics") or {},
        overall_score=analysis.get("overall_score"),
        analyzed_at=analysis["analyzed_at"],
    )
