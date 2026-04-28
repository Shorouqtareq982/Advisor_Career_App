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
        # job_alignment_score = self.calculate_job_alignment_score() if self.jd_data else None

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
        
        SCORING FORMULA:
        Score = (Number_of_Passed_Checks / Total_Number_of_Checks) * 100
        Round UP to nearest integer. Maximum score: 100.
        
        CHECK CATEGORIES:
        
        1. STRUCTURE & FORMATTING (4 checks):
        - Number of pages ≤ 2 → PASS / FAIL
        - ≤ 3 font families used → PASS / FAIL
        - Average font size between 9 and 13 points → PASS / FAIL
        - Word count ≤ 1000 → PASS / FAIL
        
        2. PAGE SETUP (4 checks):
        - Standard page size (e.g. A4, Letter) → PASS / FAIL
        - Margins between 0.5 and 1 inch → PASS / FAIL
        - No information in header → PASS / FAIL
        - No information in footer → PASS / FAIL
        
        3. ATS PARSING COMPATIBILITY (5 checks):
        - Tables absent or non-disruptive → PASS / FAIL
        - Columns absent → PASS / FAIL
        - Images absent or relevant → PASS / FAIL
        - Graphics/drawings/icons absent → PASS / FAIL
        - Textboxes absent → PASS / FAIL
        
        4. VALID DATE FORMATS (1 check):
        - Date format: MM/YY or MM/YYYY or Month YYYY (e.g. 03/18, 03/2019, Mar 2019) → PASS / FAIL
        
        5. FILE QUALITY (5 checks):
        - File size ≤ 5000 KB → PASS / FAIL
        - File type is PDF or DOCX → PASS / FAIL
        - File name is CV-relevant (contains "CV" or "Resume" or candidate name) → PASS / FAIL
        - File name length ≤ 100 characters → PASS / FAIL
        - File name does not contain special characters → PASS / FAIL
        
        RULE: If a CVLayoutAnalysis field is null/None, treat it as PASS.
        """ 
        self.ats_issues = []

        total_checks = 19
        passed_checks = 0

        def passes(value):
            return value is None or bool(value)

        # 1. Structure & Formatting (4)
        num_of_pages = self.layout_analysis.get("num_of_pages")
        pages_ok = passes(num_of_pages is None or num_of_pages <= 2)
        passed_checks += int(pages_ok)
        if not pages_ok:
            self.ats_issues.append({
                "Check_Name": "Page Count",
                "Result": {"description": "Your CV has more than 2 pages and it should be 2 pages or fewer."}
            })

        fonts_used = self.layout_analysis.get("fonts_used")
        fonts_ok = passes(fonts_used is None or len(fonts_used) <= 3)
        passed_checks += int(fonts_ok)
        if not fonts_ok:
            self.ats_issues.append({
                "Check_Name": "Font Families",
                "Result": {"description": "Your CV has more than 3 font families and they should be 3 or fewer for ATS readability."}
            })

        avg_font_size = self.layout_analysis.get("avg_font_size")
        font_size_ok = passes(avg_font_size is None or 9 <= avg_font_size <= 13)
        passed_checks += int(font_size_ok)
        if not font_size_ok:
            self.ats_issues.append({
                "Check_Name": "Font Size",
                "Result": {"description": "Your CV has an average font size outside the range and it should be between 9 and 13 pt."}
            })

        word_count = self.layout_analysis.get("word_count")
        word_count_ok = passes(word_count is None or word_count <= 1000)
        passed_checks += int(word_count_ok)
        if not word_count_ok:
            self.ats_issues.append({
                "Check_Name": "Word Count",
                "Result": {"description": "Your CV has more than 1000 words and it should be kept at 1000 words or fewer."}
            })

        # 2. Page Setup (4)
        page_sizes = self.layout_analysis.get("page_sizes_in_points")
        page_size_ok = self._is_standard_page_size(page_sizes)
        passed_checks += int(page_size_ok)
        if not page_size_ok:
            self.ats_issues.append({
                "Check_Name": "Page Size",
                "Result": {"description": "Your CV has a non-standard page size and it should use standard page size like A4 or Letter."}
            })

        page_margins = self.layout_analysis.get("page_margins_in_inches")
        margins_ok = self._is_valid_margin_range(page_margins)
        passed_checks += int(margins_ok)
        if not margins_ok:
            self.ats_issues.append({
                "Check_Name": "Page Margins",
                "Result": {"description": "Your CV has page margins outside the range and they should be between 0.5 and 1.0 inches."}
            })

        header_info = self.layout_analysis.get("information_in_header")
        no_header_info_ok = header_info is None or not header_info
        passed_checks += int(no_header_info_ok)
        if not no_header_info_ok:
            self.ats_issues.append({
                "Check_Name": "Header Content",
                "Result": {"description": "Your CV has important content in the header and it should be removed for proper ATS parsing."}
            })

        footer_info = self.layout_analysis.get("information_in_footer")
        no_footer_info_ok = footer_info is None or not footer_info
        passed_checks += int(no_footer_info_ok)
        if not no_footer_info_ok:
            self.ats_issues.append({
                "Check_Name": "Footer Content",
                "Result": {"description": "Your CV has important content in the footer and it should be removed for proper ATS parsing."}
            })

        # 3. ATS Parsing Compatibility (5)
        have_tables = self.layout_analysis.get("have_tables")
        tables_ok = have_tables is None or not have_tables
        passed_checks += int(tables_ok)
        if not tables_ok:
            self.ats_issues.append({
                "Check_Name": "Tables",
                "Result": {"description": "Your CV has tables and they should be avoided to improve ATS parsing compatibility."}
            })

        have_columns = self.layout_analysis.get("have_columns")
        columns_ok = have_columns is None or not have_columns
        passed_checks += int(columns_ok)
        if not columns_ok:
            self.ats_issues.append({
                "Check_Name": "Column Layout",
                "Result": {"description": "Your CV has multi-column layouts and they should be avoided for proper ATS parsing."}
            })

        have_images = self.layout_analysis.get("have_images")
        images_ok = have_images is None or not have_images
        passed_checks += int(images_ok)
        if not images_ok:
            self.ats_issues.append({
                "Check_Name": "Images",
                "Result": {"description": "Your CV has images and they should be avoided unless essential, as ATS may skip them."}
            })

        have_graphics = self.layout_analysis.get("have_graphics")
        graphics_ok = have_graphics is None or not have_graphics
        passed_checks += int(graphics_ok)
        if not graphics_ok:
            self.ats_issues.append({
                "Check_Name": "Graphics/Icons",
                "Result": {"description": "Your CV has graphics or icons and they should be avoided for better ATS readability."}
            })

        have_textboxes = self.layout_analysis.get("have_textboxes")
        textboxes_ok = have_textboxes is None or not have_textboxes
        passed_checks += int(textboxes_ok)
        if not textboxes_ok:
            self.ats_issues.append({
                "Check_Name": "Textboxes",
                "Result": {"description": "Your CV has textboxes and they should be avoided as they can break ATS extraction."}
            })

        # 4. Valid Date Formats (1)
        valid_date_format = self.layout_analysis.get("valid_date_format")
        date_format_ok = valid_date_format is None or valid_date_format
        passed_checks += int(date_format_ok)
        if not date_format_ok:
            self.ats_issues.append({
                "Check_Name": "Date Format",
                "Result": {"description": "Your CV has inconsistent date formats and they should be MM/YYYY or Month YYYY."}
            })

        # 5. File Quality (5)
        file_size_kb = self.layout_analysis.get("file_size_kb")
        file_size_ok = file_size_kb is None or file_size_kb <= 5000
        passed_checks += int(file_size_ok)
        if not file_size_ok:
            self.ats_issues.append({
                "Check_Name": "File Size",
                "Result": {"description": "Your CV file size is too large and it should be 5000 KB or less."}
            })

        file_type = self.layout_analysis.get("file_type")
        file_type_ok = self._is_ats_file_type(file_type)
        passed_checks += int(file_type_ok)
        if not file_type_ok:
            self.ats_issues.append({
                "Check_Name": "File Type",
                "Result": {"description": "Your CV is in an unsupported file format and it should be PDF or DOCX."}
            })

        valid_cv_filename = self.layout_analysis.get("valid_cv_filename")
        filename_relevant_ok = valid_cv_filename is None or valid_cv_filename
        passed_checks += int(filename_relevant_ok)
        if not filename_relevant_ok:
            self.ats_issues.append({
                "Check_Name": "Filename Relevance",
                "Result": {"description": "Your CV filename is not CV-relevant and it should contain CV or Resume."}
            })

        valid_cv_filename_length = self.layout_analysis.get("valid_cv_filename_length")
        filename_length_ok = valid_cv_filename_length is None or valid_cv_filename_length
        passed_checks += int(filename_length_ok)
        if not filename_length_ok:
            self.ats_issues.append({
                "Check_Name": "Filename Length",
                "Result": {"description": "Your CV filename is too long and it should be 100 characters or fewer."}
            })

        original_filename = self.layout_analysis.get("original_filename")
        filename_chars_ok = self._has_no_special_chars(original_filename)
        passed_checks += int(filename_chars_ok)
        if not filename_chars_ok:
            self.ats_issues.append({
                "Check_Name": "Filename Characters",
                "Result": {"description": "Your CV filename contains special characters and it should avoid them."}
            })

        return min(100, math.ceil((passed_checks / total_checks) * 100)), total_checks, passed_checks

    
    def calculate_job_alignment_score(self):
        """
        Evaluation of how well the resume matches the job description across skills, experience, and keywords.
        
        MATCHING FORMULA:
        Match_Score = Title/Education/Experience_Level_Alignment + Skills_Score + Keyword_Score + Experience_Score
        
        SCORING WEIGHTS (Total: 100 points):
        1. Title Match: 5 points (compare CV title with JD title)
        2. Education Level Match: 5 points (compare degree level with JD requirements)
        3. Experience Level Match: 5 points (compare years/level with JD expectations)
        4. Skills Alignment: 30 points (formula below)
        5. Keyword Alignment: 30 points (formula below)
        6. Experience Alignment: 25 points (formula below)
        
        DETAILED CALCULATIONS:
        
        1. Title/Education/Experience Level Alignment (0-15 points):
        - Title Match → True = 5 points, False = 0 points
        - Education Level Match → True = 5 points, False = 0 points
        - Experience Level Match → True = 5 points, False = 0 points
        
        2. Skills Alignment (0-30 points):
        - Extract required skills from JD
        - Extract skills from CV
        - Count matched skills (normalize case, ignore duplicates)
        - Formula: Skills_Score = (Matched_Skills / Total_Required_Skills) * 30
        - Round UP to nearest integer
        - Max: 30 points
        
        3. Keyword Alignment (0-30 points):
        - Extract important keywords from JD (tools, technologies, domain terms, methodologies)
        - Count matched keywords in CV (normalize case, ignore duplicates)
        - Formula: Keyword_Score = (Matched_Keywords / Total_Keywords) * 30
        - Round UP to nearest integer
        - Max: 30 points
        
        4. Experience Alignment (0-25 points):
        - Compare CV experience descriptions with JD responsibilities
        - Count matched responsibilities/achievements
        - Formula: Experience_Score = (Matched_Responsibilities / Total_Responsibilities) * 25
        - Round UP to nearest integer
        - Max: 25 points
        
        MATCHING RULES:
        - Count only explicit matches from CV (do not infer)
        - Normalize case when matching (Python = python)
        - Ignore duplicate matches (count each match once)
        - Use only skills/keywords/experience clearly stated in CV and JD
        - Do not assume skills/experience not written in CV
        
        MAX SCORE LIMIT:
        Final Match_Score = min(calculated_score, 100)
        """
        base_score = 0

        cv_title = self._norm(self.cv_data.get("title", ""))
        jd_title = self._norm(self.jd_data.get("job_title", ""))
        title_match = self._fuzzy_phrase_match(cv_title, jd_title)
        base_score += 5 if title_match else 0

        cv_education_levels = self._extract_education_levels_from_cv()
        jd_education_levels = self._extract_education_levels_from_jd()
        edu_match = not jd_education_levels or bool(cv_education_levels & jd_education_levels)
        base_score += 5 if edu_match else 0

        cv_years = self._estimate_cv_experience_years()
        min_years, max_years = self._extract_experience_range()
        exp_match = self._is_experience_in_range(cv_years, min_years, max_years)
        base_score += 5 if exp_match else 0

        cv_skill_set = self._extract_cv_skills()
        required_skills = self._normalize_set(self.jd_data.get("required_skills", []))
        matched_required = len(cv_skill_set & required_skills)
        skills_score = self._ratio_score(matched_required, len(required_skills), 30)

        cv_corpus = self._build_cv_text_corpus()
        jd_keywords = self._normalize_set(self.jd_data.get("keywords", []))
        matched_keywords = sum(1 for kw in jd_keywords if self._phrase_in_text(kw, cv_corpus))
        keyword_score = self._ratio_score(matched_keywords, len(jd_keywords), 30)

        responsibilities = self._normalize_set(self.jd_data.get("job_duties_and_responsibilities", []))
        matched_responsibilities = 0
        for responsibility in responsibilities:
            if self._text_overlap_match(responsibility, cv_corpus):
                matched_responsibilities += 1
        experience_score = self._ratio_score(matched_responsibilities, len(responsibilities), 25)

        return min(100, base_score + skills_score + keyword_score + experience_score)

    
    def calculate_content_quality_score(self):
        """
        Detailed analysis of content quality factors with specific checks and messages.
        
        TOTAL CHECKS: 13
        
        SCORING FORMULA:
        Score = (Number_of_Passed_Checks / Total_Number_of_Checks) * 100
        Round UP to nearest integer. Maximum score: 100.
        
        CHECK CATEGORIES:
        
        1. ESSENTIAL SECTIONS EXIST (4 checks):
        - Summary section present → PASS / FAIL
        - Skills section present → PASS / FAIL
        - Education section present → PASS / FAIL
        - Work Experience section present → PASS / FAIL
        
        2. CONTACT INFO PRESENT (4 checks):
        - Email provided → PASS / FAIL
        - Phone number provided → PASS / FAIL
        - Address/Location provided → PASS / FAIL
        - Name and professional title exist → PASS / FAIL
        
        3. CONTENT QUALITY (5 checks):
        - Headings in logical order and clearly defined → PASS / FAIL
        - Spelling and grammar correct (typos <= 2) → PASS / FAIL
        - Action verbs used, no personal pronouns (I, me, my) → PASS / FAIL
        - Clear and specific wording (no vague/generic phrases) → PASS / FAIL
        - Quantifiable impact: At least 5 measurable results across experiences/projects → PASS / FAIL
        
        QUANTIFIABLE METRICS CATEGORIES (for check #13):
        Count measurable results across these categories:
        1. Money/Finance: sales volume, revenue %, cost savings, budgets managed
        2. People: customers served/retained, direct reports, teams led, people hired
        3. Tasks/Operations: efficiency improvements, process improvements, time saved, volume of tasks
        4. Other: awards, publications, recognitions
        
        Minimum 5 measurable results required to PASS check #13.
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
                "Result": {"description": "Your CV is missing a professional summary section and it should include one."}
            })

        skills_ok = bool(self.cv_data.get("skill_section", []))
        passed_checks += int(skills_ok)
        if not skills_ok:
            self.content_quality_issues.append({
                "Check_Name": "Skills Section",
                "Result": {"description": "Your CV is missing a dedicated skills section and it should include one."}
            })

        education_ok = bool(self.cv_data.get("education", []))
        passed_checks += int(education_ok)
        if not education_ok:
            self.content_quality_issues.append({
                "Check_Name": "Education Section",
                "Result": {"description": "Your CV is missing an education section and it should include one."}
            })

        experience_ok = bool(self.cv_data.get("work_experience", []))
        passed_checks += int(experience_ok)
        if not experience_ok:
            self.content_quality_issues.append({
                "Check_Name": "Work Experience Section",
                "Result": {"description": "Your CV is missing a work experience section and it should include one."}
            })

        # 2. Contact info present (4)
        email = self.cv_data.get("email", "")
        email_ok = self._is_valid_email(email)
        passed_checks += int(email_ok)
        if not email_ok:
            self.content_quality_issues.append({
                "Check_Name": "Email Address",
                "Result": {"description": "Your CV is missing a valid email address and it should include one."}
            })

        phone = self.cv_data.get("phone", "")
        phone_ok = self._is_valid_phone(phone)
        passed_checks += int(phone_ok)
        if not phone_ok:
            self.content_quality_issues.append({
                "Check_Name": "Phone Number",
                "Result": {"description": "Your CV is missing a valid phone number and it should include one."}
            })

        location_ok = bool(self._is_present(self.cv_data.get("location", "")))
        passed_checks += int(location_ok)
        if not location_ok:
            self.content_quality_issues.append({
                "Check_Name": "Location",
                "Result": {"description": "Your CV is missing location information and it should include your location or address."}
            })

        name_present = bool(self._is_present(self.cv_data.get("name", "")))
        title_present = bool(self._is_present(self.cv_data.get("title", "")))
        identity_ok = name_present and title_present
        passed_checks += int(identity_ok)
        if not identity_ok:
            self.content_quality_issues.append({
                "Check_Name": "Name and Title",
                "Result": {"description": "Your CV is missing your full name or professional title and it should include both."}
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
    
    def _normalize_set(self, items):
        normalized = set()
        for item in items or []:
            text = self._norm(item)
            if text:
                normalized.add(text)
        return normalized

    
    def _ratio_score(self,matched, total, max_points):
        if total <= 0:
            return 0
        return min(max_points, math.ceil((matched / total) * max_points))

    
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
                margin.get("bottom"),
            ]
            if any(side is None for side in sides):
                continue
            if not all(0.5 <= float(side) <= 1.0 for side in sides):
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

    
    def _phrase_in_text(self, phrase, text):
        if not phrase:
            return False
        pattern = r"\b" + re.escape(phrase) + r"\b"
        return re.search(pattern, text) is not None

    
    def _fuzzy_phrase_match(self, a, b):
        if not a or not b:
            return False
        if a in b or b in a:
            return True
        a_tokens = {t for t in re.split(r"\W+", a) if t}
        b_tokens = {t for t in re.split(r"\W+", b) if t}
        if not a_tokens or not b_tokens:
            return False
        overlap = len(a_tokens & b_tokens)
        denom = max(1, min(len(a_tokens), len(b_tokens)))
        return (overlap / denom) >= 0.6

    
    def _extract_education_levels_from_cv(self):
        levels = set()
        for edu in self.cv_data.get("education", []) or []:
            degree = self._norm(edu.get("degree", ""))
            if "phd" in degree or "doctor" in degree:
                levels.add("doctorate")
            if "master" in degree or "msc" in degree or "m.sc" in degree or "mba" in degree:
                levels.add("master")
            if "bachelor" in degree or "bsc" in degree or "b.sc" in degree:
                levels.add("bachelor")
            if "diploma" in degree:
                levels.add("diploma")
            if "high school" in degree or "secondary school" in degree or "highschool" in degree:
                levels.add("high_school")
        return levels

    
    def _extract_education_levels_from_jd(self):
        levels = set()
        fields = [
            *(self.jd_data.get("education_requirements", []) or []),
            *(self.jd_data.get("required_qualifications", []) or []),
            *(self.jd_data.get("preferred_qualifications", []) or []),
        ]
        for field in fields:
            text = self._norm(field)
            if "phd" in text or "doctor" in text:
                levels.add("doctorate")
            if "master" in text or "msc" in text or "m.sc" in text or "mba" in text:
                levels.add("master")
            if "bachelor" in text or "bsc" in text or "b.sc" in text:
                levels.add("bachelor")
            if "diploma" in text or "associate" in text:
                levels.add("diploma")
            if "high school" in text or "secondary school" in text or "highschool" in text:
                levels.add("high_school")
        return levels

    
    def _extract_experience_range(self):
        min_years = self._extract_first_number(self.jd_data.get("minimum_experience", ""))
        max_years = self._extract_first_number(self.jd_data.get("maximum_experience", ""))
        return min_years, max_years

    
    def _extract_first_number(self, text):
        match = re.search(r"(\d+(?:\.\d+)?)", str(text or ""))
        return float(match.group(1)) if match else None

    
    def _estimate_cv_experience_years(self):

        total_months = 0
        for exp in self.cv_data.get("work_experience", []) or []:
            start = self._parse_date(exp.get("from_date", ""))
            end = self._parse_date(exp.get("to_date", ""))
            if start is None:
                continue
            if end is None:
                end = datetime.utcnow()
            months = max(0, (end.year - start.year) * 12 + (end.month - start.month))
            total_months += months
        return total_months / 12.0

    
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

    
    def _is_experience_in_range(self, cv_years, min_years, max_years):
        if min_years is None and max_years is None:
            return True
        if min_years is not None and cv_years < min_years:
            return False
        if max_years is not None and cv_years > max_years:
            return False
        return True

    
    def _extract_cv_skills(self):
        skills = set()
        for section in self.cv_data.get("skill_section", []) or []:
            for skill in section.get("skills", []) or []:
                normalized = self._norm(skill)
                if normalized:
                    skills.add(normalized)
        return skills

    
    def _build_cv_text_corpus(self):
        parts = [
            self.cv_data.get("name", ""),
            self.cv_data.get("title", ""),
            self.cv_data.get("summary", ""),
        ]

        for exp in self.cv_data.get("work_experience", []) or []:
            parts.append(exp.get("role", ""))
            parts.append(exp.get("company", ""))
            parts.extend(exp.get("description", []) or [])

        for proj in self.cv_data.get("projects", []) or []:
            parts.append(proj.get("name", ""))
            parts.extend(proj.get("description", []) or [])

        for section in self.cv_data.get("skill_section", []) or []:
            parts.append(section.get("name", ""))
            parts.extend(section.get("skills", []) or [])

        parts.extend(self.cv_data.get("achievements", []) or [])
        return self._norm(" ".join(str(p) for p in parts if p))

    
    def _text_overlap_match(self,target, source_text):
        target = self._norm(target)
        if not target:
            return False
        if self._phrase_in_text(target, source_text):
            return True

        target_tokens = {t for t in re.split(r"\W+", target) if len(t) > 2}
        if not target_tokens:
            return False
        matched_tokens = {t for t in target_tokens if self._phrase_in_text(t, source_text)}
        return (len(matched_tokens) / len(target_tokens)) >= 0.6

    
    def _is_valid_email(self, email):
        if not email:
            return False
        return re.fullmatch(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", str(email).strip()) is not None

    
    def _is_valid_phone(self, phone):
        digits = re.sub(r"\D", "", str(phone or ""))
        return len(digits) >= 7

