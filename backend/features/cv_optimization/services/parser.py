from fastapi import Depends
import io
from typing import BinaryIO, Union
from pdfplumber import pdfplumber
from docx import Document
from PIL import Image
import pytesseract

from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from prompts import CV_DATA_EXTRACTOR, JOB_DATA_EXTRACTOR
from schemas import CVData, JobData


class DocumentParser:
    def __init__(self, llm: LLMProvider = Depends(create_llm_provider)):
        self.llm = llm

    def _extract_text(self, file: Union[str, io.BytesIO, BinaryIO]) -> str:
        """
        Extract text from PDF, DOCX, TXT, or images.
        Automatically falls back to OCR for scanned PDFs/images.
        Supports Arabic (requires tesseract Arabic language pack).
        """
        text = ""
        try:
            file_name = getattr(file, 'name', None) if isinstance(file, io.BytesIO) else file

            # PDF
            if file_name and file_name.lower().endswith(".pdf"):
                with pdfplumber.open(file) as pdf:
                    for page in pdf.pages:
                        page_text = page.extract_text()
                        if page_text:
                            text += page_text + "\n"
                        else:
                            # OCR fallback
                            image = page.to_image(resolution=300).original
                            text += pytesseract.image_to_string(image, lang="ara+eng") + "\n"

            # DOCX
            elif file_name and file_name.lower().endswith(".docx"):
                doc = Document(file)
                text = "\n".join([p.text for p in doc.paragraphs])

            # TXT
            elif file_name and file_name.lower().endswith(".txt"):
                if isinstance(file, io.BytesIO):
                    file.seek(0)
                    text = file.read().decode("utf-8")
                else:
                    with open(file, "r", encoding="utf-8") as f:
                        text = f.read()

            # Images
            elif file_name and file_name.lower().endswith((".png", ".jpg", ".jpeg", ".bmp", ".tiff")):
                img = Image.open(file) if not isinstance(file, io.BytesIO) else Image.open(file)
                text = pytesseract.image_to_string(img, lang="ara+eng")

            else:
                raise ValueError("Unsupported file type for text extraction.")

        except Exception as e:
            print(f"Error extracting text: {e}")

        return text

    def parse_cv(self, file: Union[str, io.BytesIO, BinaryIO]) -> dict:
        """
        Parses a CV file into structured data using LLM.
        Returns a dictionary with extracted information.
        """
        try:
            text = self._extract_text(file)
            # Send text to LLM for structured extraction
            parsed_content = self.llm.get_response(
                prompt=CV_DATA_EXTRACTOR.format(cv_text=text),
                need_json_output=True,
                schema=CVData
            )

            # Validate and return the structured data
            if not parsed_content:
                print("LLM returned empty response for CV parsing.")
                return {}
            
            return parsed_content.dict() if isinstance(parsed_content, CVData) else parsed_content
        except Exception as e:
            print(f"Error parsing CV: {e}")
            return {}

    def parse_job_description(self, jd_text: str) -> dict:
        """
        Parses a job description text into structured data using LLM.
        Returns a dictionary with extracted information.
        """
        try:
            parsed_content = self.llm.get_response(
                prompt=JOB_DATA_EXTRACTOR.format(jd_text=jd_text),
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
