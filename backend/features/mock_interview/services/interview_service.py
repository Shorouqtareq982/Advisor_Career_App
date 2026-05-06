import asyncio
import json
import logging
import os
import tempfile
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from uuid import UUID

from azure.storage.blob import BlobClient, BlobSasPermissions, generate_blob_sas
from fastapi import HTTPException

from core.config import settings
from features.mock_interview.ml_model import behavioral_pipeline, technical_pipeline
from features.mock_interview.repositories.mock_interview_repository import MockInterviewRepository
from features.mock_interview.schemas.mock_interview_schemas import GeminiFeedback
from features.mock_interview.services.elevenlabs_service import ElevenLabsService
from shared.providers.llm_models.gemini import Gemini
from shared.providers.storage.azure_blob_storage import get_azure_storage_provider

logger = logging.getLogger(__name__)


class MockInterviewService:
    def __init__(self, repository: MockInterviewRepository):
        self.repo = repository
        self.tts = ElevenLabsService()
        self.gemini = Gemini(settings)

    async def start_session(self, role_name: str, user_id: UUID) -> Dict[str, Any]:
        role = await self.repo.get_role_by_name(role_name)
        if not role:
            raise HTTPException(status_code=404, detail="Role not found")

        session = await self.repo.create_session(user_id=user_id, role_id=UUID(role["role_id"]))
        if not session:
            raise HTTPException(status_code=500, detail="Failed to create session")

        questions = await self.repo.list_behavioral_questions(role_name)
        sas_token, blob_url, sas_expires_at = await self._create_video_upload_sas(UUID(session["session_id"]))

        return {
            "session_id": UUID(session["session_id"]),
            "questions": questions,
            "sas_token": sas_token,
            "blob_url": blob_url,
            "sas_expires_at": sas_expires_at,
        }

    async def get_question_audio_bytes(self, question_id: UUID) -> bytes:
        question_text = await self.repo.get_question_text(question_id)
        if not question_text:
            raise HTTPException(status_code=404, detail="Question not found")

        try:
            return self.tts.synthesize(question_text)
        except Exception as e:
            logger.error(f"ElevenLabs TTS failed: {e}", exc_info=True)
            raise HTTPException(status_code=502, detail="ElevenLabs TTS failed")

    async def process_behavioral_upload(self, session_id: UUID, blob_url: str) -> None:
        try:
            session = await self.repo.get_session(session_id)
            if not session:
                logger.warning("Session not found for behavioral processing")
                return

            video_bytes = await self._download_blob_bytes(blob_url)
            metrics = await asyncio.to_thread(self._run_behavioral_pipeline, video_bytes)
            report = await self._build_behavioral_report(metrics)
            await self.repo.upsert_behavioral_analysis(
                session_id=session_id,
                analysis_metrics=metrics,
                behavioral_report=report,
            )

            response_payload = await self._get_latest_valid_transcript_response(UUID(session["user_id"]))
            await self.process_technical_analysis(session_id=session_id, response_payload=response_payload)

            await self._safe_update_session_status(session_id, "completed")
            await self._safe_delete_blob(blob_url)
        except Exception:
            await self._safe_update_session_status(session_id, "failed")
            logger.exception("Behavioral analysis background task failed")

    async def process_technical_analysis(self, session_id: UUID, response_payload: Optional[str] = None) -> str:
        session = await self.repo.get_session(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")

        role = await self.repo.get_role_by_id(UUID(session["role_id"]))
        if not role:
            raise HTTPException(status_code=404, detail="Role not found")

        questions = await self.repo.list_behavioral_questions(role["role_name"])
        question_ids = [UUID(item["question_id"]) for item in questions[:7]]
        if len(question_ids) < 7:
            raise HTTPException(status_code=400, detail="Insufficient questions for technical analysis")

        if response_payload is None:
            transcript_row = await self.repo.get_latest_response_for_user(UUID(session["user_id"]))
            if not transcript_row or not transcript_row.get("response"):
                raise HTTPException(status_code=404, detail="Transcript not found")
            response_payload = transcript_row["response"]

        chunks = technical_pipeline.chunk_transcript_words(response_payload)
        if len(chunks) != 7:
            raise HTTPException(status_code=400, detail="Transcript chunk count must be 7")

        for index, chunk in enumerate(chunks):
            await self.repo.insert_session_response(
                user_id=UUID(session["user_id"]),
                question_id=question_ids[index],
                response=chunk,
            )

        report = await self._build_technical_report(chunks)
        await self.repo.upsert_technical_analysis(session_id=session_id, technical_report=report)
        return report

    async def get_analysis(self, session_id: UUID) -> Dict[str, Any]:
        analysis = await self.repo.get_session_analysis(session_id)
        if not analysis:
            raise HTTPException(status_code=404, detail="Analysis not found")
        return analysis

    async def _create_video_upload_sas(self, session_id: UUID) -> tuple[str, str, datetime]:
        try:
            storage = get_azure_storage_provider(container_name=settings.AZURE_CONTAINER_NAME)
            blob_name = f"{session_id}.mp4"
            blob_client = storage.blob_service_client.get_blob_client(
                container=storage.container_name,
                blob=blob_name,
            )
            expires_at = datetime.utcnow() + timedelta(hours=1)
            sas_token = generate_blob_sas(
                account_name=storage.blob_service_client.account_name,
                container_name=storage.container_name,
                blob_name=blob_name,
                account_key=storage.blob_service_client.credential.account_key,
                permission=BlobSasPermissions(write=True, create=True),
                expiry=expires_at,
            )
            return sas_token, blob_client.url, expires_at
        except Exception as e:
            logger.error(f"Azure SAS generation failed: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to generate upload SAS token")

    async def _download_blob_bytes(self, blob_url: str) -> bytes:
        try:
            credential = settings.STORAGE_ACCOUNT_KEY or None
            blob_client = BlobClient.from_blob_url(blob_url, credential=credential)
            return blob_client.download_blob().readall()
        except Exception as e:
            logger.error(f"Azure blob download failed: {e}", exc_info=True)
            raise

    async def _safe_delete_blob(self, blob_url: str) -> None:
        try:
            blob_client = BlobClient.from_blob_url(blob_url, credential=settings.STORAGE_ACCOUNT_KEY or None)
            blob_name = blob_client.blob_name
            if not blob_name:
                logger.warning("Blob name missing from url; skipping delete")
                return
            storage = get_azure_storage_provider(container_name=settings.AZURE_CONTAINER_NAME)
            storage.delete_file(blob_name)
        except Exception as e:
            logger.warning(f"Failed to delete blob: {e}")

    async def _safe_update_session_status(self, session_id: UUID, status: str) -> None:
        try:
            await self.repo.update_session_status(session_id, status)
        except Exception as e:
            logger.warning(f"Failed to update session status: {e}")

    def _run_behavioral_pipeline(self, video_bytes: bytes) -> Dict[str, Any]:
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_file:
                temp_file.write(video_bytes)
                temp_path = temp_file.name

            device = behavioral_pipeline.torch.device(
                "cuda" if behavioral_pipeline.torch.cuda.is_available() else "cpu"
            )
            (
                vocab,
                nlp,
                smile,
                audio_mins,
                audio_denom,
                visual,
                audio,
                text,
                baseline,
                siamese,
                final,
            ) = behavioral_pipeline.load_all_models(device)

            predictions, transcript = behavioral_pipeline.predict_video(
                temp_path,
                visual,
                audio,
                text,
                baseline,
                siamese,
                final,
                vocab,
                nlp,
                smile,
                audio_mins,
                audio_denom,
                device,
            )

            visual_metrics = behavioral_pipeline.extract_visual_metrics(temp_path)
            audio_metrics = behavioral_pipeline.extract_audio_metrics(temp_path)
            text_metrics = behavioral_pipeline.extract_text_metrics(transcript)

            return {
                "predictions": predictions,
                "visual_metrics": visual_metrics,
                "audio_metrics": audio_metrics,
                "text_metrics": text_metrics,
                "transcript": transcript or "",
            }
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    async def _build_behavioral_report(self, metrics: Dict[str, Any]) -> str:
        prompt = (
            "You are an interview coach. Review the behavioral metrics JSON and "
            "respond with JSON containing strengths, weaknesses, and suggestions.\n"
            f"Metrics: {json.dumps(metrics, ensure_ascii=False)}"
        )
        feedback = await self._get_gemini_feedback(prompt)
        return self._format_feedback(feedback)

    async def _build_technical_report(self, chunks: List[str]) -> str:
        payload = "\n".join([f"Chunk {i + 1}: {text}" for i, text in enumerate(chunks)])
        prompt = (
            "You are an interview coach. Review the technical interview transcript "
            "chunks and respond with JSON containing strengths, weaknesses, and suggestions.\n"
            f"Transcript:\n{payload}"
        )
        feedback = await self._get_gemini_feedback(prompt)
        return self._format_feedback(feedback)

    async def _get_gemini_feedback(self, prompt: str) -> GeminiFeedback:
        result = await self.gemini.get_response(
            prompt=prompt,
            need_json_output=True,
            schema=GeminiFeedback,
            expecting_longer_output=False,
        )
        if result is None:
            raise HTTPException(status_code=422, detail="Gemini response failed")
        if isinstance(result, GeminiFeedback):
            return result
        if isinstance(result, str):
            try:
                return GeminiFeedback.model_validate_json(result)
            except Exception as e:
                logger.error(f"Gemini JSON parse failed: {e}")
        if isinstance(result, dict):
            return GeminiFeedback(**result)
        raise HTTPException(status_code=422, detail="Gemini response invalid")

    def _format_feedback(self, feedback: GeminiFeedback) -> str:
        return (
            f"Strengths: {feedback.strengths}\n"
            f"Weaknesses: {feedback.weaknesses}\n"
            f"Suggestions: {feedback.suggestions}"
        )

    async def _get_latest_valid_transcript_response(self, user_id: UUID) -> str:
        responses = await self.repo.list_responses_for_user(user_id=user_id)
        for response in responses:
            payload = response.get("response")
            if not isinstance(payload, str):
                continue
            try:
                technical_pipeline.validate_transcript_words(payload)
                return payload
            except ValueError:
                continue

        raise ValueError("No valid transcript response found for user")
