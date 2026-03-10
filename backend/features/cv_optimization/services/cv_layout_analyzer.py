import io
import re
from typing import Dict, List, Optional, Set, Tuple, TypedDict

import numpy as np
import pymupdf
from docx import Document
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from docx.text.run import Run
from sklearn.cluster import KMeans

from shared.helpers.file_validation import FileValidator
from ..schemas.layout_analysis_schema import CVLayoutAnalysis, PageMargin, PageSize


# ==================== Type Definitions ====================

class PdfPageAnalysisResult(TypedDict):
    """Result from analyzing a single PDF page."""
    have_images: bool
    have_tables: bool
    have_graphics: bool
    have_columns: bool
    information_in_header: bool
    information_in_footer: bool
    page_size: Dict[str, float]
    page_margin: Dict[str, float]


class HeaderFooterResult(TypedDict):
    """Result from header/footer analysis."""
    has_header_info: bool
    has_footer_info: bool
    have_links_in_header: bool


class TextContentResult(TypedDict):
    """Result from text content analysis."""
    extracted_text: str
    fonts_names: List[str]
    font_sizes: List[float]
    have_hyperlinks: bool


class CVLayoutAnalyzer:
    """Analyzes CV layout features from PDF and DOCX files.
    
    Detects layout properties including:
    - Images, tables, graphics, columns
    - Font information and sizes
    - Page dimensions and margins
    - Header and footer content
    - Hyperlinks and document structure
    """

    # ==================== Constants ====================
    # PDF Analysis Constants
    KMEANS_N_CLUSTERS = 2
    KMEANS_INIT = 10
    COLUMN_SEPARATION_THRESHOLD = 200
    MIN_X_POSITIONS_FOR_CLUSTERING = 10
    
    # Page Margin Constants (as percentage of page height)
    HEADER_THRESHOLD_PERCENT = 0.05
    FOOTER_THRESHOLD_PERCENT = 0.95
    
    # Conversion Factors
    POINTS_PER_INCH = 72
    EMU_PER_POINT = 12700
    EMU_PER_INCH = 914400
    
    # XML Namespace URIs
    WPML_NS = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
    WPS_NS = "{http://schemas.microsoft.com/office/word/2010/wordprocessingShape}wsp"
    VML_NS = "{urn:schemas-microsoft-com:vml}shape"
    VML_TEXTBOX_NS = "{urn:schemas-microsoft-com:vml}textbox"
    WP_NS = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
    RELATIONSHIPS_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
    
    # Validation Constants
    MAX_FILENAME_LENGTH = 100

    # ==================== Main Entry Point ====================

    @staticmethod
    def analyze_file_layout(
        file_buf: io.BytesIO,
        file_name: str,
        file_size_kb: float,
        file_type: str,
    ) -> Dict | Tuple[Dict, str]:
        """Analyze layout of a CV file (PDF or DOCX).
        
        Args:
            file_buf: BytesIO object containing file data
            file_name: Original filename for validation
            file_size_kb: File size in kilobytes
            file_type: MIME type of the file
        
        Returns:
            Dictionary containing layout analysis results for PDF, or tuple(Dictionary, text) for DOCX
            Returns default analysis with None values on error
        """
        try:
            name_lower = (file_name or "").lower()
            if name_lower.endswith(".pdf"):
                doc = pymupdf.open(stream=file_buf.read(), filetype="pdf")
                try:
                    return CVLayoutAnalyzer.analyze_pdf_layout(doc, file_size_kb, file_type, file_name)
                finally:
                    doc.close()
            elif name_lower.endswith(".docx"):
                doc = Document(file_buf)
                return CVLayoutAnalyzer.analyze_docx_layout(doc, file_size_kb, file_type, file_name)
            else:
                raise ValueError("Unsupported file type for layout analysis")
        except Exception as e:
            # Log the error and return a default analysis indicating failure
            print(f"Error analyzing file layout: {e}")
            return {
                "have_images": None,
                "have_tables": None,
                "have_columns": None,
                "have_graphics": None,
                "have_textboxes": None,
                "information_in_header": None,
                "information_in_footer": None,
                "fonts_used": None,
                "avg_font_size": None,
                "file_size_kb": file_size_kb,
                "file_type": file_type,
                "num_of_pages": None,
                "num_of_sections": None,
                "word_count": None,
                "valid_cv_filename": None,
                "valid_cv_filename_length": None,
                "original_filename": file_name,
                "page_sizes_in_points": None,
                "page_margins_in_inches": None
            }, None

    # ==================== PDF Analysis Methods ====================

    @staticmethod
    def analyze_pdf_layout(
        doc, 
        file_size_kb: float, 
        file_type: str, 
        org_filename: str
    ) -> Tuple[CVLayoutAnalysis, str]:
        """Analyze PDF layout features including images, tables, graphics, columns, and fonts.
        
        Args:
            doc: PyMuPDF document object
            file_size_kb: File size in kilobytes
            file_type: Content type of the file
            org_filename: Original file name
        
        Returns:
            CVLayoutAnalysis object containing layout analysis results
        """
        have_images = False
        have_tables = False
        have_graphics = False
        have_columns = False
        num_of_doc_words = 0
        information_in_header = False
        information_in_footer = False
        page_margins = []
        page_texts = []
        page_sizes = []
        avg_font_size = 0
        all_font_sizes = []
        all_text_content = []
        valid_filename, _ = FileValidator.validate_filename(org_filename)
        valid_filename_length = len(org_filename) <= CVLayoutAnalyzer.MAX_FILENAME_LENGTH
        num_of_pages = doc.page_count
        fonts_used = set()

        # Analyze each page
        for page in doc:
            page_analysis = CVLayoutAnalyzer._analyze_pdf_page(
                page, all_font_sizes, all_text_content, fonts_used
            )
            have_images |= page_analysis["have_images"]
            have_tables |= page_analysis["have_tables"]
            have_graphics |= page_analysis["have_graphics"]
            have_columns |= page_analysis["have_columns"]
            information_in_header |= page_analysis["information_in_header"]
            information_in_footer |= page_analysis["information_in_footer"]
            page_margins.append(page_analysis["page_margin"])
            page_sizes.append(page_analysis["page_size"])
            page_texts.append(page_analysis["page_text"])

        if all_font_sizes:
            avg_font_size = round(sum(all_font_sizes) / len(all_font_sizes), 2)

        # Calculate total word count
        num_of_doc_words = sum(len(text.split()) for text in all_text_content)

        # Convert to Pydantic objects
        page_sizes_objs = [PageSize(**ps) for ps in page_sizes]
        page_margins_objs = [PageMargin(**pm) for pm in page_margins]

        extracted_text = CVLayoutAnalyzer._clean_text(page_texts)

        return CVLayoutAnalysis(
            have_images=have_images,
            have_tables=have_tables,
            have_columns=have_columns,
            have_graphics=have_graphics,
            information_in_header=information_in_header,
            information_in_footer=information_in_footer,
            fonts_used=list(fonts_used),
            avg_font_size=avg_font_size,
            file_size_kb=file_size_kb,
            file_type=file_type,
            num_of_pages=num_of_pages,
            num_of_sections=None,
            word_count=num_of_doc_words,
            valid_cv_filename=valid_filename,
            valid_cv_filename_length=valid_filename_length,
            original_filename=org_filename,
            page_sizes_in_points=page_sizes_objs,
            page_margins_in_inches=page_margins_objs,
        ), extracted_text

    @staticmethod
    def _analyze_pdf_page(
        page, 
        all_font_sizes: List[float], 
        all_text_content: List[str], 
        fonts_used: Set[str]
    ) -> PdfPageAnalysisResult:
        """Analyze a single PDF page for layout features.
        
        Args:
            page: PyMuPDF page object
            all_font_sizes: List to accumulate font sizes across pages
            all_text_content: List to accumulate text content for word count
            fonts_used: Set to accumulate unique font names
        
        Returns:
            Dictionary with page analysis results
        """
        page_rect = page.rect
        page_width = page_rect.width
        page_height = page_rect.height
        
        # Header / footer thresholds
        header_threshold = page_height * CVLayoutAnalyzer.HEADER_THRESHOLD_PERCENT
        footer_threshold = page_height * CVLayoutAnalyzer.FOOTER_THRESHOLD_PERCENT

        have_images = bool(page.get_images())
        have_tables = len(page.find_tables().tables) > 0
        have_graphics = len(page.get_drawings()) > 0
        information_in_header = False
        information_in_footer = False
        page_margin = {}
        page_text = ""

        # Extract fonts
        fonts = page.get_fonts()
        for font in fonts:
            fonts_used.add(font[3])  # font name is at index 3

        # Check for columns (simple heuristic)
        have_columns = CVLayoutAnalyzer._detect_pdf_columns(page)

        # Analyze text blocks
        blocks = page.get_text("rawdict")["blocks"]
        blocks = sorted(
            page.get_text("rawdict")["blocks"],
            key=lambda b: (b["bbox"][1], b["bbox"][0])
        )
        links = page.get_links()

        page_lines = []
        text_blocks = [b for b in blocks if b["type"] == 0]

        # Collect font sizes
        all_font_sizes.extend(
            span["size"]
            for block in text_blocks
            for line in block.get("lines", [])
            for span in line.get("spans", [])
            if span.get("size", 0) > 0
        )

        # Check for text in header/footer regions and collect text
        for block in text_blocks:
            block_top = block["bbox"][1]
            block_bottom = block["bbox"][3]

            if block_top < header_threshold:
                information_in_header = True

            if block_bottom > footer_threshold:
                information_in_footer = True

            for line in block.get("lines", []):
                line_spans = []

                for span in line.get("spans", []):
                    # reconstruct text from characters
                    chars = span.get("chars", [])
                    text = "".join(ch.get("c", "") for ch in chars).strip()

                    if text:
                        line_spans.append(text) 

                if line_spans:
                    line_text = " ".join(line_spans)

                    # Normalize bullets
                    if line_text.startswith(("•", "-", "▪", "●")):
                        line_text = f"- {line_text.lstrip('•-▪●').strip()}"

                    page_lines.append(line_text)
                    all_text_content.append(line_text)

                page_text = "\n".join(page_lines)
                page_text = CVLayoutAnalyzer._attach_links_once(page, page_text)

        # Estimate page margins
        if text_blocks:
            left_margin = min(b["bbox"][0] for b in text_blocks)
            top_margin = min(b["bbox"][1] for b in text_blocks)
            right_margin = page_width - max(b["bbox"][2] for b in text_blocks)
            bottom_margin = page_height - max(b["bbox"][3] for b in text_blocks)

            # Convert from points to inches
            page_margin = {
                "left": round(left_margin / CVLayoutAnalyzer.POINTS_PER_INCH, 2),
                "top": round(top_margin / CVLayoutAnalyzer.POINTS_PER_INCH, 2),
                "right": round(right_margin / CVLayoutAnalyzer.POINTS_PER_INCH, 2),
                "bottom": round(bottom_margin / CVLayoutAnalyzer.POINTS_PER_INCH, 2),
            }

        return {
            "have_images": have_images,
            "have_tables": have_tables,
            "have_graphics": have_graphics,
            "have_columns": have_columns,
            "information_in_header": information_in_header,
            "information_in_footer": information_in_footer,
            "page_size": {
                "width": round(page_width, 2),
                "height": round(page_height, 2)
            },
            "page_margin": page_margin,
            "page_text": page_text
        }

    @staticmethod
    def _detect_pdf_columns(page) -> bool:
        """Detect if PDF page has multi-column layout.
        
        Uses simple heuristic: clustering of text x-positions to find column separation.
        """
        blocks = page.get_text("dict")["blocks"]
        x_positions = [
            span["bbox"][0]
            for block in blocks if block["type"] == 0
            for line in block["lines"]
            for span in line["spans"]
        ]
        
        if len(x_positions) > CVLayoutAnalyzer.MIN_X_POSITIONS_FOR_CLUSTERING:
            x_positions = np.array(x_positions).reshape(-1, 1)
            kmeans = KMeans(n_clusters=CVLayoutAnalyzer.KMEANS_N_CLUSTERS, 
                          n_init=CVLayoutAnalyzer.KMEANS_INIT).fit(x_positions)
            centers = sorted(kmeans.cluster_centers_.flatten())
            if abs(centers[0] - centers[1]) > CVLayoutAnalyzer.COLUMN_SEPARATION_THRESHOLD:
                return True
        return False

    @staticmethod
    def _attach_links_once(page, page_text: str) -> str:
        links = page.get_links()
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
    # ==================== DOCX Analysis Methods ====================

    @staticmethod
    def analyze_docx_layout(
        doc: Document,
        file_size_kb: float,
        file_type: str,
        org_filename: str
    ) -> Tuple[CVLayoutAnalysis, str]:
        """Analyze DOCX layout features and extract text content.
        
        Args:
            doc: python-docx Document object
            file_size_kb: File size in kilobytes
            file_type: MIME type of the file
            org_filename: Original file name
        
        Returns:
            Tuple of (CVLayoutAnalysis object, extracted text string)
        """
        valid_filename, _ = FileValidator.validate_filename(org_filename)
        valid_filename_length = len(org_filename) <= CVLayoutAnalyzer.MAX_FILENAME_LENGTH

        num_of_pages = CVLayoutAnalyzer._get_page_count_docx(doc)
        page_sizes, page_margins, have_columns = CVLayoutAnalyzer._extract_page_properties(doc, num_of_pages)
        content_data = CVLayoutAnalyzer._analyze_text_content(doc)
        header_footer_data = CVLayoutAnalyzer._analyze_headers_footers(doc)

        fonts_used = content_data["fonts_names"]
        all_font_sizes = content_data["font_sizes"]
        avg_font_size = round(sum(all_font_sizes) / len(all_font_sizes), 2) if all_font_sizes else 0
        num_of_doc_words = CVLayoutAnalyzer.word_count(content_data["extracted_text"])

        # Detect document features
        have_graphics = CVLayoutAnalyzer._detect_graphics(doc)
        have_images = CVLayoutAnalyzer._detect_images(doc)  
        have_textboxes = CVLayoutAnalyzer._detect_textboxes(doc)
        have_tables = len(doc.tables) > 0


        return CVLayoutAnalysis(
            have_images=have_images,
            have_tables=have_tables,
            have_columns=have_columns,
            have_graphics=have_graphics,
            have_textboxes=have_textboxes,
            information_in_header=header_footer_data["has_header_info"],
            information_in_footer=header_footer_data["has_footer_info"],
            fonts_used=set(fonts_used),
            avg_font_size=avg_font_size,
            file_size_kb=file_size_kb,
            file_type=file_type,
            num_of_pages=num_of_pages,
            num_of_sections=len(doc.sections),
            word_count=num_of_doc_words,
            valid_cv_filename=valid_filename,
            valid_cv_filename_length=valid_filename_length,
            original_filename=org_filename,
            page_sizes_in_points=page_sizes,
            page_margins_in_inches=page_margins
        ), content_data["extracted_text"]
    
    @staticmethod
    def _extract_page_properties(doc: Document, num_pages: int) -> Tuple[List[PageSize], List[PageMargin], bool]:
        """Extract page sizes, margins, and column information from DOCX sections.
        
        Distributes section properties across all pages proportionally.
        
        Args:
            doc: python-docx Document object
            num_pages: Total number of pages in document
        
        Returns:
            Tuple of (page_sizes list, page_margins list, have_columns bool)
        """
        page_sizes = []
        page_margins = []
        have_columns = False

        # Collect section properties
        section_properties = []
        for section in doc.sections:
            page_size = CVLayoutAnalyzer._get_section_page_size(section)
            margins = CVLayoutAnalyzer._get_section_margins(section)
            section_properties.append((page_size, margins))

            # Check for columns
            sect_pr = section._sectPr
            cols_elem = sect_pr.find(f"{CVLayoutAnalyzer.WPML_NS}cols")
            if cols_elem is not None:
                num_cols = cols_elem.get(f"{CVLayoutAnalyzer.WPML_NS}num")
                if num_cols and int(num_cols) > 1:
                    have_columns = True

        # Distribute section properties across pages
        page_sizes, page_margins = CVLayoutAnalyzer._distribute_section_properties(
            section_properties, num_pages
        )

        return page_sizes, page_margins, have_columns

    @staticmethod
    def _get_section_page_size(section) -> Optional[PageSize]:
        """Extract page size from a document section."""
        if section.page_width and section.page_height:
            return PageSize(
                width=round(section.page_width / CVLayoutAnalyzer.EMU_PER_POINT, 2),
                height=round(section.page_height / CVLayoutAnalyzer.EMU_PER_POINT, 2),
            )
        return None

    @staticmethod
    def _get_section_margins(section) -> PageMargin:
        """Extract margins from a document section.
        
        Converts EMU (English Metric Units) to inches.
        """
        return PageMargin(
            top=round(section.top_margin / CVLayoutAnalyzer.EMU_PER_INCH, 2),
            bottom=round(section.bottom_margin / CVLayoutAnalyzer.EMU_PER_INCH, 2),
            left=round(section.left_margin / CVLayoutAnalyzer.EMU_PER_INCH, 2),
            right=round(section.right_margin / CVLayoutAnalyzer.EMU_PER_INCH, 2)
        )


    @staticmethod
    def _distribute_section_properties(
        section_properties: List[Tuple], 
        num_pages: int
    ) -> Tuple[List[PageSize], List[PageMargin]]:
        """Distribute section properties across pages.
        
        Args:
            section_properties: List of (page_size, margins) tuples
            num_pages: Total number of pages
        
        Returns:
            Tuple of (page_sizes list, page_margins list)
        """
        page_sizes = []
        page_margins = []

        if len(section_properties) == 1:
            # Single section: replicate properties for all pages
            page_size, margins = section_properties[0]
            for _ in range(num_pages):
                if page_size:
                    page_sizes.append(page_size)
                page_margins.append(margins)
        else:
            # Multiple sections: estimate pages per section
            pages_per_section = max(1, num_pages // len(section_properties))
            remaining_pages = num_pages % len(section_properties)
            page_count = 0

            for section_idx, (page_size, margins) in enumerate(section_properties):
                pages_in_section = pages_per_section + (1 if section_idx < remaining_pages else 0)

                for _ in range(pages_in_section):
                    if page_size:
                        page_sizes.append(page_size)
                    page_margins.append(margins)
                    page_count += 1
                    if page_count >= num_pages:
                        break
                if page_count >= num_pages:
                    break

        # Ensure page_sizes and page_margins have matching lengths
        if len(page_sizes) < len(page_margins):
            last_size = page_sizes[-1] if page_sizes else PageSize(width=8.5, height=11.0)
            page_sizes.extend([last_size] * (len(page_margins) - len(page_sizes)))

        return page_sizes, page_margins

    
    @staticmethod
    def _detect_images(doc: Document) -> bool:
        """Detect if DOCX contains images by checking document relationships."""
        try:
            for rel in doc.part.rels.values():
                if hasattr(rel, "target_ref") and "image" in rel.target_ref:
                    return True
        except Exception:
            pass
        return False
    
    @staticmethod
    def _detect_graphics(doc: Document) -> bool:
        """Detect if DOCX contains graphics/shapes (both modern and legacy VML)."""
        body = doc._element.body
        return bool(body.findall(f".//{CVLayoutAnalyzer.WPS_NS}") or 
                   body.findall(f".//{CVLayoutAnalyzer.VML_NS}"))
    
    @staticmethod
    def _detect_textboxes(doc: Document) -> bool:
        """Detect if DOCX contains textboxes."""
        body = doc._element.body
        return bool(body.findall(f".//{CVLayoutAnalyzer.WP_NS}txbxContent") or
                   body.findall(f".//{CVLayoutAnalyzer.VML_TEXTBOX_NS}"))

    @staticmethod
    def _analyze_headers_footers(doc: Document) -> HeaderFooterResult:
        """Analyze headers and footers for content and hyperlinks.
        
        Returns:
            HeaderFooterResult with header_info, footer_info, have_links_in_header
        """
        header_info = False
        footer_info = False
        have_links_in_header = False

        for section in doc.sections:
            # Check headers
            header_info, has_links = CVLayoutAnalyzer._check_header_footer_parts(
                (section.header, section.first_page_header, section.even_page_header),
                check_hyperlinks=True
            )
            have_links_in_header |= has_links
            
            # Check footers
            footer_info, _ = CVLayoutAnalyzer._check_header_footer_parts(
                (section.footer, section.first_page_footer, section.even_page_footer),
                check_hyperlinks=False
            )

        return HeaderFooterResult(
            has_header_info=header_info,
            has_footer_info=footer_info,
            have_links_in_header=have_links_in_header
        )

    @staticmethod
    def _check_header_footer_parts(
        parts: tuple, 
        check_hyperlinks: bool = False
    ) -> Tuple[bool, bool]:
        """Check header/footer parts for content and optionally hyperlinks.
        
        Args:
            parts: Tuple of header or footer objects
            check_hyperlinks: Whether to check for hyperlinks
        
        Returns:
            Tuple of (has_content, has_hyperlinks)
        """
        has_content = False
        has_hyperlinks = False
        
        for part in parts:
            try:
                if any(p.text.strip() for p in part.paragraphs):
                    has_content = True
                
                if check_hyperlinks:
                    for p in part.paragraphs:
                        if p.hyperlinks:
                            has_hyperlinks = True
            except Exception:
                pass
        
        return has_content, has_hyperlinks


    # ==================== Font & Style Methods ====================

    @staticmethod
    def get_effective_font_name(run: Run, paragraph, styles_element) -> Optional[str]:
        """Get the effective font name for a run, including inherited fonts.
        
        Follows python-docx style inheritance hierarchy:
        1. Direct run formatting (run.font.name)
        2. Paragraph style font
        3. Document default font from w:docDefaults
        
        References:
        - https://python-docx.readthedocs.io/en/latest/dev/analysis/features/text/font.html
        - https://github.com/python-openxml/python-docx/issues/383

        Args:
            run: The run object from python-docx
            paragraph: The paragraph object containing the run
            styles_element: The styles element from the document
        
        Returns:
            Font name string or None if not found
        """
        # 1. Check direct run formatting
        if run.font.name:
            return run.font.name

        # 2. Check paragraph style font
        if paragraph.style and hasattr(paragraph.style, 'font'):
            try:
                if paragraph.style.font.name:
                    return paragraph.style.font.name
            except:
                pass

        # 3. Check document defaults from XML
        try:
            rFonts_elements = styles_element.xpath(
                'w:docDefaults/w:rPrDefault/w:rPr/w:rFonts',
            )
            if rFonts_elements:
                rFonts = rFonts_elements[0]
                font_name = (
                    rFonts.get(f'{CVLayoutAnalyzer.WPML_NS}ascii') or
                    rFonts.get(f'{CVLayoutAnalyzer.WPML_NS}hAnsi') or
                    rFonts.get(f'{CVLayoutAnalyzer.WPML_NS}cs')
                )
                if font_name:
                    return font_name
        except Exception:
            pass

        return None

    @staticmethod
    def get_effective_font_size(run: Run) -> Optional[float]:
        """Get the effective font size for a run, including inherited sizes.
        
        Args:
            run: The run object from python-docx
        
        Returns:
            Font size in points or None if not found
        """
        if run.font and run.font.size:
            return run.font.size.pt

        style = run._parent.style
        while style:
            if style.font and style.font.size:
                return style.font.size.pt
            style = style.base_style

        return None

    # ==================== Text Content Analysis Methods ====================

    @staticmethod
    def _analyze_text_content(doc: Document) -> TextContentResult:
        """Analyze document text content for structure and formatting.
        
        Extracts:
        - All text with hyperlinks resolved
        - Font names and sizes
        - Tables, graphics detection
        - Header/footer presence
        
        Returns:
            TextContentResult dictionary
        """
        final_text: List[str] = []
        fonts: Set[str] = set()
        font_sizes: List[float] = []
        seen_uris: Set[str] = set()

        # Extract body text with hyperlinks
        CVLayoutAnalyzer._extract_text_recursive(
            doc._element, doc, final_text, seen_uris
        )

        # Extract fonts from paragraphs
        CVLayoutAnalyzer._extract_fonts_from_paragraphs(
            doc.paragraphs, doc.styles.element, fonts, font_sizes
        )

        # Extract fonts from tables
        for table in doc.tables:
            for row in table.rows:
                for cell in row.cells:
                    CVLayoutAnalyzer._extract_fonts_from_paragraphs(
                        cell.paragraphs, doc.styles.element, fonts, font_sizes
                    )

        # Detect document features
        have_graphics = CVLayoutAnalyzer._detect_graphics(doc)
        have_images = CVLayoutAnalyzer._detect_images(doc)  
        have_textboxes = CVLayoutAnalyzer._detect_textboxes(doc)

        # Clean and join text
        extracted_text = CVLayoutAnalyzer._clean_text(final_text)

        return {
            "extracted_text": extracted_text,
            "fonts_names": list(fonts),
            "font_sizes": font_sizes,
            "have_hyperlinks": len(seen_uris) > 0,
        }

    @staticmethod
    def _get_text_from_element(elem) -> str:
        """Extract all text content from an XML element."""
        texts = [t.text for t in elem.iter() if t.tag.endswith('}t') and t.text]
        return " ".join(texts).strip()

    @staticmethod
    def _extract_text_recursive(
        element, 
        doc: Document, 
        final_text: List[str], 
        seen_uris: Set[str]
    ) -> None:
        """Recursively extract text from document elements (including tables).
        
        Args:
            element: XML element to extract from
            doc: Document object for relationship lookups
            final_text: List to accumulate text
            seen_uris: Set to track processed hyperlink URIs
        """
        for child in element.iterchildren():
            if isinstance(child, CT_P):
                para_text = CVLayoutAnalyzer._get_text_from_element(child)
                para_text = CVLayoutAnalyzer._resolve_hyperlinks(
                    child, doc, para_text, seen_uris
                )
                if para_text:
                    final_text.append(para_text)

            elif isinstance(child, CT_Tbl):
                for row in child.iter():
                    for cell in row.iter():
                        CVLayoutAnalyzer._extract_text_recursive(
                            cell, doc, final_text, seen_uris
                        )
            else:
                CVLayoutAnalyzer._extract_text_recursive(
                    child, doc, final_text, seen_uris
                )

    @staticmethod
    def _resolve_hyperlinks(
        para, 
        doc: Document, 
        para_text: str, 
        seen_uris: Set[str]
    ) -> str:
        """Resolve hyperlinks in paragraph text.
        
        Args:
            para: Paragraph XML element
            doc: Document object
            para_text: Original paragraph text
            seen_uris: Set to track processed URIs
        
        Returns:
            Text with hyperlink URLs appended to anchors
        """
        for hyperlink in para.findall(f".//{CVLayoutAnalyzer.WPML_NS}hyperlink"):
            rId = hyperlink.get(CVLayoutAnalyzer.RELATIONSHIPS_NS + "id")
            if rId and rId not in seen_uris:
                rel = doc.part.rels.get(rId)
                if rel and hasattr(rel, "target_ref"):
                    url = rel.target_ref
                    anchor = CVLayoutAnalyzer._get_text_from_element(hyperlink)
                    if anchor:
                        para_text = para_text.replace(anchor, f"{anchor} ({url})", 1)
                        seen_uris.add(rId)
        return para_text

    @staticmethod
    def _extract_fonts_from_paragraphs(
        paragraphs, 
        styles_element, 
        fonts: Set[str], 
        font_sizes: List[float]
    ) -> None:
        """Extract font information from paragraphs.
        
        Args:
            paragraphs: Iterable of paragraph objects
            styles_element: Document styles element
            fonts: Set to accumulate font names
            font_sizes: List to accumulate font sizes
        """
        for paragraph in paragraphs:
            for run in paragraph.runs:
                font_name = CVLayoutAnalyzer.get_effective_font_name(
                    run, paragraph, styles_element
                )
                if font_name:
                    fonts.add(font_name)

                font_size = CVLayoutAnalyzer.get_effective_font_size(run)
                if font_size and font_size > 0:
                    font_sizes.append(font_size)

    @staticmethod
    def _check_header_footer_content(doc: Document) -> Tuple[bool, bool]:
        """Check if document has content in headers or footers.
        
        Returns:
            Tuple of (has_header_info, has_footer_info)
        """
        has_header_info = False
        has_footer_info = False

        for section in doc.sections:
            header_parts = (section.header, section.first_page_header, section.even_page_header)
            footer_parts = (section.footer, section.first_page_footer, section.even_page_footer)
            
            has_header_info, _ = CVLayoutAnalyzer._check_header_footer_parts(header_parts)
            has_footer_info, _ = CVLayoutAnalyzer._check_header_footer_parts(footer_parts)

        return has_header_info, has_footer_info

    @staticmethod
    def _clean_text(text_lines: List[str]) -> str:
        """Clean and join text lines.
        
        Removes extra whitespace and joins non-empty lines.
        """
        cleaned = [
            re.sub(r'\s+', ' ', line).strip()
            for line in text_lines
            if line.strip()
        ]
        return "\n".join(cleaned)

    # ==================== Utility & Helper Methods ====================

    @staticmethod
    def _get_page_count_docx(doc: Document) -> int:
        """Estimate page count from DOCX by counting page breaks.
        
        Note: DOCX does not store page count explicitly, so this is an estimate.
        """
        page_count = sum(p.contains_page_break for p in doc.paragraphs) + 1
        return page_count

    @staticmethod
    def _detect_section_breaks(doc: Document) -> Optional[List[int]]:
        """Detect section breaks in the document to determine page boundaries.
        
        Returns:
            List of page numbers where each section breaks, or None if unable to detect
        """
        try:
            section_breaks = []
            current_page = 1
            
            for paragraph in doc.paragraphs:
                pPr = paragraph._element.find(f"{CVLayoutAnalyzer.WPML_NS}pPr")
                if pPr is not None:
                    sectPr = pPr.find(f"{CVLayoutAnalyzer.WPML_NS}sectPr")
                    if sectPr is not None:
                        section_breaks.append(current_page)
            
            return section_breaks if section_breaks else None
        except Exception:
            return None
    
    @staticmethod
    def _get_section_index_for_page(page_num: int, section_breaks: List[int]) -> int:
        """Determine which section a page belongs to based on section breaks.
        
        Args:
            page_num: The page number (1-indexed)
            section_breaks: List of page numbers where sections start/break
        
        Returns:
            Index of the section this page belongs to
        """
        section_idx = 0
        for break_page in sorted(section_breaks):
            if page_num >= break_page:
                section_idx += 1
            else:
                break
        return section_idx
    
    @staticmethod
    def word_count(text: str) -> int:
        """Count words in text string.
        
        Args:
            text: Input text
        
        Returns:
            Number of words
        """
        if not text:
            return 0
        return len(text.split())
    
    