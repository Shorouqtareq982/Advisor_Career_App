import math
import re
from datetime import datetime
from typing import Any, Optional

from ..schemas import CVData, CVLayoutAnalysis, JobData
from ..helpers.content_quality_checker import check_cv_content_quality

class CVScoringService:

    _MONTH_MAP = {
        "jan": 1, "january": 1,
        "feb": 2, "february": 2,
        "mar": 3, "march": 3,
        "apr": 4, "april": 4,
        "may": 5,
        "jun": 6, "june": 6,
        "jul": 7, "july": 7,
        "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "oct": 10, "october": 10,
        "nov": 11, "november": 11,
        "dec": 12, "december": 12,
    }

    def __init__(self, cv_data: CVData, layout_analysis: CVLayoutAnalysis, jd_data: Optional[JobData], cv_text: str):
        self.cv_data = cv_data if isinstance(cv_data, dict) else cv_data.model_dump()
        self.layout_analysis = (
            layout_analysis if isinstance(layout_analysis, dict) else layout_analysis.model_dump()
        )
        self.jd_data = (
            jd_data if isinstance(jd_data, dict)
            else (jd_data.model_dump() if jd_data else None)
        )
        self.cv_text = cv_text
        self.ats_issues = []
        self.content_quality_issues = []
    
    def get_cv_scores(self):
        ats_readability_score, ats_total_checks, ats_passed_checks = self.calculate_ats_readability_score()
        content_quality_score, content_total_checks, content_passed_checks = self.calculate_content_quality_score()

        return {
            "ATS_Readability_Analysis": {
                "score": ats_readability_score,
                "issues": self.ats_issues,
                "total_checks": ats_total_checks,
                "passed_checks": ats_passed_checks
            },
            "Content_Quality_Analysis": {
                "score": content_quality_score,
                "issues": self.content_quality_issues,
                "total_checks": content_total_checks,
                "passed_checks": content_passed_checks
            }
        }
    
    def calculate_ats_readability_score(self):
        """
        Detailed analysis of ATS readability factors with specific checks and messages.
        TOTAL CHECKS: 19
        
        Score = (passed checks ÷ 19) × 100 (rounded up, max 100).

        Categories:

        Structure: pages, fonts, font size, word count
        Page setup: page size, margins, no headers/footers
        ATS compatibility: no disruptive tables, columns, images, graphics, or text boxes
        Dates: valid standard format (e.g., MM/YY, Mar 2019)
        File quality: size, type (PDF/DOCX), valid name, length, no special chars

        Rule: any null field counts as PASS.
        """ 
        self.ats_issues = []

        total_checks = 19
        passed_checks = 0

        def passes(value):
            return value is None or bool(value)

        # 1. Structure & Formatting (4)
        num_of_pages = self.layout_analysis.get("num_of_pages")
        pages_ok = passes(num_of_pages is None or num_of_pages <= 3)
        passed_checks += int(pages_ok)
        if not pages_ok:
            self.ats_issues.append({
                "Check_Name": "Page Count",
                "Result": {"description": "Your CV is a bit long (over 3 pages). Try trimming it down to 3 pages or less to make it easier for recruiters and ATS systems to scan."}
            })

        fonts_used = self.layout_analysis.get("fonts_used")
        fonts_ok = passes(fonts_used is None or len(fonts_used) <= 3)
        passed_checks += int(fonts_ok)
        if not fonts_ok:
            self.ats_issues.append({
                "Check_Name": "Font Families",
                "Result": {"description": "More than 3 font families were detected. Sticking to 3 or fewer will maintain ATS-friendly consistency."}
            })

        avg_font_size = self.layout_analysis.get("avg_font_size")
        font_size_ok = passes(avg_font_size is None or 9 <= avg_font_size <= 13)
        passed_checks += int(font_size_ok)
        if not font_size_ok:
            self.ats_issues.append({
                "Check_Name": "Font Size",
                "Result": {"description": "Average font size is outside the recommended 9–13 pt range, which may affect readability in ATS systems. Try adjusting your font size to be between 9 and 13 points."}
            })

        word_count = self.layout_analysis.get("word_count")
        word_count_ok = passes(word_count is None or word_count <= 1000)
        passed_checks += int(word_count_ok)
        if not word_count_ok:
            self.ats_issues.append({
                "Check_Name": "Word Count",
                "Result": {"description": "Your CV is a bit word-heavy (over 1000 words). Cutting it down will help highlight your strongest points more clearly."}
            })

        # 2. Page Setup (4)
        page_sizes = self.layout_analysis.get("page_sizes_in_points")
        page_size_ok = self._is_standard_page_size(page_sizes)
        passed_checks += int(page_size_ok)
        if not page_size_ok:
            self.ats_issues.append({
                "Check_Name": "Page Size",
                "Result": {"description": "Non-standard page size detected. Use A4 or Letter format to ensure ATS compatibility."}
            })

        page_margins = self.layout_analysis.get("page_margins_in_inches")
        margins_ok = self._is_valid_margin_range(page_margins)
        passed_checks += int(margins_ok)
        if not margins_ok:
            self.ats_issues.append({
                "Check_Name": "Page Margins",
                "Result": {"description": "Page margins fall outside the recommended range (0.5–1 inch). Small adjustments will make your layout cleaner and more ATS-friendly."}
            })

        header_info = self.layout_analysis.get("information_in_header")
        no_header_info_ok = header_info is None or not header_info
        passed_checks += int(no_header_info_ok)
        if not no_header_info_ok:
            self.ats_issues.append({
                "Check_Name": "Header Content",
                "Result": {"description": "Some important details are in the header. Moving them into the main body will help ATS systems read them properly."}
            })

        footer_info = self.layout_analysis.get("information_in_footer")
        no_footer_info_ok = footer_info is None or not footer_info
        passed_checks += int(no_footer_info_ok)
        if not no_footer_info_ok:
            self.ats_issues.append({
                "Check_Name": "Footer Content",
                "Result": {"description": "A few key details are in the footer. Bringing them into the main section will improve visibility for ATS parsing."}
            })

        # 3. ATS Parsing Compatibility (5)
        have_tables = self.layout_analysis.get("have_tables")
        tables_ok = have_tables is None or not have_tables
        passed_checks += int(tables_ok)
        if not tables_ok:
            self.ats_issues.append({
                "Check_Name": "Tables",
                "Result": {"description": "You’ve used tables in your CV. Converting them into simple text will help ATS systems read your content more accurately."}
            })

        have_columns = self.layout_analysis.get("have_columns")
        columns_ok = have_columns is None or not have_columns
        passed_checks += int(columns_ok)
        if not columns_ok:
            self.ats_issues.append({
                "Check_Name": "Column Layout",
                "Result": {"description": "A multi-column layout is detected. A single-column format usually works better for ATS systems and improves readability."}
            })

        have_images = self.layout_analysis.get("have_images")
        images_ok = have_images is None or not have_images
        passed_checks += int(images_ok)
        if not images_ok:
            self.ats_issues.append({
                "Check_Name": "Images",
                "Result": {"description": "Your CV includes images. Unless essential, removing them will help ensure ATS systems capture all your information."}
            })

        have_graphics = self.layout_analysis.get("have_graphics")
        graphics_ok = have_graphics is None or not have_graphics
        passed_checks += int(graphics_ok)
        if not graphics_ok:
            self.ats_issues.append({
                "Check_Name": "Graphics/Icons",
                "Result": {"description": "Some icons or graphics are used. Keeping things text-based will make your CV more ATS-friendly and easier to parse."}
            })

        have_textboxes = self.layout_analysis.get("have_textboxes")
        textboxes_ok = have_textboxes is None or not have_textboxes
        passed_checks += int(textboxes_ok)
        if not textboxes_ok:
            self.ats_issues.append({
                "Check_Name": "Textboxes",
                "Result": {"description": "Textboxes are present in your CV. Converting them into regular text will improve ATS readability and avoid missing content."}
            })

        # 4. Valid Date Formats (1)
        valid_date_format = validate_cv_dates(self.cv_text).get("is_valid")
        date_format_ok = valid_date_format is None or valid_date_format
        passed_checks += int(date_format_ok)
        if not date_format_ok:
            self.ats_issues.append({
                "Check_Name": "Date Format",
                "Result": {"description": "Your date formats are a bit inconsistent. Using MM/YYYY or Month YYYY will make your timeline clearer and more ATS-friendly."}
            })

        # 5. File Quality (5)
        file_size_kb = self.layout_analysis.get("file_size_kb")
        file_size_ok = file_size_kb is None or file_size_kb <= 1000
        passed_checks += int(file_size_ok)
        if not file_size_ok:
            self.ats_issues.append({
                "Check_Name": "File Size",
                "Result": {"description": "CV file size is on the heavy side. Compressing it to 1 MB or less will help it upload and process more smoothly."}
            })

        file_type = self.layout_analysis.get("file_type")
        file_type_ok = self._is_ats_file_type(file_type)
        passed_checks += int(file_type_ok)
        if not file_type_ok:
            self.ats_issues.append({
                "Check_Name": "File Type",
                "Result": {"description": "This file format may not be fully supported by ATS systems. PDF or DOCX is the safest choice for reliable parsing."}
            })

        cv_filename = self.layout_analysis.get("original_filename")
        filename_relevant_ok = cv_filename and ("cv" in cv_filename.lower() or "resume" in cv_filename.lower())
        passed_checks += int(filename_relevant_ok)
        if not filename_relevant_ok:
            self.ats_issues.append({
                "Check_Name": "Filename Relevance",
                "Result": {"description": "Your filename doesn’t clearly indicate it's a CV. Adding 'CV' or 'Resume' will make it instantly recognizable to recruiters."}
            })

        valid_cv_filename_length = self.layout_analysis.get("valid_cv_filename_length")
        filename_length_ok = valid_cv_filename_length is None or valid_cv_filename_length
        passed_checks += int(filename_length_ok)
        if not filename_length_ok:
            self.ats_issues.append({
                "Check_Name": "Filename Length",
                "Result": {"description": "CV filename length is too long. Shortening it to under 100 characters will keep it cleaner and easier to manage."}
            })

        original_filename = self.layout_analysis.get("original_filename")
        filename_chars_ok = self._has_no_special_chars(original_filename)
        passed_checks += int(filename_chars_ok)
        if not filename_chars_ok:
            self.ats_issues.append({
                "Check_Name": "Filename Characters",
                "Result": {"description": "Special characters in the filename can sometimes cause issues. Removing them will ensure smoother uploading and compatibility."}
            })

        return min(100, math.ceil((passed_checks / total_checks) * 100)), total_checks, passed_checks

    def calculate_content_quality_score(self):
        """
        This evaluates CV content quality using 13 PASS/FAIL checks.

        Score = (passed ÷ 13) × 100 (rounded up, max 100).

        Checks:

        Essential sections (4): summary, skills, education, experience
        Contact info (4): email, phone, location, name/title
        Content quality (5): structure, action verbs, no pronouns, clarity, and ≥5 quantifiable achievements

        Quantifiable results include: money, people, operations, and achievements (e.g., revenue, team size, efficiency gains).
        """

        self.content_quality_issues = []

        total_checks = 13
        passed_checks = 0

        text = self.cv_text or ""

        # 1. Essential sections exist (4)
        summary_ok = bool(self._norm(self.cv_data.get("summary", "")))
        passed_checks += int(summary_ok)
        if not summary_ok:
            self.content_quality_issues.append({
                "Check_Name": "Professional Summary",
                "Result": {"description": "A professional summary is not found in your CV. Consider adding a short overview of your background and goals."}
            })

        skills_ok = bool(self.cv_data.get("skill_section", []))
        passed_checks += int(skills_ok)
        if not skills_ok:
            self.content_quality_issues.append({
                "Check_Name": "Skills Section",
                "Result": {"description": "No dedicated skills section was detected. Adding one will help highlight your key technical and soft skills."}
            })

        education_ok = bool(self.cv_data.get("education", []))
        passed_checks += int(education_ok)
        if not education_ok:
            self.content_quality_issues.append({
                "Check_Name": "Education Section",
                "Result": {"description": "Your CV does not include an education section. Include your academic background to improve completeness."}
            })

        experience_ok = bool(self.cv_data.get("work_experience", []))
        passed_checks += int(experience_ok)
        if not experience_ok:
            self.content_quality_issues.append({
                "Check_Name": "Work Experience Section",
                "Result": {"description": "Work experience details are missing. Add your previous roles to strengthen your CV."}
            })

        # 2. Contact info present (4)
        email = self.cv_data.get("email", "")
        email_ok = self._is_valid_email(email)
        passed_checks += int(email_ok)
        if not email_ok:
            self.content_quality_issues.append({
                "Check_Name": "Email Address",
                "Result": {"description": "No valid email address was found. Please include a professional contact email."}
            })

        phone = self.cv_data.get("phone", "")
        phone_ok = self._is_valid_phone(phone)
        passed_checks += int(phone_ok)
        if not phone_ok:
            self.content_quality_issues.append({
                "Check_Name": "Phone Number",
                "Result": {"description": "A phone number is not present. Adding one will make it easier for recruiters to contact you."}
            })

        location_ok = bool(self._is_present(self.cv_data.get("location", "")))
        passed_checks += int(location_ok)
        if not location_ok:
            self.content_quality_issues.append({
                "Check_Name": "Location",
                "Result": {"description": "Location information is missing. Consider adding your city or country for better visibility."}
            })

        name_present = bool(self._is_present(self.cv_data.get("name", "")))
        title_present = bool(self._is_present(self.cv_data.get("title", "")))
        identity_ok = name_present and title_present
        passed_checks += int(identity_ok)
        if not identity_ok:
            self.content_quality_issues.append({
                "Check_Name": "Name and Title",
                "Result": {"description": "Your CV is missing either your full name or a professional title. Make sure both are clearly stated."}
            })

        # 3. Content quality (5)
        parsed_content = dict(self.cv_data)
        parsed_content.setdefault("all_sections_order", [])

        checks_dict = check_cv_content_quality(text, parsed_content)
        for check in checks_dict.get("checks", []):
            check_passed = bool(check.get("pass"))
            passed_checks += int(check_passed)
            if check_passed:
                continue

            check_name = str(check.get("name", "Content quality check")).strip()
            check_details = str(check.get("details", "")).strip()

            if check_details:
                first_line = check_details.splitlines()[0].strip()
                sanitized_line = re.sub(r"^[^A-Za-z0-9]+", "", first_line)
                self.content_quality_issues.append({
                    "Check_Name": check_name,
                    "Result": {"description": sanitized_line}
                })
            else:
                self.content_quality_issues.append({
                    "Check_Name": check_name,
                    "Result": {"description": f"{check_name}: failed."}
                })
        

        return min(100, math.ceil((passed_checks / total_checks) * 100)), total_checks, passed_checks
    
    def _norm(self, value):
        return re.sub(r"\s+", " ", str(value or "").strip().lower())

    def _is_present(self, value: Any) -> bool:
        if value is None:
            return False
        if isinstance(value, str):
            return bool(value.strip() and value.strip().lower() not in {"n/a", "na", "none", "null", "unknown"})
        if isinstance(value, (list, tuple, set, dict)):
            return len(value) > 0
        return True

    
    def _is_standard_page_size(self, page_sizes):
        if page_sizes is None:
            return True
        if not page_sizes:
            return True

        # A4 (595x842) and Letter (612x792) with tolerance to extraction noise.
        allowed_sizes = [(595.0, 842.0), (612.0, 792.0)]
        tolerance = 10.0

        for page in page_sizes:
            width = float(page.get("width", 0.0) or 0.0)
            height = float(page.get("height", 0.0) or 0.0)
            match_found = any(
                abs(width - aw) <= tolerance and abs(height - ah) <= tolerance
                or abs(width - ah) <= tolerance and abs(height - aw) <= tolerance
                for aw, ah in allowed_sizes
            )
            if not match_found:
                return False
        return True
    
    def _is_valid_margin_range(self, page_margins):
        if page_margins is None:
            return True
        if not page_margins:
            return True

        for margin in page_margins:
            sides = [
                margin.get("left"),
                margin.get("top"),
                margin.get("right"),
            ]
            bottom_margin = margin.get("bottom")
            if any(side is None for side in sides):
                continue
            if not all(0.5 <= float(side) <= 1.0 for side in sides):
                return False
            if bottom_margin is not None and float(bottom_margin) < 0.5:
                return False
        return True
    
    def _is_ats_file_type(self, file_type):
        if file_type is None:
            return True
        file_type_norm = self._norm(file_type)
        return file_type_norm in {
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "pdf",
            "doc",
            "docx"
        }

    def _has_no_special_chars(self, filename):
        if filename is None:
            return True
        base_name = str(filename).split("/")[-1].split("\\")[-1]
        return bool(re.fullmatch(r"[A-Za-z0-9._\- ]+", base_name))
    
    def _parse_date(self, value):
        text = self._norm(value)
        if not text or text in {"present", "current", "now", "ongoing"}:
            return datetime.utcnow()

        for fmt in ("%b %Y", "%B %Y", "%m/%Y", "%m/%y", "%Y-%m", "%Y"):
            try:
                parsed = datetime.strptime(text, fmt)
                if fmt == "%Y":
                    parsed = parsed.replace(month=1, day=1)
                return parsed
            except ValueError:
                continue

        month_year = re.match(r"([a-zA-Z]+)\s+(\d{4})", text)
        if month_year:
            month_text = month_year.group(1).lower()
            year = int(month_year.group(2))
            month = self._MONTH_MAP.get(month_text)
            if month:
                return datetime(year=year, month=month, day=1)

        return None

    def _is_valid_email(self, email):
        if not email:
            return False
        return re.fullmatch(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", str(email).strip()) is not None

    def _is_valid_phone(self, phone):
        digits = re.sub(r"\D", "", str(phone or ""))
        return len(digits) >= 7

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

FULL_MONTHS = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)
ABBR_MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
SEASONS = ("Spring", "Summer", "Fall", "Winter")

