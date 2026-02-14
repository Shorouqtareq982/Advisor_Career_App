from fastapi import Depends, UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile
import io
from typing import BinaryIO, Union
import pdfplumber
from docx import Document
from PIL import Image
import pytesseract

from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from ..prompts import CV_DATA_EXTRACTOR, JOB_DATA_EXTRACTOR
from ..schemas import CVData, JobData


class DocumentParser:
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()

    def _extract_text(self, file: Union[str, io.BytesIO, BinaryIO, UploadFile]) -> str:
        """
        Extract text from PDF, DOCX, TXT, or images.
        Automatically falls back to OCR for scanned PDFs/images.
        Supports Arabic (requires tesseract Arabic language pack).
        """
        text = ""

        try:
            file_name = None
            file_obj = file

            # ✅ Handle UploadFile
            if isinstance(file, (UploadFile, StarletteUploadFile)):
                file_name = file.filename
                file_obj = file.file  # this is a BinaryIO stream
                file_obj.seek(0)

            # BytesIO case
            elif isinstance(file, io.BytesIO):
                file_name = getattr(file, "name", None)
                file.seek(0)

            # string path case
            elif isinstance(file, str):
                file_name = file

            # ========================
            # PDF
            # ========================
            if file_name and file_name.lower().endswith(".pdf"):
                with pdfplumber.open(file_obj) as pdf:
                    for page in pdf.pages:
                        page_text = page.extract_text()
                        if page_text:
                            text += page_text + "\n"
                        else:
                            image = page.to_image(resolution=300).original
                            text += pytesseract.image_to_string(image, lang="ara+eng") + "\n"

            # ========================
            # DOCX
            # ========================
            elif file_name and file_name.lower().endswith(".docx"):
                doc = Document(file_obj)
                text = "\n".join([p.text for p in doc.paragraphs])

            # ========================
            # TXT
            # ========================
            elif file_name and file_name.lower().endswith(".txt"):
                if isinstance(file_obj, (io.BytesIO, BinaryIO)):
                    file_obj.seek(0)
                    text = file_obj.read().decode("utf-8")
                else:
                    with open(file_obj, "r", encoding="utf-8") as f:
                        text = f.read()

            # ========================
            # Images
            # ========================
            elif file_name and file_name.lower().endswith((".png", ".jpg", ".jpeg", ".bmp", ".tiff")):
                img = Image.open(file_obj)
                text = pytesseract.image_to_string(img, lang="ara+eng")

            else:
                raise ValueError("Unsupported file type for text extraction.")

        except Exception as e:
            print(f"Error extracting text: {e}")

        return text

    def parse_cv(self, file: Union[str, io.BytesIO, BinaryIO, UploadFile]) -> tuple[str,CVData]:
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
