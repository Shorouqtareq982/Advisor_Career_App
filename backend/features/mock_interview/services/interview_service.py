import asyncio
import json
import logging
import os
import re
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Any, Optional, cast
from uuid import UUID

from azure.storage.blob import BlobClient, BlobSasPermissions, generate_blob_sas
from fastapi import HTTPException

from core.config import settings
from features.mock_interview.ml_model import behavioral_pipeline
from features.mock_interview.repositories.mock_interview_repository import MockInterviewRepository
from features.mock_interview.services.assemblyai_service import AssemblyAIService
from features.mock_interview.services.whisper_service import WhisperTranscriptionService
from features.mock_interview.services.behavioral_report_service import BehavioralReportService
from features.mock_interview.services.elevenlabs_service import ElevenLabsService
from features.mock_interview.services.technical_report_service import TechnicalReportService
from shared.providers.llm_models.gemini import Gemini
from shared.providers.llm_models.groq_provider import GroqProvider
from shared.providers.storage.azure_blob_storage import get_azure_storage_provider

logger = logging.getLogger(__name__)


class MockInterviewService:
    def __init__(self, repository: MockInterviewRepository):
        self.repo = repository
        self.tts = ElevenLabsService()
        self.gemini = Gemini(settings)
        self.groq = GroqProvider(settings) if settings.GROQ_API_KEY else None
        self.assembly_transcriber = AssemblyAIService()
        self.whisper_transcriber: Optional[WhisperTranscriptionService] = None
        self.prompts_dir = Path(__file__).resolve().parent.parent / "prompts"
        self.behavioral_reports = BehavioralReportService(self.gemini, self.prompts_dir, self.groq)
        self.technical_reports = TechnicalReportService(self.gemini, self.prompts_dir, self.groq)

    # ------------------------------------------------------------------ #
    #  Session creation                                                    #
    # ------------------------------------------------------------------ #

    async def start_behavioral_session(
        self,
        role_name: str,
        user_id: UUID,
        language_preferred: Optional[str],
    ) -> Dict[str, Any]:
        role = await self.repo.get_role_by_name(role_name)
        if not role:
            raise HTTPException(status_code=404, detail="Role not found")

        session = await self.repo.create_session(
            user_id=user_id,
            role_id=UUID(role["role_id"]),
            session_type="behavioral",
        )
        if not session:
            raise HTTPException(status_code=500, detail="Failed to create session")

        questions = await self.repo.list_behavioral_questions(role_name)
        if self._is_arabic_preference(language_preferred):
            questions = self._use_arabic_question_text(questions)
        sas_token, blob_url, sas_expires_at = await self._create_video_upload_sas(
            UUID(session["session_id"])
        )

        return {
            "session_id": UUID(session["session_id"]),
            "questions": questions,
            "sas_token": sas_token,
            "blob_url": blob_url,
            "sas_expires_at": sas_expires_at,
            "language_preferred": language_preferred,
        }

    async def start_technical_session(
        self,
        role_name: str,
        user_id: UUID,
        language_preferred: Optional[str],
    ) -> Dict[str, Any]:
        role = await self.repo.get_role_by_name(role_name)
        if not role:
            raise HTTPException(status_code=404, detail="Role not found")

        session = await self.repo.create_session(
            user_id=user_id,
            role_id=UUID(role["role_id"]),
            session_type="technical",
        )
        if not session:
            raise HTTPException(status_code=500, detail="Failed to create session")

        questions = await self.repo.list_technical_questions(UUID(role["role_id"]))
        if self._is_arabic_preference(language_preferred):
            questions = self._use_arabic_question_text(questions)
        sas_token, blob_url, sas_expires_at = await self._create_audio_upload_sas(
            UUID(session["session_id"])
        )

        return {
            "session_id": UUID(session["session_id"]),
            "questions": questions,
            "sas_token": sas_token,
            "blob_url": blob_url,
            "sas_expires_at": sas_expires_at,
            "language_preferred": language_preferred,
        }

    # ------------------------------------------------------------------ #
    #  Audio TTS                                                           #
    # ------------------------------------------------------------------ #

    async def get_question_audio_bytes(
        self,
        question_id: UUID,
        language_preferred: Optional[str] = None,
    ) -> bytes:
        question_text = await self.repo.get_question_text_for_language(
            question_id,
            language_preferred,
        )
        if not question_text:
            raise HTTPException(status_code=404, detail="Question not found")
        try:
            return self.tts.synthesize(question_text)
        except Exception as e:
            logger.error(f"ElevenLabs TTS failed: {e}", exc_info=True)
            raise HTTPException(status_code=502, detail="ElevenLabs TTS failed")

    # ------------------------------------------------------------------ #
    #  Behavioral pipeline — upload → process → notify → delete blob      #
    # ------------------------------------------------------------------ #

    async def queue_behavioral_upload(
        self,
        session_id: UUID,
        blob_url: str,
        language_preferred: Optional[str] = None,
    ) -> None:
        """
        Called as a background task from the notify-upload endpoint.
        Frontend notifies only after upload completes, so processing starts immediately.
        The blob is always deleted when processing finishes (success or failure).
        Status is NOT set here — claim_session_for_processing is the single
        place that transitions the session to in_progress, keeping the duplicate
        guard reliable.
        """
        await self._process_behavioral_upload(session_id, blob_url, language_preferred)

    async def _process_behavioral_upload(
        self,
        session_id: UUID,
        blob_url: str,
        language_preferred: Optional[str] = None,
    ) -> None:
        """
        Downloads the video, runs the behavioral pipeline, saves results,
        then deletes the blob from Azure. Does NOT call the technical pipeline.
        """
        try:
            session = await self.repo.get_session(session_id)
            if not session:
                logger.warning("Behavioral: session not found, skipping")
                return

            claimed = await self.repo.claim_session_for_processing(session_id)
            if not claimed:
                logger.info("Behavioral: session already in_progress/completed, skipping duplicate run")
                return

            # Keep user_id for FCM notification (from HEAD)
            user_id = session.get("user_id")

            # Blob readiness check (from origin/main)
            if not await self._is_blob_ready(blob_url, min_size_bytes=1024):
                logger.warning("Behavioral: blob missing or too small, skipping")
                await self._safe_update_session_status(session_id, "pending")
                return

            role_name = None
            try:
                role = await self.repo.get_role_by_id(UUID(session["role_id"]))
                if role:
                    role_name = role.get("role_name")
            except Exception as e:
                logger.warning(f"Behavioral: failed to resolve role: {e}")

            video_bytes = await self._download_blob_bytes(blob_url)
            metrics = await asyncio.to_thread(
                self._run_behavioral_pipeline,
                video_bytes,
                language_preferred,
            )

            behavioral_metrics = self._extract_behavioral_metrics(metrics)
            report_language = "ar" if self._is_arabic_preference(language_preferred) else "en"
            if report_language != "ar" and self._prefers_arabic_report(session):
                report_language = "ar"
            report = await self.behavioral_reports.build_report(
                behavioral_metrics,
                role_name=role_name,
                report_language=report_language,
            )
            transcript_text = cast(str, metrics.get("transcript") or "")
            behavioral_score = self._extract_score(behavioral_metrics)

            await self.repo.upsert_behavioral_analysis(
                session_id=session_id,
                analysis_metrics=behavioral_metrics,
                behavioral_report=report,
                transcript=transcript_text,
                video_url=None,
                score=behavioral_score,
            )

            await self._safe_update_session_status(session_id, "completed")
            logger.info(f"Behavioral pipeline completed for session {session_id}")

            if user_id:
                asyncio.create_task(
                    self._send_fcm_notification(
                        session_id=session_id,
                        user_id=user_id,
                        role_name=role_name,
                        session_type="behavioral",
                    )
                )

        except Exception:
            await self._safe_update_session_status(session_id, "pending")
            logger.exception(f"Behavioral pipeline failed for session {session_id}")

        finally:
            deleted = await self._safe_delete_blob(blob_url)
            logger.info(f"Behavioral pipeline finished for session {session_id}; blob deleted: {deleted}")
            print(f"Behavioral pipeline finished for session {session_id}; blob deleted: {deleted}")

    # ------------------------------------------------------------------ #
    #  Technical pipeline — upload → process → notify → delete blob       #
    # ------------------------------------------------------------------ #

    async def queue_technical_upload(
        self,
        session_id: UUID,
        blob_url: str,
        language_preferred: Optional[str] = None,
    ) -> None:
        """
        Called as a background task from the technical notify-upload endpoint.
        Frontend notifies only after upload completes, so processing starts immediately.
        The blob is always deleted when processing finishes (success or failure).
        """
        await self._process_technical_upload(session_id, blob_url, language_preferred)

    async def _process_technical_upload(
        self,
        session_id: UUID,
        blob_url: str,
        language_preferred: Optional[str] = None,
    ) -> None:
        """
        Downloads the audio, transcribes it, extracts audio/text metrics,
        generates the technical report, saves results, then deletes the blob.
        Does NOT call the behavioral pipeline.
        """
        try:
            session = await self.repo.get_session(session_id)
            if not session:
                logger.warning("Technical: session not found, skipping")
                return

            claimed = await self.repo.claim_session_for_processing(session_id)
            if not claimed:
                logger.info("Technical: session already in_progress/completed, skipping duplicate run")
                return

            # Keep user_id for FCM notification (from HEAD)
            user_id = session.get("user_id")

            # Blob readiness check (from origin/main)
            if not await self._is_blob_ready(blob_url, min_size_bytes=1024):
                logger.warning("Technical: blob missing or too small, skipping")
                await self._safe_update_session_status(session_id, "pending")
                return

            role = await self.repo.get_role_by_id(UUID(session["role_id"]))
            if not role:
                logger.error(f"Technical: role not found for session {session_id}")
                await self._safe_update_session_status(session_id, "pending")
                return

            questions = await self.repo.list_technical_questions(UUID(session["role_id"]))
            if self._is_arabic_preference(language_preferred):
                questions = self._use_arabic_question_text(questions)
            if len(questions) < 5:
                logger.error(f"Technical: insufficient questions for session {session_id}")
                await self._safe_update_session_status(session_id, "pending")
                return

            audio_bytes = await self._download_blob_bytes(blob_url)
            transcript_text, transcript_language = await asyncio.to_thread(
                self._transcribe_audio_bytes,
                audio_bytes,
                language_preferred,
            )

            if not transcript_text or not transcript_text.strip():
                raise RuntimeError("Transcription returned empty text")

            role_requirements = (
                role.get("role_requirements")
                or role.get("requirements")
                or role.get("role_description")
                or role.get("description")
                or ""
            )
            report_language = "ar" if self._is_arabic_preference(language_preferred) else "en"
            if report_language != "ar" and self._prefers_arabic_report(session):
                report_language = "ar"
            transcript_for_analysis, was_translated = self._translate_if_needed(
                transcript_text,
                transcript_language,
            )
            questions_list = [q.get("question_text", "") for q in questions]
            metrics = await asyncio.to_thread(
                self._run_technical_audio_metrics, audio_bytes, transcript_for_analysis
            )
            report = await self.technical_reports.build_report(
                role_requirements=role_requirements,
                questions=questions_list,
                user_response=transcript_for_analysis,
                metrics=metrics,
                role_name=role.get("role_name") or "the role",
                report_language=report_language,
                was_translated=was_translated,
            )

            await self.repo.upsert_technical_analysis(
                session_id=session_id,
                technical_report=report,
                transcript=transcript_text,
                video_url=None,
            )

            await self._safe_update_session_status(session_id, "completed")
            logger.info(f"Technical pipeline completed for session {session_id}")

            if user_id:
                asyncio.create_task(
                    self._send_fcm_notification(
                        session_id=session_id,
                        user_id=user_id,
                        role_name=role.get("role_name") if role else None,
                        session_type="technical",
                    )
                )

        except Exception:
            await self._safe_update_session_status(session_id, "pending")
            logger.exception(f"Technical pipeline failed for session {session_id}")

        finally:
            deleted = await self._safe_delete_blob(blob_url)
            logger.info(f"Technical pipeline finished for session {session_id}; blob deleted: {deleted}")
            print(f"Technical pipeline finished for session {session_id}; blob deleted: {deleted}")

    # ------------------------------------------------------------------ #
    #  FCM Push Notification                                               #
    # ------------------------------------------------------------------ #

    async def _send_fcm_notification(
        self,
        session_id: UUID,
        user_id: str,
        role_name: Optional[str],
        session_type: str,
    ) -> None:
        try:
            import firebase_admin
            from firebase_admin import credentials, messaging

            if not firebase_admin._apps:
                cred_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", "")
                if not cred_path or not os.path.exists(cred_path):
                    logger.warning(
                        "FIREBASE_CREDENTIALS_PATH not set or file not found — skipping FCM notification"
                    )
                    return
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)

            token_result = (
                self.repo.client.table("user_fcm_tokens")
                .select("fcm_token")
                .eq("user_id", str(user_id))
                .limit(1)
                .execute()
            )
            if not token_result.data:
                logger.info(f"No FCM token for user {user_id} — skipping notification")
                return

            fcm_token = token_result.data[0]["fcm_token"]
            role_display = role_name or session_type.capitalize()

            message = messaging.Message(
                notification=messaging.Notification(
                    title="Interview Feedback Ready! 🎉",
                    body=f"Your {role_display} interview feedback is now available. Tap to view.",
                ),
                data={
                    "session_id": str(session_id),
                    "session_type": session_type,
                    "type": "interview_feedback",
                    "click_action": "FLUTTER_NOTIFICATION_CLICK",
                },
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="interview_feedback",
                        icon="ic_launcher",
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(badge=1, sound="default"),
                    ),
                ),
                token=fcm_token,
            )

            messaging.send(message)
            logger.info(f"FCM notification sent successfully for session {session_id}")

        except Exception as e:
            logger.error(f"FCM notification failed for session {session_id}: {e}")

    # ------------------------------------------------------------------ #
    #  Read results                                                        #
    # ------------------------------------------------------------------ #

    async def get_analysis(self, session_id: UUID) -> Dict[str, Any]:
        analysis = await self.repo.get_session_analysis(session_id)
        if not analysis:
            raise HTTPException(status_code=404, detail="Analysis not found")
        return analysis

    async def get_session_status(self, session_id: UUID) -> str:
        session = await self.repo.get_session(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        return session.get("status") or "unknown"

    # ------------------------------------------------------------------ #
    #  Azure blob helpers                                                  #
    # ------------------------------------------------------------------ #

    async def _create_video_upload_sas(self, session_id: UUID) -> tuple[str, str, datetime]:
        try:
            storage = get_azure_storage_provider(container_name=settings.AZURE_CONTAINER_NAME)
            blob_name = f"behavioral/video/{session_id}.mp4"
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

    async def _create_audio_upload_sas(self, session_id: UUID) -> tuple[str, str, datetime]:
        try:
            storage = get_azure_storage_provider(container_name=settings.AZURE_CONTAINER_NAME)
            blob_name = f"technical/audio/{session_id}.mp3"
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

    async def _is_blob_ready(self, blob_url: str, min_size_bytes: int = 1) -> bool:
        try:
            credential = settings.STORAGE_ACCOUNT_KEY or None
            blob_client = BlobClient.from_blob_url(blob_url, credential=credential)
            if not blob_client.exists():
                return False
            props = blob_client.get_blob_properties()
            size = getattr(props, "size", None)
            return size is not None and size >= min_size_bytes
        except Exception as e:
            logger.debug(f"Blob readiness check failed: {e}")
            return False

    async def _safe_delete_blob(self, blob_url: str) -> bool:
        try:
            credential = settings.STORAGE_ACCOUNT_KEY or None
            blob_client = BlobClient.from_blob_url(blob_url, credential=credential)
            blob_client.delete_blob(delete_snapshots="include")
            logger.info(f"Blob deleted successfully: {blob_client.blob_name}")
            print(f"Blob deleted successfully: {blob_client.blob_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete blob '{blob_url}': {e}", exc_info=True)
            print(f"Failed to delete blob '{blob_url}': {e}")
            return False

    async def _safe_update_session_status(self, session_id: UUID, status: str) -> None:
        try:
            await self.repo.update_session_status(session_id, status)
        except Exception as e:
            logger.warning(f"Failed to update session status: {e}")

    # ------------------------------------------------------------------ #
    #  ML pipeline runners (sync — called via asyncio.to_thread)          #
    # ------------------------------------------------------------------ #

    def _transcribe_video_bytes(self, video_bytes: bytes) -> str:
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as f:
                f.write(video_bytes)
                temp_path = f.name
            transcript_text, _, _ = self._transcribe_with_fallback(temp_path)
            return transcript_text or ""
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    def _transcribe_audio_bytes(
        self,
        audio_bytes: bytes,
        language_preferred: Optional[str] = None,
    ) -> tuple[str, str]:
        """Write bytes to a temp file, transcribe, return text and language code."""
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
                f.write(audio_bytes)
                temp_path = f.name
            language_code = self._resolve_language_code(language_preferred)
            transcript_text, _, detected_language = self._transcribe_with_fallback(
                temp_path,
                language_preferred,
            )
            return transcript_text or "", detected_language or ""
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    def _run_behavioral_pipeline(
        self,
        video_bytes: bytes,
        language_preferred: Optional[str] = None,
    ) -> Dict[str, Any]:
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as f:
                f.write(video_bytes)
                temp_path = f.name

            device = behavioral_pipeline.torch.device(
                "cuda" if behavioral_pipeline.torch.cuda.is_available() else "cpu"
            )
            (
                vocab, nlp, smile, audio_mins, audio_denom,
                visual, audio, text, baseline, siamese, final,
            ) = behavioral_pipeline.load_all_models(device)

            language_code_override = self._resolve_language_code(language_preferred)
            transcript_text, transcript_words, language_code = self._transcribe_with_fallback(
                temp_path,
                language_preferred,
            )
            if not transcript_text or not transcript_words:
                raise RuntimeError("Transcription failed or missing word timestamps")

            transcript_text_for_model, _ = self._translate_if_needed(
                transcript_text,
                language_code,
            )

            predictions, transcript_text, transcript_words = behavioral_pipeline.predict_video(
                temp_path,
                visual, audio, text, baseline, siamese, final,
                vocab, nlp, smile, audio_mins, audio_denom, device,
                transcript_text=transcript_text_for_model,
                transcript_words=transcript_words,
            )

            return {
                "predictions":    predictions,
                "visual_metrics": behavioral_pipeline.extract_visual_metrics(temp_path),
                "audio_metrics":  behavioral_pipeline.extract_audio_metrics(temp_path),
                "text_metrics":   behavioral_pipeline.extract_text_metrics(transcript_text_for_model),
                "transcript":     transcript_text or "",
            }
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    def _run_technical_audio_metrics(self, audio_bytes: bytes, transcript_text: str) -> Dict[str, Any]:
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
                f.write(audio_bytes)
                temp_path = f.name

            return {
                "audio_metrics": behavioral_pipeline.extract_audio_metrics(temp_path) or {},
                "text_metrics": behavioral_pipeline.extract_text_metrics(transcript_text) or {},
            }
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    def _translate_if_needed(self, transcript_text: str, language_code: str) -> tuple[str, bool]:
        if not transcript_text.strip():
            return transcript_text, False

        if not self._is_arabic_language(language_code) and not self._contains_arabic(transcript_text):
            return transcript_text, False

        translated = self._translate_arabic_to_english(transcript_text)
        return translated, translated != transcript_text

    def _translate_arabic_to_english(self, text: str) -> str:
        return self._translate_text(text, source="ar", target="en")

    def _prefers_arabic_report(self, session: Dict[str, Any]) -> bool:
        for key in ("language", "interview_language", "report_language"):
            value = session.get(key)
            if isinstance(value, str) and self._is_arabic_preference(value):
                return True
        return False

    def _is_arabic_language(self, language_code: str) -> bool:
        return (language_code or "").strip().lower().startswith("ar")

    def _contains_arabic(self, text: str) -> bool:
        return bool(re.search(r"[\u0600-\u06FF]", text))

    def _is_arabic_preference(self, value: Optional[str]) -> bool:
        if not value:
            return False
        return value.strip().lower() in {"ar", "arabic", "ar-eg", "ar-sa"}

    def _resolve_language_code(self, value: Optional[str]) -> Optional[str]:
        if not value:
            return None
        normalized = value.strip().lower()
        if normalized in {"ar", "arabic", "ar-eg", "ar-sa"}:
            return "ar"
        if normalized in {"en", "english", "en-us", "en-gb"}:
            return "en"
        return None

    def _transcribe_with_fallback(
        self,
        video_path: str,
        language_preferred: Optional[str] = None,
    ) -> tuple[str, list[Dict[str, Any]], str]:
        try:
            return self.assembly_transcriber.transcribe_video_file(video_path)
        except Exception as exc:
            logger.warning(f"AssemblyAI transcription failed, falling back to Whisper: {exc}")

        if self.whisper_transcriber is None:
            self.whisper_transcriber = WhisperTranscriptionService()

        return self.whisper_transcriber.transcribe_video_file(video_path)

    def _translate_text(self, text: str, source: str, target: str) -> str:
        if not text.strip():
            return text

        try:
            from deep_translator import GoogleTranslator
        except Exception as exc:
            logger.warning(f"deep-translator not available: {exc}")
            return text

        try:
            return GoogleTranslator(source=source, target=target).translate(text) or text
        except Exception as exc:
            logger.warning(f"Translation failed: {exc}")
            return text

    def _use_arabic_question_text(self, questions: list[Dict[str, Any]]) -> list[Dict[str, Any]]:
        updated_questions = []
        for question in questions:
            question_text_ar = question.get("question_text_ar", "")
            if question_text_ar:
                updated = dict(question)
                updated["question_text"] = question_text_ar
                updated_questions.append(updated)
            else:
                updated_questions.append(question)
        return updated_questions

    # ------------------------------------------------------------------ #
    #  Internal helpers                                                    #
    # ------------------------------------------------------------------ #

    def _extract_behavioral_metrics(self, metrics: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "predictions":    metrics.get("predictions") or {},
            "visual_metrics": metrics.get("visual_metrics") or {},
            "audio_metrics":  metrics.get("audio_metrics") or {},
            "text_metrics":   metrics.get("text_metrics") or {},
        }

    def _extract_score(self, metrics: Dict[str, Any]) -> Optional[float]:
        predictions = metrics.get("predictions")
        if not isinstance(predictions, dict):
            return None
        values = [float(v) for v in predictions.values() if isinstance(v, (int, float))]
        if not values:
            return None
        return float(sum(values) / len(values))