_FM  = "|".join(FULL_MONTHS)           # full month names
_AM  = "|".join(ABBR_MONTHS)           # 3-letter abbreviations
_S   = "|".join(SEASONS)               # season names
_SEP = r"\s*[–-]\s*"                   # en-dash or hyphen, optional spaces

# ---------- atomic date atoms ----------
# Year-only  e.g. 2019 or Present/Current
_YEAR      = r"(?:19|20)\d{2}"
_YEAR_FLEX = rf"(?:{_YEAR}|[Pp]resent|[Cc]urrent)"

# MM/YYYY or MM-YYYY
_MMYYYY    = r"(?:0?[1-9]|1[0-2])[/\-](?:19|20)\d{2}"
# MM/YY (short year)
_MMYY      = r"(?:0?[1-9]|1[0-2])[/\-]\d{2}"
# Full month + year
_FMYYYY    = rf"(?:{_FM})\s+(?:19|20)\d{{2}}"
# Abbreviated month + year
_AMYYYY    = rf"(?:{_AM})\s+(?:19|20)\d{{2}}"
# Season + year
_SYYYY     = rf"(?:{_S})\s+(?:19|20)\d{{2}}"

# "Expected …" prefix variants
_EXP_ATOM  = rf"(?:{_SYYYY}|{_FMYYYY}|{_AMYYYY}|{_MMYYYY}|{_MMYY}|{_YEAR})"
_EXPECTED  = rf"Expected\s+{_EXP_ATOM}"

