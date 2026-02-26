from fastapi import Depends, UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile
import io
from typing import BinaryIO, Union
import pdfplumber
from docx import Document
from PIL import Image
import pytesseract

from shared.helpers.text_extractor import TextExtractor
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from features.cv_optimization.prompts.data_extraction_prompt import CV_DATA_EXTRACTOR, JOB_DATA_EXTRACTOR#from ...features.cv_optimization.prompts import CV_DATA_EXTRACTOR, JOB_DATA_EXTRACTOR
from features.cv_optimization.schemas import CVData, JobData

class DocumentParser:
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
        self.textExtractor = TextExtractor()

    async def _extract_text(self, file: Union[str, io.BytesIO, BinaryIO, UploadFile]) -> str:
        """
        Extract text from PDF, DOCX, TXT, or images.
        Automatically falls back to OCR for scanned PDFs/images.
        Supports Arabic (requires tesseract Arabic language pack).
        """
        text = ""

        try:
            text = await TextExtractor.extract_text(file)

        except Exception as e:
            print(f"Error extracting text: {e}")

        return text

    async def parse_cv(self, file: Union[str, io.BytesIO, BinaryIO, UploadFile]) -> tuple[str,CVData]:
        """
        Parses a CV file into structured data using LLM.
        Returns a dictionary with extracted information.
        """
        try:
            text = await self._extract_text(file)
            # Send text to LLM for structured extraction
            parsed_content = self.llm.get_response(
                prompt=CV_DATA_EXTRACTOR.format(cv_text=text),
                need_json_output=True,
                schema=CVData
            )

            # Validate and return the structured data
            if not parsed_content:
                print("LLM returned empty response for CV parsing.")
                return text, None
            
            return text, parsed_content.dict() if isinstance(parsed_content, CVData) else parsed_content
        except Exception as e:
            print(f"Error parsing CV: {e}")
            return text, None

    def parse_job_description(self, jd_text: str) -> JobData:
        """
        Parses a job description text into structured data using LLM.
        Returns a dictionary with extracted information.
        """
        try:
            parsed_content = self.llm.get_response(
                prompt=JOB_DATA_EXTRACTOR.format(job_description=jd_text),
                need_json_output=True,
                schema= JobData
            )
            if not parsed_content:
                print("LLM returned empty response for job description parsing.")
                return {}
            
            return parsed_content.dict() if isinstance(parsed_content, JobData) else parsed_content
        except Exception as e:
            print(f"Error parsing job description: {e}")
            return {}
