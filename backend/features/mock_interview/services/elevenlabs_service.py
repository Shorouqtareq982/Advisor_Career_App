import json
import uuid
from io import BytesIO
from typing import Optional

import requests

from core.config import settings
from shared.providers.storage.azure_blob_storage import get_azure_storage_provider


class ElevenLabsService:
    def __init__(self):
        self.api_key = settings.ELEVENLABS_API_KEY
        self.base_url = "https://api.elevenlabs.io/v1"

    def synthesize(self, text: str, voice_id: Optional[str] = None) -> bytes:
        if not self.api_key:
            raise ValueError("ElevenLabs API key is not configured")

        voice = voice_id or "EXAVITQu4vr4xnSDxMaL"
        url = f"{self.base_url}/text-to-speech/{voice}"
        headers = {
            "xi-api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        }
        payload = {
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": {
                "stability": 0.5,
                "similarity_boost": 0.75,
            },
        }
        response = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
        if response.status_code != 200:
            raise RuntimeError(f"ElevenLabs TTS failed: {response.status_code} {response.text}")
        return response.content

    def synthesize_to_azure(
        self,
        text: str,
        container_name: str,
        folder: str = "mock_interview/tts",
        voice_id: Optional[str] = None,
    ) -> dict:
        audio_bytes = self.synthesize(text=text, voice_id=voice_id)
        storage = get_azure_storage_provider(container_name=container_name)
        filename = f"{uuid.uuid4()}.mp3"
        return storage.upload_file(
            file=BytesIO(audio_bytes),
            filename=filename,
            folder=folder,
            content_type="audio/mpeg",
        )