# Any single standalone date (no range)
_SINGLE    = rf"(?:{_EXPECTED}|{_SYYYY}|{_FMYYYY}|{_AMYYYY}|{_MMYYYY}|{_MMYY}|{_YEAR_FLEX})"

# A range: <date> – <date or Present>
_RANGE     = rf"(?:{_SYYYY}|{_FMYYYY}|{_AMYYYY}|{_MMYYYY}|{_MMYY}|{_YEAR}){_SEP}(?:{_SYYYY}|{_FMYYYY}|{_AMYYYY}|{_MMYYYY}|{_MMYY}|{_YEAR_FLEX})"

DATE_PATTERN = re.compile(
    rf"\b(?:{_RANGE}|{_SINGLE})\b",
    re.IGNORECASE,
)

# ---------- bad-pattern detectors ----------
# Day included: DD/MM/YYYY, MM/DD/YYYY, etc.
BAD_WITH_DAY = re.compile(
    r"\b(?:\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}|\d{4}[/\-]\d{1,2}[/\-]\d{1,2})\b"
)
# Month only (no year near it)
BAD_MONTH_ONLY = re.compile(
    rf"\b(?:{_FM}|{_AM})\b(?!\s+(?:19|20)\d{{2}})",
    re.IGNORECASE,
)
# Bad separator: "to", "until", "through" between years
BAD_WORD_SEP = re.compile(
    rf"(?:{_YEAR}|{_AM}|{_FM}|{_S})\s+\d{{4}}\s+(?:to|until|through)\s+",
    re.IGNORECASE,
)
# No space around dash/en-dash in a range  e.g. "2016-2019"
BAD_NO_SPACE_SEP = re.compile(r"(?<!\s)[–-](?!\s)")
# Abbreviated month with trailing period  e.g. "Sept." or "Jan."
BAD_ABBR_PERIOD = re.compile(
    rf"\b(?:{'|'.join(ABBR_MONTHS)})\.",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Format-family classifier
# ---------------------------------------------------------------------------
def _classify(date_str: str) -> str:
    """Return a format-family tag for a matched date string."""
    s = date_str.strip()
    if re.match(r"^Expected\b", s, re.IGNORECASE):
        return "expected"
    if re.search(rf"\b(?:{_S})\b", s, re.IGNORECASE):
        return "season_year"
    if re.search(rf"\b(?:{_FM})\b", s):
        return "full_month_year"
    if re.search(rf"\b(?:{_AM})\b", s):
        return "abbr_month_year"
    if re.search(r"\d{1,2}[/\-](?:19|20)\d{2}", s):
        return "mm_yyyy"
    if re.search(r"\d{1,2}[/\-]\d{2}\b", s):
        return "mm_yy"
    return "year_only"

def validate_cv_dates(cv_text: str) -> dict[str, Any]:
    """
    Validate all date expressions found in *cv_text* against the resume
    date-format rules from resumeworded.com.

    Parameters
    ----------
    cv_text : str
        Raw text extracted from a CV / resume.

    Returns
    -------
    dict[str, Any]
        Contains validity flag, found dates, format families, errors, warnings.
    """
    errors:   list[str] = []
    warnings: list[str] = []

    # 1. Detect outright bad patterns ----------------------------------------
    for m in BAD_WITH_DAY.finditer(cv_text):
        errors.append(
            f"Exact day included (not allowed on resumes): '{m.group()}'"
        )

    for m in BAD_WORD_SEP.finditer(cv_text):
        errors.append(
            f"Word separator ('to'/'until'/'through') used instead of dash: '{m.group().strip()}'"
        )

    for m in BAD_ABBR_PERIOD.finditer(cv_text):
        errors.append(
            f"Month abbreviation should not have a trailing period: '{m.group()}'"
        )

    # 2. Check for bad no-space separators (heuristic: year-dash-year) --------
    no_space = re.findall(r"(?:19|20)\d{2}[–-](?:19|20)\d{2}", cv_text)
    for hit in no_space:
        errors.append(
            f"Date range missing spaces around separator: '{hit}' "
            f"(should be e.g. '2016 – 2019')"
        )

    # 3. Extract valid date matches -------------------------------------------
    dates_found: list[str] = []
    families:    list[str] = []

    for m in DATE_PATTERN.finditer(cv_text):
        token = m.group().strip()
        # Skip tokens that are only a bare 2-digit number (false positives)
        if re.fullmatch(r"\d{1,2}", token):
            continue
        dates_found.append(token)
        families.append(_classify(token))

    # 4. Consistency check ----------------------------------------------------
    if dates_found:
        # Ignore "expected" and "year_only" when checking cross-section consistency
        # (the article explicitly allows year-only for old jobs alongside month+year)
        core_families = [f for f in families if f not in ("expected",)]
        unique_core = set(core_families)

        # Incompatible mix: e.g. full_month_year AND abbr_month_year in same doc
        incompatible_pairs = [
            {"full_month_year", "abbr_month_year"},
            {"mm_yyyy", "mm_yy"},
            {"season_year", "mm_yyyy"},
            {"season_year", "mm_yy"},
            {"season_year", "full_month_year"},
            {"season_year", "abbr_month_year"},
        ]
        for pair in incompatible_pairs:
            if pair.issubset(unique_core):
                errors.append(
                    f"Inconsistent date formats detected: "
                    f"{sorted(pair)} — pick one and use it throughout."
                )

        # Warn (not error) about mixing year-only with month+year
        # (article says it's acceptable for older positions)
        if "year_only" in unique_core and len(unique_core) > 1:
            warnings.append(
                "Year-only dates are mixed with month+year dates. "
                "This is acceptable for older/distant positions, but ensure "
                "it's not being used to hide short tenures."
            )

    is_valid = len(errors) == 0
    return {
        "is_valid": is_valid,
        "dates_found": dates_found,
        "format_families": families,
        "errors": errors,
        "warnings": warnings
    }
    