import logging
import os
import re
import subprocess
import time
from typing import List, Tuple, Optional, Dict, Any

import requests

from core.config import settings

logger = logging.getLogger(__name__)


class AssemblyAIService:
    def __init__(self, api_key: Optional[str] = None, base_url: str = "https://api.assemblyai.com"):
        self.api_key = api_key or settings.ASSEMBLYAI_API_KEY or os.getenv("ASSEMBLYAI_API_KEY", "")
        self.base_url = base_url

    def transcribe_video_file(
        self,
        video_path: str,
        max_wait_seconds: int = 600,
        poll_interval_seconds: int = 3,
    ) -> Tuple[str, List[Dict[str, Any]]]:
        if not self.api_key:
            return self._fallback_transcribe(video_path, translate=True)

        duration_seconds = self._get_media_duration_seconds(video_path)
        if duration_seconds:
            max_wait_seconds = max(max_wait_seconds, int(duration_seconds * 3))

        audio_bytes = self._extract_audio_wav(video_path)
        if not audio_bytes:
            return self._fallback_transcribe(video_path, translate=True)

        headers = {"authorization": self.api_key}
        upload_response = requests.post(
            f"{self.base_url}/v2/upload",
            headers=headers,
            data=audio_bytes,
            timeout=180,
        )
        if upload_response.status_code != 200:
            return self._fallback_transcribe(video_path, translate=True)

        audio_url = upload_response.json().get("upload_url")
        if not audio_url:
            return self._fallback_transcribe(video_path, translate=True)

        transcript_payload = {
            "audio_url": audio_url,
            "language_detection": True,
            "punctuate": True,
            "speech_models": ["universal-3-pro", "universal-2"],
        }
        transcript_response = requests.post(
            f"{self.base_url}/v2/transcript",
            json=transcript_payload,
            headers=headers,
            timeout=60,
        )
        if transcript_response.status_code != 200:
            return self._fallback_transcribe(video_path, translate=True)

        transcript_id = transcript_response.json().get("id")
        if not transcript_id:
            return self._fallback_transcribe(video_path, translate=True)

        status_url = f"{self.base_url}/v2/transcript/{transcript_id}"
        deadline = time.time() + max_wait_seconds
        while time.time() < deadline:
            result = requests.get(status_url, headers=headers, timeout=30).json()
            status = result.get("status")
            if status == "completed":
                language_code = (result.get("language_code") or "").lower()
                if language_code.startswith("ar"):
                    return self._fallback_transcribe(video_path, translate=True)
                return result.get("text", ""), result.get("words") or []
            if status == "error":
                return self._fallback_transcribe(video_path, translate=True)
            time.sleep(poll_interval_seconds)

        return self._fallback_transcribe(video_path, translate=True)

    def _fallback_transcribe(self, video_path: str, translate: bool) -> Tuple[str, List[Dict[str, Any]]]:
        try:
            import whisper  # type: ignore
        except Exception as exc:
            logger.error(f"Local transcription unavailable: {exc}")
            return "", []

        try:
            model = whisper.load_model("tiny")
            task = "translate" if translate else None
            result = model.transcribe(
                video_path,
                word_timestamps=True,
                fp16=False,
                task=task,
            )
            text = result.get("text", "") or ""
            words = self._collect_words(result)
            return text, words
        except Exception as exc:
            logger.error(f"Local transcription failed: {exc}")
            return "", []

    def _collect_words(self, result: Dict[str, Any]) -> List[Dict[str, Any]]:
        words: List[Dict[str, Any]] = []
        for segment in result.get("segments", []) or []:
            segment_words = segment.get("words")
            if segment_words:
                for word in segment_words:
                    word_text = str(word.get("word", "")).strip()
                    start = word.get("start")
                    if word_text and start is not None:
                        words.append({"text": word_text, "start": int(start * 1000)})
            else:
                segment_text = str(segment.get("text", "")).strip()
                start = segment.get("start")
                if segment_text and start is not None:
                    for token in segment_text.split():
                        words.append({"text": token, "start": int(start * 1000)})
        return words

    def _contains_arabic(self, text: str) -> bool:
        return bool(re.search(r"[\u0600-\u06FF]", text))

    def _extract_audio_wav(self, video_path: str) -> bytes:
        cmd = [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            video_path,
            "-ac",
            "1",
            "-ar",
            "16000",
            "-f",
            "wav",
            "-",
        ]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0 or not result.stdout:
            return b""
        return result.stdout

    def _get_media_duration_seconds(self, video_path: str) -> Optional[float]:
        cmd = [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            video_path,
        ]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0 or not result.stdout:
            return None

        try:
            return float(result.stdout.decode("utf-8").strip())
        except ValueError:
            return None
