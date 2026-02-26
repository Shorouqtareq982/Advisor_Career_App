import io
import re
import logging
from typing import Union, BinaryIO, List, Tuple
from fastapi import UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile
import pymupdf
import pytesseract
from PIL import Image
from docx import Document
from docx.oxml.text.paragraph import CT_P
from docx.oxml.table import CT_Tbl


logger = logging.getLogger(__name__)


class TextExtractor:

    @staticmethod
    async def extract_text_and_links(
        file: Union[str, io.BytesIO, BinaryIO, UploadFile]
    ) -> dict:
        """Extract text + URLs from PDF, DOCX, TXT, or images."""
        raw_text = await TextExtractor.extract_text(file)
        urls = TextExtractor._extract_urls(raw_text)
        return {"text": raw_text, "urls": urls}

    @staticmethod
    async def extract_text(
        file: Union[str, io.BytesIO, BinaryIO, UploadFile]
    ) -> str:
        """Extract text from supported file formats."""
        text = ""
        try:
            file_name, file_obj = TextExtractor._prepare_file(file)
            
            if file_name.endswith(".pdf"):
                text = await TextExtractor._extract_from_pdf(file_obj)
            elif file_name.endswith(".docx"):
                text = TextExtractor._extract_from_docx(file_obj)
            elif file_name.endswith(".txt"):
                text = TextExtractor._extract_from_txt(file_obj)
            elif file_name.endswith((".png", ".jpg", ".jpeg", ".bmp", ".tiff")):
                text = TextExtractor._extract_from_image(file_obj)
            else:
                raise ValueError(f"Unsupported file type: {file_name}")
        except Exception as e:
            logger.exception("Text extraction failed: %s", e)
            return ""

        return TextExtractor._normalize_ocr_text(text)

    @staticmethod
    def _prepare_file(file: Union[str, io.BytesIO, BinaryIO, UploadFile]) -> Tuple[str, BinaryIO]:
        """Prepare file for extraction and return (filename, file_object)."""
        if isinstance(file, (UploadFile, StarletteUploadFile)):
            file_name = file.filename.lower()
            file_obj = file.file
            file_obj.seek(0)
        elif isinstance(file, io.BytesIO):
            file_name = getattr(file, "name", "").lower()
            file.seek(0)
            file_obj = file
        elif isinstance(file, str):
            file_name = file.lower()
            file_obj = open(file, "rb")
        else:
            raise ValueError(f"Unsupported file input type: {type(file)}")

        return file_name, file_obj

    @staticmethod
    async def _extract_from_pdf(file_obj: BinaryIO) -> str:
        """Extract text and links from PDF."""
        file_bytes = file_obj.read() if hasattr(file_obj, "read") else file_obj
        doc = pymupdf.open(stream=file_bytes, filetype="pdf")
        
        try:
            final_text = []
            for page in doc:
                page_text = page.get_text("text")
                links = page.get_links()
                page_text = TextExtractor._replace_links_in_text(page, page_text, links)
                final_text.append(page_text)
            
            return TextExtractor._clean_text_lines(final_text)
        finally:
            doc.close()

    @staticmethod
    def _replace_links_in_text(page, page_text: str, links: list) -> str:
        """Replace anchor text with 'text (url)' format."""
        replacements = []
        seen_uris = set()

        for link in links:
            uri = link.get("uri")
            rect = link.get("from")

            if not uri or uri in seen_uris or not rect:
                continue

            anchor_text = page.get_text("text", clip=rect).strip()
            if anchor_text:
                replacements.append((anchor_text, f"{anchor_text} ({uri})"))
                seen_uris.add(uri)

        for original, replaced in replacements:
            page_text = page_text.replace(original, replaced, 1)

        return page_text

    @staticmethod
    def _clean_text_lines(text_list: List[str]) -> str:
        """Clean and join text lines."""
        text = "\n".join(text_list)
        lines = text.splitlines()
        cleaned = [line.strip() for line in lines if line.strip()]
        return "\n".join(cleaned)

    @staticmethod
    def _extract_from_docx(file_obj: BinaryIO) -> str:
        """Extract text and hyperlinks from DOCX."""
        doc = Document(file_obj)
        final_text = []
        seen_uris = set()

        def get_text_from_element(elem):
            texts = [t.text for t in elem.iter() if t.tag.endswith('}t') and t.text]
            return " ".join(texts).strip()

        def extract_text_recursive(element):
            for child in element.iterchildren():
                if isinstance(child, CT_P):
                    para_text = get_text_from_element(child)
                    # Handle hyperlinks: <w:hyperlink> with r:id pointing to rels
                    for hyperlink in child.findall(".//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}hyperlink"):
                        rId = hyperlink.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
                        if rId and rId not in seen_uris:
                            rel = doc.part.rels.get(rId)
                            if rel and hasattr(rel, "target_ref"):
                                url = rel.target_ref
                                anchor = get_text_from_element(hyperlink)
                                if anchor:
                                    para_text = para_text.replace(anchor, f"{anchor} ({url})", 1)
                                    seen_uris.add(rId)
                    if para_text:
                        final_text.append(para_text)
                elif isinstance(child, CT_Tbl):
                    for row in child.iter():
                        for cell in row.iter():
                            extract_text_recursive(cell)
                # Textboxes / shapes
                else:
                    if "txbxContent" in child.tag:
                        extract_text_recursive(child)
                    else:
                        extract_text_recursive(child)  # recurse deeper

        extract_text_recursive(doc._element)

        # Headers and footers
        for section in doc.sections:
            for element in [section.header, section.first_page_header, section.even_page_header,
                           section.footer, section.first_page_footer, section.even_page_footer]:
                extract_text_recursive(element._element)

        cleaned_texts = [re.sub(r'\s+', ' ', line).strip() for line in final_text if line.strip()]
        return "\n".join(cleaned_texts)


    @staticmethod
    def _extract_from_txt(file_obj: BinaryIO) -> str:
        """Extract text from TXT file."""
        if hasattr(file_obj, "read"):
            file_obj.seek(0)
            return file_obj.read().decode("utf-8")
        with open(file_obj, "r", encoding="utf-8") as f:
            return f.read()

    @staticmethod
    def _extract_from_image(file_obj: BinaryIO) -> str:
        """Extract text from image using OCR."""
        img = Image.open(file_obj)
        return pytesseract.image_to_string(img, lang="ara+eng")

    @staticmethod
    def _extract_urls(text: str) -> List[str]:
        """Extract URLs from text."""
        url_pattern = r"(https?://[^\s]+|www\.[^\s]+)"
        return re.findall(url_pattern, text)

    @staticmethod
    def _normalize_ocr_text(text: str) -> str:
        """Normalize OCR text by fixing broken URLs and whitespace."""
        text = re.sub(r"\s*:\s*/\s*/\s*", "://", text)
        text = re.sub(r"\s*\.\s*", ".", text)
        text = re.sub(r"\s*/\s*", "/", text)
        return text
