from pydantic import BaseModel, Field
from typing import List, Optional


class PageSize(BaseModel):
    """Page dimensions in points."""
    width: float = Field(..., description="Page width in points")
    height: float = Field(..., description="Page height in points")


class PageMargin(BaseModel):
    """Page margin measurements in inches."""
    left: float = Field(..., description="Left margin in inches")
    top: float = Field(..., description="Top margin in inches")
    right: float = Field(..., description="Right margin in inches")
    bottom: float = Field(..., description="Bottom margin in inches")


class CVLayoutAnalysis(BaseModel):
    """Comprehensive CV layout analysis results."""
    
    # ── Structure and Content ────────────────────────────────────────────────
    have_images: bool = Field(..., description="Whether the document contains images")
    have_tables: bool = Field(..., description="Whether the document contains tables")
    have_columns: bool = Field(..., description="Whether the document has multi-column layout")
    have_graphics: bool = Field(..., description="Whether the document contains graphics/drawings")
    have_textboxes: Optional[bool] = Field(None, description="Whether the document contains textboxes")
    valid_date_format: Optional[bool] = Field(None, description="Whether dates are in the expected format: “MM / YY or MM / YYYY or Month YYYY” (e.g. 03/18, 03/2019, Mar 2019 or March 2019)")

    # ── File and Font Information ────────────────────────────────────────────
    fonts_used: List[str] = Field(default_factory=list, description="List of fonts used in document")
    avg_font_size: float = Field(..., description="Average font size in points")
    file_size_kb: float = Field(..., description="File size in kilobytes")
    file_type: str = Field(..., description="MIME type of the file (e.g., application/pdf)")
    
    # ── Document Metrics ────────────────────────────────────────────────────
    num_of_pages: int = Field(..., description="Total number of pages/sections")
    num_of_sections: Optional[int] = Field(None, description="Number of sections (DOCX only)")
    word_count: int = Field(..., description="Total number of words in document")
    
    # ── Filename Validation ──────────────────────────────────────────────────
    valid_cv_filename: bool = Field(..., description="Whether filename is valid for CV")
    valid_cv_filename_length: bool = Field(..., description="Whether filename length is acceptable (<= 100 chars)")
    original_filename: Optional[str] = Field(None, description="The original filename of the uploaded CV")
    
    # ── Page Setup ────────────────────────────────────────────────────
    page_sizes_in_points: List[PageSize] = Field(default_factory=list, description="List of page dimensions (one per page/section)")
    page_margins_in_inches: List[PageMargin] = Field(default_factory=list, description="List of page margins (one per page/section)")
    information_in_header: bool = Field(..., description="Whether content exists in header")
    information_in_footer: bool = Field(..., description="Whether content exists in footer")
    
    class Config:
        """Pydantic configuration."""
        json_schema_extra = {
            "example": {
                "have_images": True,
                "have_tables": False,
                "have_columns": False,
                "have_graphics": False,
                "have_textboxes": False,
                "valid_date_format": True,
                "information_in_header": True,
                "information_in_footer": False,
                "fonts_used": ["Calibri", "Arial"],
                "avg_font_size": 11.5,
                "file_size_kb": 245.3,
                "file_type": "application/pdf",
                "num_of_pages": 2,
                "num_of_sections": None,
                "word_count": 542,
                "valid_cv_filename": True,
                "valid_cv_filename_length": True,
                "page_sizes_in_points": [
                    {"width": 612.0, "height": 792.0},
                    {"width": 612.0, "height": 792.0}
                ],
                "page_margins_in_inches": [
                    {"left": 0.5, "top": 0.5, "right": 0.5, "bottom": 0.5},
                    {"left": 0.5, "top": 0.5, "right": 0.5, "bottom": 0.5}
                ]
            }
        }
