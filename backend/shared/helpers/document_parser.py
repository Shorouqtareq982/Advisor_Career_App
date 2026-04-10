from fastapi import UploadFile
import io
from typing import BinaryIO, Union, Tuple, Dict, Any

from shared.helpers.text_extractor import TextExtractor
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from features.cv_optimization.prompts.data_extraction_prompt import (
    CV_DATA_EXTRACTOR,
    JOB_DATA_EXTRACTOR,
)
from features.cv_optimization.schemas import CVData, JobData


class DocumentParser:
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
        self.textExtractor = TextExtractor()

    async def _extract_text(
        self,
        file: Union[str, io.BytesIO, BinaryIO, UploadFile]
    ) -> str:
        """
        Extract text from PDF, DOCX, TXT, or images.
        Falls back to OCR if needed (depending on TextExtractor implementation).
        """
        text = ""

        try:
            text = await TextExtractor.extract_text(file)
        except Exception as e:
            print(f"Error extracting text: {e}")

        return text or ""

    async def parse_cv(
        self,
        file: Union[str, io.BytesIO, BinaryIO, UploadFile]
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Parse a CV file into:
        - extracted raw text
        - structured parsed content dict
        """
        try:
            text = await self._extract_text(file)

            if not text:
                print("No text extracted from CV.")
                return "", {}

            parsed_content = await self.parse_cv_text(text)
            return text, parsed_content

        except Exception as e:
            print(f"Error parsing CV: {e}")
            return "", {}

    async def parse_cv_text(self, cv_text: str) -> Dict[str, Any]:
        """
        Parse CV text into structured data using LLM.

        Always returns a dict.
        If parsing fails or response is invalid, returns {} instead of crashing.
        """
        try:
            parsed_content = await self.llm.get_response(
                prompt=CV_DATA_EXTRACTOR.format(cv_text=cv_text),
                need_json_output=True,
                schema=CVData
            )

            if not parsed_content:
                print("LLM returned empty response for CV text parsing.")
                return {}

            # Pydantic model
            if isinstance(parsed_content, CVData):
                return parsed_content.model_dump()

            # Already dict
            if isinstance(parsed_content, dict):
                return parsed_content

            # Unexpected type مثل string/raw content
            print(f"Unexpected parsed_content type in parse_cv_text: {type(parsed_content)}")
            return {}

        except Exception as e:
            print(f"Error parsing CV text: {e}")
            return {}

    async def parse_job_description(self, jd_text: str) -> Dict[str, Any]:
        """
        Parse job description text into structured data using LLM.

        Always returns a dict.
        """
        try:
            parsed_content = await self.llm.get_response(
                prompt=JOB_DATA_EXTRACTOR.format(job_description=jd_text),
                need_json_output=True,
                schema=JobData
            )

            if not parsed_content:
                print("LLM returned empty response for job description parsing.")
                return {}

            # Pydantic model
            if isinstance(parsed_content, JobData):
                return parsed_content.model_dump()

            # Already dict
            if isinstance(parsed_content, dict):
                return parsed_content

            print(f"Unexpected parsed_content type in parse_job_description: {type(parsed_content)}")
            return {}

        except Exception as e:
            print(f"Error parsing job description: {e}")
            return {}