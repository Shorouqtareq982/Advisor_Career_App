import re
from typing import Dict


# Canonical section names and their variations
SECTION_PATTERNS = {
    'summary': [
        'summary', 'professional summary', 'executive summary', 'career summary',
        'objective', 'career objective', 'professional objective',
        'profile', 'about me', 'overview'
    ],
    'education': [
        'education', 'academic background', 'academic qualifications', 'qualifications',
        'degrees', 'degree', 'university', 'college', 'schooling'
    ],
    'experience': [
        'experience', 'work experience', 'professional experience', 'employment experience',
        'work history', 'employment history', 'career history',
        'positions held', 'employment', 'professional background', 'experience summary'
    ],
    'internships': [
        'internships', 'internship experience', 'internships experience'
    ],
    'skills': [
        'skills', 'technical skills', 'soft skills', 'core skills', 'key skills',
        'professional skills', 'competency', 'competencies',
        'expertise', 'proficiencies', 'capabilities'
    ],
    'projects': [
        'projects', 'personal projects', 'key projects',
        'notable projects', 'portfolio'
    ],
    'certifications': [
        'certifications', 'certificates', 'certification',
        'licenses and certifications', 'credentials',
        'accreditations', 'professional development'
    ],
    'awards': [
        'awards', 'achievements', 'honors', 'recognitions',
        'accomplishments', 'distinctions'
    ],
    'publications': [
        'publications', 'papers', 'research', 'journals',
        'articles', 'conference papers'
    ],
    'languages': [
        'languages', 'language proficiency', 'linguistic skills'
    ],
    'volunteer': [
        'volunteer', 'volunteering', 'volunteer experience',
        'community service', 'community involvement',
        'civic activities', 'social activities'
    ],
    'interests': [
        'interests', 'hobbies', 'personal interests', 'extracurricular',
        'hobbies and interests'
    ],
    'references': [
        'references', 'referees'
    ],
    'contact': [
        'contact', 'contact information', 'contact details',
        'personal information', 'personal details'
    ],
}

def add_newlines_around_headers(text: str) -> str:
    """
    Add newline BEFORE and AFTER section headers safely.

    Only matches headers that appear in:
    - Title Case   -> "Professional Summary"
    - UPPERCASE    -> "PROFESSIONAL SUMMARY"

    Ignores:
    - lowercase inline words
    - random partial matches

    Examples:
    ----------------------------------------
    "solutions.Work Experience Developer..."
    ->
    "solutions.\nWork Experience\nDeveloper..."

    "SKILLS Python SQL..."
    ->
    "SKILLS\nPython SQL..."
    """

    headers = []

    for variants in SECTION_PATTERNS.values():
        headers.extend(variants)

    # -----------------------------------------------------
    # Sort longest first to avoid partial matching
    # -----------------------------------------------------

    headers = sorted(set(headers), key=len, reverse=True)

    # -----------------------------------------------------
    # Build explicit Title Case + UPPERCASE variants
    # -----------------------------------------------------

    header_variants = []

    for h in headers:
        header_variants.append(re.escape(h.title()))
        header_variants.append(re.escape(h.upper()))

    header_pattern = "|".join(
        sorted(set(header_variants), key=len, reverse=True)
    )

    # =====================================================
    # Add newline BEFORE headers
    #
    # Example:
    # "...solutions.Work Experience"
    # ->
    # "...solutions.\nWork Experience"
    # =====================================================

    text = re.sub(
        rf"""
        (?<!\n)                 # not already on new line
        (?<!^)                  # not start of text
        \s*
        (
            {header_pattern}
        )
        \b
        """,
        r"\n\1",
        text,
        flags=re.VERBOSE
    )

    # =====================================================
    # Add newline AFTER headers
    #
    # Example:
    # "Professional Summary Innovative..."
    # ->
    # "Professional Summary\nInnovative..."
    # =====================================================

    text = re.sub(
        rf"""
        \b
        (
            {header_pattern}
        )
        \b
        [ \t]+
        (?=[A-Z0-9•\-])
        """,
        r"\1\n",
        text,
        flags=re.VERBOSE
    )

    return text


def normalize_text(text: str) -> str:

    text = text.replace("\r\n", "\n").replace("\r", "\n")

    text = re.sub(r"[\u200b-\u200d\ufeff]", "", text)
    # text = re.sub(r"([.,;:])([A-Za-z])", r"\1 \2", text)
    text = re.sub(r"[•●▪■]", "\n- ", text)

    text = add_newlines_around_headers(text)

    # ----------------------------------------
    # Normalize excessive newlines
    # ----------------------------------------
    text = re.sub(r"\n{3,}", "\n\n", text)

    # Normalize excessive newlines
    text = re.sub(r"\n{3,}", "\n\n", text)

    # 7. Remove URLs (optional but recommended for parsing)
    text = re.sub(r"https?://\S+", "", text)

    # Trim lines
    lines = [line.strip() for line in text.split("\n")]

    return "\n".join(lines).strip()

def compute_similarity(a: str, b: str) -> float:

        if a == b:
            return 1.0

        if b in a:
            return 0.92

        a_words = set(a.split())
        b_words = set(b.split())

        if not a_words or not b_words:
            return 0.0

        overlap = len(a_words & b_words)

        score = overlap / max(len(b_words), 1)

        return score

def detect_sections(text: str) -> Dict:
        text = normalize_text(text)

        lines = text.splitlines()

        results = {}
        sections_found = set()

        for section_name, variants in SECTION_PATTERNS.items():

            best_match = None
            best_confidence = 0.0

            for line in lines:

                clean = line.strip().lower().rstrip(":")

                for variant in variants:

                    confidence = compute_similarity(
                        clean,
                        variant.lower()
                    )

                    if confidence > best_confidence:
                        best_confidence = confidence
                        best_match = line.strip()

            found = best_confidence >= 0.82

            sections_found.add(section_name.upper()) if found else None

            results[section_name.upper()] = {
                "found": found,
                "confidence": round(best_confidence, 2),
                "matched_header": best_match if found else None
            }

        results["sections_found"] = sorted(list(sections_found))
        return results

