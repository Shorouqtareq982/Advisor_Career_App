import io
import re
import logging
from typing import Union, BinaryIO, List
from fastapi import UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile

# import pdfplumber
import pymupdf.layout
import pymupdf4llm
import pytesseract
from PIL import Image
from docx import Document


logger = logging.getLogger(__name__)


class TextExtractor:

    # =============================
    # Public API
    # =============================
    async def extract_text_and_links(
        self,
        file: Union[str, io.BytesIO, BinaryIO, UploadFile]
    ) -> dict:
        """
        Extract text + URLs from PDF, DOCX, TXT, or images.

        Returns:
            {
                "text": str,
                "urls": List[str]
            }
        """
        raw_text  = await self._extract_text(file)
        clean_text = self._normalize_ocr_text(raw_text)
        urls = self._extract_urls(clean_text)

        return {
            "text": clean_text,
            "urls": urls
        }

    # =============================
    # Core Text Extraction
    # =============================
    async def _extract_text(
        self,
        file: Union[str, io.BytesIO, BinaryIO, UploadFile]
    ) :

        text = ""

        try:
            file_name, file_obj = self._prepare_file(file)

            if file_name.endswith(".pdf"):
                text = await self._extract_from_pdf(file_obj)

            elif file_name.endswith(".docx"):
                text = self._extract_from_docx(file_obj)

            elif file_name.endswith(".txt"):
                text = self._extract_from_txt(file_obj)

            elif file_name.endswith((".png", ".jpg", ".jpeg", ".bmp", ".tiff")):
                text = self._extract_from_image(file_obj)

            else:
                raise ValueError("Unsupported file type")

        except Exception as e:
            logger.exception("Text extraction failed: %s", e)

        return text

    # =============================
    # File preparation
    # =============================
    def _prepare_file(self, file):
        file_name = None
        file_obj = file

        if isinstance(file, (UploadFile, StarletteUploadFile)):
            file_name = file.filename.lower()
            file_obj = file.file
            file_obj.seek(0)

        elif isinstance(file, io.BytesIO):
            file_name = getattr(file, "name", "").lower()
            file.seek(0)

        elif isinstance(file, str):
            file_name = file.lower()
            file_obj = open(file, "rb")

        else:
            raise ValueError("Unsupported file input type")

        return file_name, file_obj

    # =============================
    # PDF
    # =============================
    async def _extract_from_pdf(self, file_obj: UploadFile) -> str:
        # Read file content as bytes
        file_bytes = await file_obj.read()
        doc = pymupdf.open(stream=file_bytes)
        return pymupdf4llm.to_text(doc, extract_links=True)
    


    async def extract_text_with_links_no_duplicate(self, file: UploadFile) -> str:
        file_bytes = await file.read()
        ext = file.filename.split(".")[-1].lower()

        doc = pymupdf.open(stream=file_bytes, filetype=ext)

        final_text = []

        for page in doc:
            page_text = page.get_text("text")

            # get all links in page
            links = page.get_links()

            replacements = []
            seen_uris = set()  # track duplicated links

            for link in links:
                uri = link.get("uri")
                rect = link.get("from")

                # skip duplicated URIs
                if not uri or uri in seen_uris:
                    continue

                if rect:
                    anchor_text = page.get_text("text", clip=rect).strip()

                    if anchor_text:
                        replacements.append((anchor_text, f"{anchor_text} ({uri})"))
                        seen_uris.add(uri)   # mark as used

            # Replace anchor text with "text (url)"
            for original, replaced in replacements:
                # replace only first occurrence to avoid over-replacing duplicates
                page_text = page_text.replace(original, replaced, 1)

            final_text.append(page_text)

    
        text_list = "\n".join(final_text)
        text_list = text_list.split("\n\n")
        # Remove Unicode characters from each line
        cleaned_texts = [re.sub(r'[^\x00-\x7F]+', '', line) for line in text_list]
        cleaned_texts = [text.strip() for text in cleaned_texts if text.strip() not in ['', None]]

        # Join the lines into a single string
        cleaned_texts_string = '\n'.join(cleaned_texts)

        return cleaned_texts_string


    async def extract_text_with_links(self, file: UploadFile) -> str:
        file_bytes = await file.read()
        ext = file.filename.split(".")[-1].lower()

        doc = pymupdf.open(stream=file_bytes, filetype=ext)

        final_text = []

        for page in doc:
            page_text = page.get_text("text")

            # get all links in page
            links = page.get_links()

            replacements = []

            for link in links:
                uri = link.get("uri")
                rect = link.get("from")

                if uri and rect:
                    anchor_text = page.get_text("text", clip=rect).strip()

                    if anchor_text:
                        replacements.append((anchor_text, f"{anchor_text} ({uri})"))

            # Replace anchor text with "text (url)"
            for original, replaced in replacements:
                # replace only first occurrence to avoid over-replacing duplicates
                page_text = page_text.replace(original, replaced, 1)

            final_text.append(page_text)

        return "\n".join(final_text)
    
    async def extract_text_with_links_precise(self, file: UploadFile) -> str:
        file_bytes = await file.read()
        ext = file.filename.split(".")[-1].lower()

        doc = pymupdf.open(stream=file_bytes, filetype=ext)

        final_pages = []

        for page in doc:
            words = page.get_text("words")  
            # (x0, y0, x1, y1, "word", block, line, word_no)

            links = page.get_links()

            # We'll mark words that belong to links
            word_replacements = {}

            for link in links:
                uri = link.get("uri")
                rect = link.get("from")

                if not uri or not rect:
                    continue

                rect = pymupdf.Rect(rect)

                # collect words inside link rectangle
                anchor_words = []
                anchor_indices = []

                for i, w in enumerate(words):
                    w_rect = pymupdf.Rect(w[0], w[1], w[2], w[3])

                    if rect.intersects(w_rect):
                        anchor_words.append(w[4])
                        anchor_indices.append(i)

                if not anchor_words:
                    continue

                anchor_text = " ".join(anchor_words)

                # Replace ONLY the first word in that group
                first_idx = anchor_indices[0]

                word_replacements[first_idx] = f"{anchor_text} ({uri})"

                # mark remaining words in that anchor to be removed
                for idx in anchor_indices[1:]:
                    word_replacements[idx] = ""

            # rebuild line in correct order
            new_words = []
            for i, w in enumerate(words):
                if i in word_replacements:
                    replacement = word_replacements[i]
                    if replacement:
                        new_words.append(replacement)
                else:
                    new_words.append(w[4])

            page_text = " ".join(new_words)
            final_pages.append(page_text)

        return "\n\n".join(final_pages)
    
    async def extract_text_with_links_preserve_layout(self, file: UploadFile) -> str:
        file_bytes = await file.read()
        ext = file.filename.split(".")[-1].lower()

        doc = pymupdf.open(stream=file_bytes, filetype=ext)

        final_pages = []

        for page in doc:
            links = page.get_links()
            link_rects = []

            # prepare link rectangles
            for link in links:
                uri = link.get("uri")
                rect = link.get("from")

                if uri and rect:
                    link_rects.append((pymupdf.Rect(rect), uri))

            page_dict = page.get_text("dict")

            page_lines = []

            for block in page_dict["blocks"]:
                if block["type"] != 0:
                    continue

                for line in block["lines"]:
                    line_words = []

                    for span in line["spans"]:
                        span_text = span["text"]
                        span_rect = pymupdf.Rect(span["bbox"])

                        replaced = False

                        for rect, uri in link_rects:
                            if rect.intersects(span_rect):
                                # this span is part of a hyperlink
                                clean = span_text.strip()
                                if clean:
                                    line_words.append(f"{clean} ({uri})")
                                    replaced = True
                                    break

                        if not replaced:
                            line_words.append(span_text)

                    # preserve spacing inside line
                    line_text = "".join(line_words)
                    page_lines.append(line_text)

                # keep block separation (paragraph spacing)
                page_lines.append("")

            final_pages.append("\n".join(page_lines))

        return "\n\n".join(final_pages)
    
    # =============================
    # DOCX
    # =============================
    def _extract_from_docx(self, file_obj) -> str:
        doc = Document(file_obj)
        text = "\n".join([p.text for p in doc.paragraphs])

        # extract hyperlinks
        rels = doc.part.rels
        for rel in rels.values():
            if "hyperlink" in rel.reltype:
                text += f"\n{rel.target_ref}\n"

        return text


    # =============================
    # TXT
    # =============================
    def _extract_from_txt(self, file_obj) -> str:
        if hasattr(file_obj, "read"):
            file_obj.seek(0)
            return file_obj.read().decode("utf-8")

        with open(file_obj, "r", encoding="utf-8") as f:
            return f.read()

    # =============================
    # Images / OCR
    # =============================
    def _extract_from_image(self, file_obj) -> str:
        img = Image.open(file_obj)
        return pytesseract.image_to_string(img, lang="ara+eng")

    # =============================
    # URL Extraction
    # =============================
    def _extract_urls(self, text: str) -> List[str]:
        url_pattern = r"(https?://[^\s]+|www\.[^\s]+)"
        return re.findall(url_pattern, text)

    # =============================
    # OCR cleanup
    # =============================
    def _normalize_ocr_text(self, text: str) -> str:
        # fix broken URLs like: https : // linkedin . com
        text = re.sub(r"\s*:\s*/\s*/\s*", "://", text)
        text = re.sub(r"\s*\.\s*", ".", text)
        text = re.sub(r"\s*/\s*", "/", text)

        return text
