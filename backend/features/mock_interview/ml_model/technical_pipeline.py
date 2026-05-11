import json
from typing import Any, Dict, List


def extract_full_transcript_text(response_payload: str) -> str:
	if not response_payload:
		return ""

	try:
		payload = json.loads(response_payload)
		if isinstance(payload, dict):
			text = payload.get("text", "")
			if text:
				return text.strip()
			words = payload.get("words", [])
			if isinstance(words, list) and words:
				joined = " ".join(
					str(item.get("text", "")).strip()
					for item in words
					if isinstance(item, dict)
				)
				return joined.strip()
			return ""
		if isinstance(payload, str):
			return payload.strip()
		return ""
	except json.JSONDecodeError:
		return response_payload.strip()


def validate_full_transcript_text(text: str) -> None:
	if not text or not text.strip():
		raise ValueError("Transcript text is empty")


def build_questions_text(questions: List[Dict[str, Any]], limit: int = 7) -> str:
	if len(questions) < limit:
		raise ValueError("Insufficient questions for technical analysis")

	selected = questions[:limit]
	lines = [
		f"Q{i + 1}: {item.get('question_text', '')}" for i, item in enumerate(selected)
	]
	return "\n".join(lines)
