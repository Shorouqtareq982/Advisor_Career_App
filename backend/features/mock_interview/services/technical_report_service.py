import asyncio
import json
import logging
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import HTTPException

from core.config import settings
from features.mock_interview.schemas.mock_interview_schemas import GeminiFeedback
from shared.providers.llm_models.gemini import Gemini
from shared.providers.llm_models.groq_provider import GroqProvider

logger = logging.getLogger(__name__)


class TechnicalReportService:
    def __init__(self, gemini: Gemini, prompts_dir: Path, groq: Optional[GroqProvider] = None):
        self.gemini = gemini
        self.groq = groq
        self.prompts_dir = prompts_dir
        self.request_delay_seconds = settings.GEMINI_REQUEST_DELAY_SECONDS or 2.0
        self.groq_delay_seconds = settings.GROQ_REQUEST_DELAY_SECONDS or self.request_delay_seconds

    async def build_report(
        self,
        role_requirements: str,
        questions: List[str],
        user_response: str,
        metrics: Dict[str, Any],
        role_name: str,
        report_language: str = "en",
        was_translated: bool = False,
    ) -> str:
        """Constructs the prompt and generates the report."""
        template = self._load_prompt("technical_report_prompt.txt")

        questions_text = "\n".join(f"- {q}" for q in questions)
        metrics_json = json.dumps(metrics, indent=2)
        prompt = template.replace("{{ROLE_NAME}}", role_name)
        prompt = prompt.replace("{{ROLE_REQUIREMENTS}}", role_requirements)
        prompt = prompt.replace("{{QUESTIONS}}", questions_text)
        prompt = prompt.replace("{{USER_RESPONSE}}", user_response)
        prompt = prompt.replace("{{METRICS_JSON}}", metrics_json)
        prompt = self._apply_language_instructions(
            prompt,
            report_language=report_language,
            was_translated=was_translated,
        )

        feedback = await self._get_feedback(prompt)
        return self._format_feedback(feedback, report_language=report_language)

    def _load_prompt(self, filename: str) -> str:
        prompt_path = self.prompts_dir / filename
        if not prompt_path.exists():
            raise HTTPException(status_code=500, detail=f"Prompt file missing: {filename}")
        return prompt_path.read_text(encoding="utf-8")

    async def _get_feedback(self, prompt: str) -> GeminiFeedback:
        """Fetch plain-text feedback from Gemini and parse into structured format."""
        last_error: Optional[Exception] = None

        for attempt in range(2):
            result = await self.gemini.get_response(
                prompt=prompt,
                need_json_output=False,
                schema=None,
                expecting_longer_output=True,
            )

            extracted = self._parse_sections(result)
            if extracted:
                return GeminiFeedback(**extracted)

            if result is None:
                last_error = HTTPException(status_code=422, detail="Gemini returned no response")
            elif isinstance(result, str):
                last_error = ValueError("Could not parse sections from Gemini response")
                logger.error(
                    f"Section parsing failed on attempt {attempt + 1}. Raw output:\n{result}"
                )
            else:
                last_error = HTTPException(status_code=422, detail="Unexpected Gemini response type")

            await asyncio.sleep(self.request_delay_seconds)

        if self.groq:
            await asyncio.sleep(self.groq_delay_seconds)
            for attempt in range(2):
                result = await self.groq.get_response(
                    prompt=prompt,
                    need_json_output=False,
                    schema=None,
                    expecting_longer_output=True,
                )

                extracted = self._parse_sections(result)
                if extracted:
                    return GeminiFeedback(**extracted)

                if result is None:
                    last_error = HTTPException(status_code=422, detail="Groq returned no response")
                elif isinstance(result, str):
                    last_error = ValueError("Could not parse sections from Groq response")
                    logger.error(
                        f"Groq section parsing failed on attempt {attempt + 1}. Raw output:\n{result}"
                    )
                else:
                    last_error = HTTPException(status_code=422, detail="Unexpected Groq response type")

                await asyncio.sleep(self.groq_delay_seconds)

        if isinstance(last_error, HTTPException):
            raise last_error
        raise HTTPException(status_code=422, detail="Failed to parse report feedback")

    def _parse_sections(self, result: Optional[Any]) -> Optional[Dict[str, str]]:
        if not isinstance(result, str):
            return None

        section_patterns = {
            "strengths": r"\*\*(Strengths|نقاط القوة)\*\*\s*(.*?)(?=\*\*(Weaknesses|نقاط الضعف)\*\*|\Z)",
            "weaknesses": r"\*\*(Weaknesses|نقاط الضعف)\*\*\s*(.*?)(?=\*\*(Suggestions|التوصيات|الاقتراحات)\*\*|\Z)",
            "suggestions": r"\*\*(Suggestions|التوصيات|الاقتراحات)\*\*\s*(.*?)(?=\Z)",
        }

        extracted: Dict[str, str] = {}
        for key, pattern in section_patterns.items():
            match = re.search(pattern, result, re.DOTALL | re.IGNORECASE)
            if match:
                extracted[key] = match.group(2).strip()

        if len(extracted) == 3:
            return extracted
        return None

    def _apply_language_instructions(self, prompt: str, report_language: str, was_translated: bool) -> str:
        instructions = []
        if report_language == "ar":
            instructions.append(
                "Respond using the headings **Strengths**, **Weaknesses**, and **Suggestions**, "
                "but write the content in Arabic."
            )
        if was_translated:
            instructions.append("Note: The user response was translated from Arabic to English.")

        if not instructions:
            return prompt

        return f"{prompt}\n\n" + "\n".join(instructions)

    def _format_feedback(self, feedback: GeminiFeedback, report_language: str) -> str:
        """Formats the structured feedback into a bulleted list report."""
        heading_map = {
            "en": {
                "strengths": "**Strengths**",
                "weaknesses": "**Weaknesses**",
                "suggestions": "**Suggestions**",
            },
            "ar": {
                "strengths": "**نقاط القوة**",
                "weaknesses": "**نقاط الضعف**",
                "suggestions": "**التوصيات**",
            },
        }
        headings = heading_map.get(report_language, heading_map["en"])

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
            f"{headings['strengths']}\n" + to_two_bullets(feedback.strengths),
            f"{headings['weaknesses']}\n" + to_two_bullets(feedback.weaknesses),
            f"{headings['suggestions']}\n" + to_two_bullets(feedback.suggestions),
        ]
        return "\n\n".join(lines)
