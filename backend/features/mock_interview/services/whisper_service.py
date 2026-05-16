import logging
import os
from typing import List, Tuple, Optional, Dict, Any

from faster_whisper import WhisperModel

from core.config import BACKEND_DIR, settings

logger = logging.getLogger(__name__)


class WhisperTranscriptionService:
    def __init__(
        self,
        model_size: str = "medium",
        device: str = "cpu",
        compute_type: str = "int8",
    ):
        cache_dir = settings.WHISPER_MODEL_CACHE_DIR or str(BACKEND_DIR / ".cache" / "whisper")
        os.makedirs(cache_dir, exist_ok=True)
        os.environ.setdefault("HF_HOME", cache_dir)
        os.environ.setdefault("HUGGINGFACE_HUB_CACHE", os.path.join(cache_dir, "hub"))
        self.model = WhisperModel(model_size, device=device, compute_type=compute_type)

    def transcribe_video_file(
        self,
        video_path: str,
        language_code: Optional[str] = None,
        beam_size: int = 5,
    ) -> Tuple[str, List[Dict[str, Any]], str]:
        segments, info = self.model.transcribe(
            video_path,
            beam_size=beam_size,
            language=language_code,
            word_timestamps=True,
        )

        words: List[Dict[str, Any]] = []
        transcript_parts: List[str] = []

        for segment in segments:
            if segment.text:
                transcript_parts.append(segment.text.strip())
            if segment.words:
                for word in segment.words:
                    word_text = str(word.word or "").strip()
                    if word_text and word.start is not None:
                        words.append({"text": word_text, "start": int(word.start * 1000)})

        transcript_text = " ".join(transcript_parts).strip()
        detected_language = str(getattr(info, "language", "") or "").lower()
        return transcript_text, words, detected_language
