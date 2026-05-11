import asyncio
import json
import logging
import re
from pathlib import Path
from typing import Any, Dict, Optional

from fastapi import HTTPException

from features.mock_interview.schemas.mock_interview_schemas import BehavioralGeminiFeedback
from shared.providers.llm_models.gemini import Gemini

logger = logging.getLogger(__name__)


class BehavioralReportService:
    def __init__(self, gemini: Gemini, prompts_dir: Path):
        self.gemini = gemini
        self.prompts_dir = prompts_dir

    async def build_report(self, metrics: Dict[str, Any], role_name: Optional[str] = None) -> str:
        template = self._load_prompt("behavioral_report_prompt.txt")

        metrics_json = json.dumps(metrics, indent=2)
        prompt = template.replace("{{METRICS_JSON}}", metrics_json)
        prompt = prompt.replace("{{ROLE_NAME}}", role_name or "")

        feedback = await self._get_gemini_feedback(prompt)
        return self._format_feedback(feedback)

    def _load_prompt(self, filename: str) -> str:
        prompt_path = self.prompts_dir / filename
        if not prompt_path.exists():
            raise HTTPException(status_code=500, detail=f"Prompt file missing: {filename}")
        return prompt_path.read_text(encoding="utf-8")

    async def _get_gemini_feedback(self, prompt: str) -> BehavioralGeminiFeedback:
        """Fetch plain-text feedback from Gemini and parse into structured format."""
        last_error: Optional[Exception] = None

        section_patterns = {
            "strengths": r"\*\*Strengths\*\*\s*(.*?)(?=\*\*Weaknesses\*\*|\Z)",
            "weaknesses": r"\*\*Weaknesses\*\*\s*(.*?)(?=\*\*Suggestions\*\*|\Z)",
            "suggestions": r"\*\*Suggestions\*\*\s*(.*?)(?=\Z)",
        }

        for attempt in range(3):
            result = await self.gemini.get_response(
                prompt=prompt,
                need_json_output=False,
                schema=None,
                expecting_longer_output=True,
            )

            if result is None:
                last_error = HTTPException(status_code=422, detail="Gemini returned no response")
            elif isinstance(result, str):
                extracted: Dict[str, str] = {}
                for key, pattern in section_patterns.items():
                    match = re.search(pattern, result, re.DOTALL | re.IGNORECASE)
                    if match:
                        extracted[key] = match.group(1).strip()

                if len(extracted) == 3:
                    return BehavioralGeminiFeedback(**extracted)

                last_error = ValueError("Could not parse sections from Gemini response")
                logger.error(
                    f"Section parsing failed on attempt {attempt + 1}. Raw output:\n{result}"
                )
            else:
                last_error = HTTPException(status_code=422, detail="Unexpected Gemini response type")

            if attempt < 2:
                await asyncio.sleep(5)

        if isinstance(last_error, HTTPException):
            raise last_error
        raise HTTPException(status_code=422, detail="Failed to parse Gemini feedback after 3 attempts")

    def _format_feedback(self, feedback: BehavioralGeminiFeedback) -> str:
        """Format the parsed feedback as a readable report (no raw metrics included)."""
        def to_two_bullets(text: str) -> str:
            items = []
            for line in text.splitlines():
                stripped = line.strip()
                if not stripped:
                    continue
                if stripped.startswith(('-', '*', '•')):
                    stripped = stripped.lstrip('-*•').strip()
                items.append(stripped)
                if len(items) == 2:
                    break
            if len(items) < 2:
                paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
                for paragraph in paragraphs:
                    if paragraph not in items:
                        items.append(paragraph)
                    if len(items) == 2:
                        break
            return "\n".join(f"- {item}" for item in items[:2])

        lines = [
            "**Strengths**\n" + to_two_bullets(feedback.strengths),
            "**Weaknesses**\n" + to_two_bullets(feedback.weaknesses),
            "**Suggestions**\n" + to_two_bullets(feedback.suggestions),
        ]

        return "\n\n".join(lines)
