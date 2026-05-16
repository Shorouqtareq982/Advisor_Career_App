import logging
import os
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
    ) -> Tuple[str, List[Dict[str, Any]], str]:
        if not self.api_key:
            raise RuntimeError("ASSEMBLYAI_API_KEY is not set")

        duration_seconds = self._get_media_duration_seconds(video_path)
        if duration_seconds:
            max_wait_seconds = max(max_wait_seconds, int(duration_seconds * 3))

        audio_bytes = self._extract_audio_wav(video_path)
        if not audio_bytes:
            raise RuntimeError("Failed to extract audio for AssemblyAI")

        headers = {"authorization": self.api_key}
        upload_response = requests.post(
            f"{self.base_url}/v2/upload",
            headers=headers,
            data=audio_bytes,
            timeout=180,
        )
        upload_response.raise_for_status()

        audio_url = upload_response.json().get("upload_url")
        if not audio_url:
            raise RuntimeError("AssemblyAI upload response missing upload_url")

        transcript_payload = {
            "audio_url": audio_url,
            "punctuate": True,
            "language_detection": True,
            "speech_models": ["universal"],
        }
        transcript_response = requests.post(
            f"{self.base_url}/v2/transcript",
            json=transcript_payload,
            headers=headers,
            timeout=60,
        )
        transcript_response.raise_for_status()

        transcript_id = transcript_response.json().get("id")
        if not transcript_id:
            raise RuntimeError("AssemblyAI transcript response missing id")

        status_url = f"{self.base_url}/v2/transcript/{transcript_id}"
        deadline = time.time() + max_wait_seconds
        while time.time() < deadline:
            result = requests.get(status_url, headers=headers, timeout=30).json()
            status = result.get("status")
            if status == "completed":
                language_code = (result.get("language_code") or "").lower()
                return result.get("text", ""), result.get("words") or [], language_code
            if status == "error":
                raise RuntimeError(result.get("error") or "AssemblyAI error")
            time.sleep(poll_interval_seconds)

        raise RuntimeError("Timed out waiting for AssemblyAI transcription")

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
