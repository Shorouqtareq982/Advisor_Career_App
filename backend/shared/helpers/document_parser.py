from fastapi import UploadFile
import io
from typing import BinaryIO, Union, Tuple, Dict, Any

from shared.helpers.text_extractor import TextExtractor
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from shared.helpers.cv_pii_masker import pii_pipeline, unmask_text
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
        file: Union[str, io.BytesIO, BinaryIO, UploadFile],
        mask_pii: bool = True,
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

            parsed_content = await self.parse_cv_text(text, mask_pii=mask_pii)
            return text , parsed_content

        except Exception as e:
            print(f"Error parsing CV: {e}")
            return "", {}

    async def parse_cv_text(self, cv_text: str, mask_pii: bool = True) -> Tuple[str, Dict[str, Any]]:
        """
        Parse CV text into structured data using LLM.

        Always returns a dict.
        If parsing fails or response is invalid, returns {} instead of crashing.
        """
        try:
            text_to_process, mask_map = self._prepare_text(cv_text, mask_pii)

            parsed = await self._call_llm(text_to_process)

            parsed_dict = self._normalize_llm_output(parsed)

            if not parsed_dict:
                return text_to_process, {}

            if mask_pii and mask_map:
                parsed_dict = self._unmask_parsed_output(parsed_dict, mask_map)

            return parsed_dict

        except Exception as e:
            print(f"Error parsing CV text: {e}")
            return text_to_process, {}
        
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

    # ─────────────────────────────────────────────
    # Helpers (Single Responsibility)
    # ─────────────────────────────────────────────

    def _prepare_text(self, cv_text: str, mask_pii: bool):
        """Mask text if needed."""
        if not mask_pii:
            return cv_text, None

        mask_result = pii_pipeline(cv_text)
        return mask_result["masked_text"], mask_result["mask_map"]


    async def _call_llm(self, text: str) -> Union[Dict, "CVData", None]:
        """Call LLM safely."""
        response = await self.llm.get_response(
            prompt=CV_DATA_EXTRACTOR.format(cv_text=text),
            need_json_output=True,
            schema=CVData
        )

        if not response:
            print("LLM returned empty response.")
            return None

        return response


    def _normalize_llm_output(self, parsed: Union[Dict, "CVData", None]) -> Dict[str, Any]:
        """Ensure output is always a dict."""
        if parsed is None:
            return {}

        if isinstance(parsed, CVData):
            return parsed.model_dump()

        if isinstance(parsed, dict):
            return parsed

        print(f"Unexpected parsed_content type: {type(parsed)}")
        return {}


    def _unmask_parsed_output(self, data: Dict[str, Any], mask_map: Dict[str, str]) -> Dict[str, Any]:
        """Recursively unmask all string values."""
        def unmask(value):
            if isinstance(value, str):
                return unmask_text(value, mask_map)
            if isinstance(value, dict):
                return {k: unmask(v) for k, v in value.items()}
            if isinstance(value, list):
                return [unmask(v) for v in value]
            return value

        return unmask(data)
