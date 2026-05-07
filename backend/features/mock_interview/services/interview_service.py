import asyncio
import json
import logging
import os
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Any, List, Optional
from uuid import UUID

from azure.storage.blob import BlobClient, BlobSasPermissions, generate_blob_sas
from fastapi import HTTPException

from core.config import settings
from features.mock_interview.ml_model import behavioral_pipeline, technical_pipeline
from features.mock_interview.repositories.mock_interview_repository import MockInterviewRepository
from features.mock_interview.schemas.mock_interview_schemas import GeminiFeedback
from features.mock_interview.services.assemblyai_service import AssemblyAIService
from features.mock_interview.services.elevenlabs_service import ElevenLabsService
from shared.providers.llm_models.gemini import Gemini
from shared.providers.storage.azure_blob_storage import get_azure_storage_provider

logger = logging.getLogger(__name__)


class MockInterviewService:
    def __init__(self, repository: MockInterviewRepository):
        self.repo = repository
        self.tts = ElevenLabsService()
        self.gemini = Gemini(settings)
        self.transcriber = AssemblyAIService()
        self.prompts_dir = Path(__file__).resolve().parent.parent / "prompts"

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

            await self._wait_for_blob_ready(blob_url)

            video_bytes = await self._download_blob_bytes(blob_url)
            metrics = await asyncio.to_thread(self._run_behavioral_pipeline, video_bytes)
            report = await self._build_behavioral_report(metrics)
            await self.repo.upsert_behavioral_analysis(
                session_id=session_id,
                analysis_metrics=metrics,
                behavioral_report=report,
            )

            transcript_payload = metrics.get("transcript_payload")
            if transcript_payload:
                await self._store_transcript_payload(session, transcript_payload)
                await self.process_technical_analysis(
                    session_id=session_id,
                    response_payload=json.dumps(transcript_payload),
                )
            else:
                logger.warning("Transcript payload missing; skipping technical analysis")

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

        cleaned_chunks = technical_pipeline.preprocess_chunks(chunks)

        question_items = questions[:7]
        qa_pairs = [
            {
                "question": item.get("question_text") or "",
                "answer": cleaned_chunks[index] if index < len(cleaned_chunks) else "",
            }
            for index, item in enumerate(question_items)
        ]

        for index, chunk in enumerate(cleaned_chunks):
            await self.repo.insert_session_response(
                user_id=UUID(session["user_id"]),
                question_id=question_ids[index],
                response=chunk,
            )

        report = await self._build_technical_report(
            qa_pairs,
            role.get("role_name") or "the role",
        )
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

    async def verify_blob_ready(self, blob_url: str, min_size_bytes: int = 1) -> None:
        try:
            credential = settings.STORAGE_ACCOUNT_KEY or None
            blob_client = BlobClient.from_blob_url(blob_url, credential=credential)
            props = blob_client.get_blob_properties()
            size = getattr(props, "size", None)
            if size is None or size < min_size_bytes:
                raise HTTPException(status_code=400, detail="Blob not ready or empty")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Blob verification failed: {e}")
            raise HTTPException(status_code=404, detail="Blob not found") from e

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

    async def _wait_for_blob_ready(
        self,
        blob_url: str,
        max_wait_seconds: int = 120,
        poll_interval_seconds: int = 5,
        min_size_bytes: int = 1024,
    ) -> None:
        deadline = datetime.utcnow().timestamp() + max_wait_seconds
        last_size = 0
        while datetime.utcnow().timestamp() < deadline:
            try:
                credential = settings.STORAGE_ACCOUNT_KEY or None
                blob_client = BlobClient.from_blob_url(blob_url, credential=credential)
                props = blob_client.get_blob_properties()
                size = getattr(props, "size", None)
                if size is not None and size >= min_size_bytes:
                    if size == last_size:
                        return
                    last_size = size
            except Exception as e:
                logger.debug(f"Blob readiness check failed: {e}")
            await asyncio.sleep(poll_interval_seconds)

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

            transcript_text, transcript_words = self.transcriber.transcribe_video_file(
                temp_path,
                max_wait_seconds=900,
                poll_interval_seconds=5,
            )
            if not transcript_text or not transcript_words:
                raise RuntimeError("Transcription failed or missing word timestamps")
            predictions, transcript_text, transcript_words = behavioral_pipeline.predict_video(
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
                transcript_text=transcript_text,
                transcript_words=transcript_words,
            )

            visual_metrics = behavioral_pipeline.extract_visual_metrics(temp_path)
            audio_metrics = behavioral_pipeline.extract_audio_metrics(temp_path)
            text_metrics = behavioral_pipeline.extract_text_metrics(transcript_text)
            transcript_payload = {
                "text": transcript_text or "",
                "words": transcript_words or [],
            }

            return {
                "predictions": predictions,
                "visual_metrics": visual_metrics,
                "audio_metrics": audio_metrics,
                "text_metrics": text_metrics,
                "transcript": transcript_text or "",
                "transcript_payload": transcript_payload,
            }
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    async def _build_behavioral_report(self, metrics: Dict[str, Any]) -> str:
        template = self._load_prompt("behavioral_report_prompt.txt")
        prompt = template.replace(
            "[Paste Numerical Scores/Data Here]",
            json.dumps(metrics, ensure_ascii=False),
        )
        feedback = await self._get_gemini_feedback(prompt)
        return self._format_feedback(feedback)

    async def _build_technical_report(self, qa_pairs: List[Dict[str, str]], role_name: str) -> str:
        payload = "\n".join(
            [
                f"Q{i + 1}: {pair.get('question', '')}\nA{i + 1}: {pair.get('answer', '')}"
                for i, pair in enumerate(qa_pairs)
            ]
        )
        template = self._load_prompt("technical_report_prompt.txt")
        prompt = (
            template
            .replace("[Insert Job Title]", role_name)
            .replace("[Paste Answers Here]", payload)
        )
        feedback = await self._get_gemini_feedback(prompt)
        return self._format_feedback(feedback)

    def _load_prompt(self, filename: str) -> str:
        prompt_path = self.prompts_dir / filename
        if not prompt_path.exists():
            raise HTTPException(status_code=500, detail=f"Prompt file missing: {filename}")
        return prompt_path.read_text(encoding="utf-8")

    async def _store_transcript_payload(self, session: Dict[str, Any], transcript_payload: Dict[str, Any]) -> None:
        try:
            role = await self.repo.get_role_by_id(UUID(session["role_id"]))
            if not role:
                logger.warning("Role not found for transcript storage")
                return

            questions = await self.repo.list_behavioral_questions(role["role_name"])
            if not questions:
                logger.warning("No questions found for transcript storage")
                return

            question_id = UUID(questions[0]["question_id"])
            await self.repo.insert_session_response(
                user_id=UUID(session["user_id"]),
                question_id=question_id,
                response=json.dumps(transcript_payload),
            )
        except Exception as e:
            logger.warning(f"Failed to store transcript payload: {e}")

    async def _get_gemini_feedback(self, prompt: str) -> GeminiFeedback:
        last_error: Optional[Exception] = None
        for attempt in range(3):
            result = await self.gemini.get_response(
                prompt=prompt,
                need_json_output=True,
                schema=GeminiFeedback,
                expecting_longer_output=False,
            )
            if result is None:
                last_error = HTTPException(status_code=422, detail="Gemini response failed")
            elif isinstance(result, GeminiFeedback):
                return result
            elif isinstance(result, str):
                try:
                    return GeminiFeedback.model_validate_json(result)
                except Exception as e:
                    last_error = e
                    logger.error(f"Gemini JSON parse failed: {e}")
            elif isinstance(result, dict):
                return GeminiFeedback(**result)
            else:
                last_error = HTTPException(status_code=422, detail="Gemini response invalid")

            if attempt < 2:
                await asyncio.sleep(5)

        if isinstance(last_error, HTTPException):
            raise last_error
        raise HTTPException(status_code=422, detail="Gemini response failed")

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
