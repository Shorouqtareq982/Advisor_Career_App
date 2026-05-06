import json
from typing import Any, Dict, List


def validate_transcript_words(response_payload: str) -> List[Dict[str, Any]]:
	try:
		payload = json.loads(response_payload)
	except json.JSONDecodeError as exc:
		raise ValueError("Transcript payload must be JSON") from exc

	words = payload.get("words") if isinstance(payload, dict) else None
	if not isinstance(words, list):
		raise ValueError("Transcript payload missing words array")
	if not words:
		raise ValueError("Transcript words array is empty")

	for index, word in enumerate(words):
		if not isinstance(word, dict):
			raise ValueError(f"Word at index {index} must be an object")
		if not word.get("text"):
			raise ValueError(f"Word at index {index} is missing text")
		if word.get("start") is None:
			raise ValueError(f"Word at index {index} is missing start")

	return words


def chunk_transcript_words(response_payload: str) -> List[str]:
	words = validate_transcript_words(response_payload)

	chunks: List[List[str]] = [[]]
	for word in words:
		start = word.get("start")
		if start is not None and start > 0 and start % 30000 == 0:
			chunks.append([])

		chunks[-1].append(word["text"])

	return [" ".join(chunk).strip() for chunk in chunks if " ".join(chunk).strip()]
