import time
from typing import Optional

import requests

from core.config import settings


class AssemblyAIService:
    def __init__(self):
        self.api_key = settings.ASSEMBLYAI_API_KEY
        self.base_url = "https://api.assemblyai.com"

    def _headers(self) -> dict:
        return {"authorization": self.api_key}

    def transcribe_file(self, file_path: str, timeout_seconds: int = 300) -> str:
        if not self.api_key:
            raise ValueError("AssemblyAI API key is not configured")

        with open(file_path, "rb") as f:
            upload = requests.post(
                f"{self.base_url}/v2/upload",
                headers=self._headers(),
                data=f,
                timeout=120,
            )
        if upload.status_code != 200:
            raise RuntimeError(f"AssemblyAI upload failed: {upload.status_code} {upload.text}")

        audio_url = upload.json().get("upload_url")
        if not audio_url:
            raise RuntimeError("AssemblyAI upload_url missing")

        start = requests.post(
            f"{self.base_url}/v2/transcript",
            headers=self._headers(),
            json={
                "audio_url": audio_url,
                "language_detection": True,
                "punctuate": True,
                "speech_models": ["universal-3-pro", "universal-2"],
            },
            timeout=60,
        )
        if start.status_code != 200:
            raise RuntimeError(f"AssemblyAI transcript start failed: {start.status_code} {start.text}")

        transcript_id = start.json().get("id")
        if not transcript_id:
            raise RuntimeError("AssemblyAI transcript id missing")

        deadline = time.time() + timeout_seconds
        status_url = f"{self.base_url}/v2/transcript/{transcript_id}"

        while time.time() < deadline:
            poll = requests.get(status_url, headers=self._headers(), timeout=30)
            data = poll.json()
            status = data.get("status")
            if status == "completed":
                return data.get("text", "") or ""
            if status == "error":
                raise RuntimeError(f"AssemblyAI error: {data.get('error')}")
            time.sleep(3)

        raise TimeoutError("AssemblyAI transcription timed out")
