import re
from typing import Optional
from presidio_analyzer import AnalyzerEngine, RecognizerResult, PatternRecognizer, Pattern
from presidio_anonymizer import AnonymizerEngine

# Initialize once
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

ORG_KEYWORDS = {
    "university",
    "college",
    "institute",
    "school",
    "faculty",
    "department",
    "academy",
    "center",
    "centre",
    "laboratory",
    "lab",
    "research group",
    "research center",
    "research centre",
    "hospital",
}

COMPANY_SUFFIXES = {
    "inc",
    "inc.",
    "corp",
    "corp.",
    "corporation",
    "company",
    "co",
    "co.",
    "ltd",
    "ltd.",
    "llc",
    "plc",
    "gmbh",
    "ag",
}

TECH_SKILLS = {
    "python",
    "java",
    "javascript",
    "typescript",
    "c",
    "c++",
    "c#",
    "php",
    "ruby",
    "go",
    "golang",
    "rust",
    "kotlin",
    "swift",
    "scala",
    "r",
    "matlab",
    "linux",
    "json",
    "js",
    "ajax",
    "singleton",
    "html5",
    "log4j",
    "build",
    "sql",
    "nosql",
    "mongodb",
    "postgresql",
    "mysql",
    "oracle",
    "sqlite",
    "redis",
    "docker",
    "kubernetes",
    "aws",
    "azure",
    "gcp",
    "tensorflow",
    "pytorch",
    "keras",
    "pandas",
    "numpy",
    "scikit-learn",
    "sklearn",
    "opencv",
    "fastapi",
    "django",
    "flask",
    "spring",
    "angular",
    "react",
    "vue",
    "nodejs",
    "git",
    "github",
    "linkedin",
    "devpost",
    "medium",
    "linux",
    "deep learning",
    "nltk",
    "s3",
    "docker",
    "postman",
}

CERTIFICATIONS = {
    "aws certified",
    "azure fundamentals",
    "azure administrator",
    "ccna",
    "ccnp",
    "comptia",
    "security+",
    "network+",
    "pmp",
    "scrum master",
    "istqb",
    "oracle certified",
    "google cloud certified",
}

CV_HEADERS = {
    "education",
    "experience",
    "work experience",
    "employment",
    "projects",
    "skills",
    "technical skills",
    "certifications",
    "awards",
    "achievements",
    "publications",
    "research",
    "languages",
    "interests",
    "summary",
    "profile",
    "objective",
    "references",
}

WHITELIST_TERMS = (
    ORG_KEYWORDS
    | COMPANY_SUFFIXES
    | TECH_SKILLS
    | CERTIFICATIONS
    | CV_HEADERS
)

DATE_RANGE_PATTERN = re.compile(
        r'^\d{1,2}/\d{2,4}\s*[-–]\s*\d{1,2}/\d{2,4}$'
    )

DATE_RANGE_PATTERNS = [
    r'^\d{4}\s*[-–]\s*\d{4}$',                  # 2019-2021
    r'^\d{1,2}/\d{2,4}\s*[-–]\s*\d{1,2}/\d{2,4}$',  # 05/22 - 01/23
    r'^[A-Za-z]{3,9}\s+\d{4}\s*[-–]\s*(?:[A-Za-z]{3,9}\s+\d{4}|Present)$'
]


def remove_pii_fields(cv_data: dict, pii_keys: Optional[set] = None) -> dict:
    if pii_keys is None:
        pii_keys = {
            "name",
            "email",
            "phone",
            "address",
            "location",
            "linkedin",
            "github",
            "website",
            "link"
        }

    sanitized_data = {}

    for key, value in cv_data.items():
        normalized_key = key.lower()

        if normalized_key in pii_keys:
            sanitized_data[f"{normalized_key}_exist"] = True
            continue

        sanitized_data[key] = value

    return sanitized_data

# =========================================================
# Top Region Helper (first N lines)
# =========================================================
def get_top_region_end(text, max_lines=8):
    lines = text.split("\n")[:max_lines]
    return len("\n".join(lines))


def _get_detection_value(detection, key, default=None):
    if isinstance(detection, dict):
        return detection.get(key, default)
    return getattr(detection, key, default)


# =========================================================
# Filter Entities (your improved logic)
# =========================================================

def is_whitelisted(entity_type, value):
    value_lower = value.lower().strip()

    # Exact match against any whitelist term — applies to all entity types
    if value_lower in WHITELIST_TERMS:
        return True

    # For PERSON and LOCATION: reject if org keyword is found anywhere in the value
    if entity_type in {"PERSON", "LOCATION"}:
        if any(keyword in value_lower for keyword in ORG_KEYWORDS):
            return True

    # Company suffix check: only meaningful for multi-word strings
    # (avoids false positives on short names like "Hugo" matching "go")
    if entity_type in {"PERSON", "LOCATION", "ORG"}:
        words = value_lower.split()
        if len(words) > 1 and any(w in COMPANY_SUFFIXES for w in words):
            return True

    return False

def looks_like_date_range(value):
    return any(
        re.fullmatch(pattern, value.strip())
        for pattern in DATE_RANGE_PATTERNS
    )

# A single "word" that looks like a name token
_NAME_TOKEN_RE = re.compile(
    r"^[A-Za-z][a-z]+(?:[-'][A-Z]?[a-z]+)*$"   # optional hyphen/apostrophe
    r"|^[A-Z]{1,3}\.?$"                       # Initials: "J." or "JR"
)

def looks_like_person_name(value: str) -> bool:
    value = value.strip()
    if not value:
        return False

    words = value.split()

    # Honorifics and suffixes to strip before core validation
    _HONORIFICS = {"mr", "mrs", "ms", "miss", "dr", "prof", "sr", "jr", "rev", "hon"}
    _SUFFIXES    = {"jr", "sr", "ii", "iii", "iv", "v", "esq", "phd", "md", "dds", "rn"}

    # Expanded forbidden words — org/place/role signals
    _FORBIDDEN_NAME_WORDS = {
        # Org types
        "agency", "agencies", "company", "companies", "corp", "corporation",
        "inc", "llc", "ltd", "group", "firm", "partners", "associates",
        # Roles
        "marketing", "software", "engineer", "manager", "developer",
        "consultant", "director", "analyst", "designer", "intern",
        "lead", "head", "chief", "officer", "executive",
        # Places
        "street", "road", "avenue", "blvd", "lane", "drive",
        "university", "college", "institute", "school", "academy",
        "midtown", "downtown", "remote",
        # Resume section headers that leak through
        "summary", "experience", "education", "skills", "objective",
        "references", "profile", "contact",
        "mailto"
    }


    # Strip leading honorific and trailing suffix for core check
    core = words[:]
    if core and core[0].rstrip(".").lower() in _HONORIFICS:
        core = core[1:]
    if core and core[-1].rstrip(".").lower() in _SUFFIXES:
        core = core[:-1]

    # After stripping, core name should be 1–4 words
    if not (1 <= len(core) <= 4):
        return False

    # Reject if any word is a known non-name term
    if any(w.lower().rstrip(".") in _FORBIDDEN_NAME_WORDS for w in core):
        return False

    # Every core word must match a valid name-token pattern
    if not all(_NAME_TOKEN_RE.match(w) for w in core):
        return False
    return True

def filter_entities(results, text, max_top_region=350):
    included = {"PERSON","EMAIL_ADDRESS","PHONE_NUMBER","URL","LOCATION","LINKEDIN_URL","GITHUB_URL","MEDIUM_URL","DEVPOST_URL"}
    thresholds = {
        "URL": 0.6,
        "LINKEDIN_URL": 0.6,
        "GITHUB_URL": 0.6,
        "MEDIUM_URL": 0.6,
        "DEVPOST_URL": 0.6
    }

    top_end = min(get_top_region_end(text), max_top_region)
    filtered = []

    for r in results:
        entity_type = _get_detection_value(r, "entity_type")
        start = _get_detection_value(r, "start", 0)
        end = _get_detection_value(r, "end", 0)
        score = _get_detection_value(r, "score", 0)

        value = text[start:end].strip()

        # Exclude if whitelisted
        if is_whitelisted(entity_type, value):
            continue

        if entity_type not in included:
            continue

        # PERSON or PHONE → only if in top
        if entity_type == "PHONE_NUMBER":
            digits = re.sub(r"\D", "", value)
            if looks_like_date_range(value) or not (7 <= len(digits) <= 15):
                continue

        if entity_type == "PERSON":
            if not looks_like_person_name(value):
                continue

        if entity_type == "PERSON" or entity_type == "PHONE_NUMBER":
            if start < top_end:
                filtered.append(r)
            continue

        # EMAIL → always keep (important for CVs)
        if entity_type == "EMAIL_ADDRESS":
            filtered.append(r)
            continue

        if entity_type == "LOCATION":
            if "\n" in value :
                continue
            # reject skill keywords using word boundaries to avoid matching single-letter skills
            # (e.g., "r" in TECH_SKILLS shouldn't filter "Alexandria")
            value_words = set(value.lower().split())
            if any(skill in value_words for skill in TECH_SKILLS):
                continue
            # reject very long spans (but allow full addresses up to 12+ words)
            if len(value.split()) > 15:
                continue

        # Others → use score
        min_score = thresholds.get(entity_type, 0)
        if score >= min_score:
            filtered.append(r)

    return filtered


# =========================================================
# Remove Overlaps (keep best span)
# =========================================================
def remove_overlaps(results):
    results = sorted(
        results,
        key=lambda x: (
            _get_detection_value(x, "start", 0),
            -_get_detection_value(x, "score", 0),
        ),
    )
    filtered = []

    for r in results:
        start = _get_detection_value(r, "start", 0)
        end = _get_detection_value(r, "end", 0)

        if not any(
            start < _get_detection_value(f, "end", 0)
            and end > _get_detection_value(f, "start", 0)
            for f in filtered
        ):
            filtered.append(r)

    return filtered


def _trim_url_span(text, start, end):
    """Trim trailing punctuation that should stay outside a URL token."""
    while end > start and text[end - 1] in ")]},.;:!?":
        end -= 1
    return start, end


# =========================================================
# Categorize URLs
# =========================================================
def categorize_url(url_text):
    """Categorize URL into specific types (LinkedIn, GitHub, Medium, DevPost) or generic URL"""
    url_lower = url_text.lower()

    if "linkedin" in url_lower:
        return "LINKEDIN_URL"
    elif "github" in url_lower:
        return "GITHUB_URL"
    elif "medium" in url_lower:
        return "MEDIUM_URL"
    elif "devpost" in url_lower:
        return "DEVPOST_URL"
    else:
        return "URL"

# =========================================================
# Mask + Mapping (CORE PART)
# =========================================================
def mask_with_mapping(text, results):
    results = sorted(results, key=lambda x: _get_detection_value(x, "start", 0))
    value_to_token = {}  # Track already-seen values

    masked_text = text
    offset = 0
    mask_map = {}
    counters = {}

    for r in results:
        label = _get_detection_value(r, "entity_type")
        start = _get_detection_value(r, "start", 0)
        end = _get_detection_value(r, "end", 0)
        confidence = _get_detection_value(r, "score", 0)
        original_value = text[start:end]

        if label == "URL":
            start, end = _trim_url_span(text, start, end)

        # Reuse token if same value already masked
        normalized = original_value.lower().strip()
        if normalized in value_to_token:
            token = value_to_token[normalized]
        else:
            counters[label] = counters.get(label, 0)
            token = f"<{label}_{counters[label]}>"
            counters[label] += 1
            value_to_token[normalized] = token


        masked_start = start + offset
        masked_end = end + offset

        # Replace safely
        masked_text = masked_text[:masked_start] + token + masked_text[masked_end:]

        # Update offset
        offset += len(token) - (end - start)

        # Store mapping
        mask_map[token] = {
            "value": original_value,
            "type": label,
            "start": start,
            "end": end,
            "confidence": confidence,
        }

    return masked_text, mask_map


# =========================================================
# Unmask
# =========================================================
def unmask_text(text, mask_map):
    for token, data in mask_map.items():
        original_value = data["value"]
        base_token = token.strip("<>")
        flexible_pattern = rf"<\s*{re.escape(base_token)}\s*>"

        # 1. Try exact string replacements first (all occurrences)
        for var in [token, f"< {base_token} >"]:
            if var in text:
                text = text.replace(var, original_value)

        # 2. Case-insensitive regex for LLM-mangled tokens (all occurrences)
        try:
            if re.search(flexible_pattern, text, flags=re.IGNORECASE):
                text = re.sub(
                    flexible_pattern,
                    lambda m: original_value,   # lambda avoids backreference issues
                    text,
                    flags=re.IGNORECASE
                )
        except re.error as e:
            import logging
            logging.warning("unmask_text regex error for token %s: %s", token, e)

    return text


# =========================================================
# Pattern-Based Masking (Fallback)
# =========================================================
PATTERN_CONFIGS = {
    "EMAIL_ADDRESS": {
        "pattern": r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
        "priority": 1
    },
    "PHONE_NUMBER": {
        # Requires recognizable phone structure: optional country code,
        # then groups of digits separated by spaces/dashes/dots/parens.
        # Minimum 7 digits, maximum 15 (ITU-T E.164 limit).
        "pattern": r'(?<!\d)(\+?(?:[0-9]{1,3}[-.\s])?'      # optional country code
                  r'(?:\([0-9]{1,4}\)[-.\s]?)?'             # optional area code in parens
                  r'[0-9]{3,5}[-.\s]?[0-9]{3,5}'            # main number body
                  r'(?:[-.\s]?[0-9]{1,5})?)(?!\d)',          # optional extension
        "priority": 2
    },
    "PERSON": {
        # Look for lines starting with "Name:" or "Full Name:", followed by capitalized words (at least 2, max 5)
        "pattern": r'(?i)(?:name|full name)\s*[:\-]?\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,4})',
        "priority": 3
    },
    "URL": {
        "pattern": r'https?://[^\s]+',
        "priority": 4
    },
    "LOCATION": {
      "pattern": r'\d{1,5}\s[\w\s]{1,50}(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr)[\w\s,\.]*\d{5}(?:-\d{4})?',
      "priority": 5
    }
}

def pattern_based_detection(text):
    """Detect PII using regex patterns"""
    detected = []

    for entity_type, config in PATTERN_CONFIGS.items():
        pattern = config["pattern"]
        for match in re.finditer(pattern, text):
            # Create a RecognizerResult-like object for consistency
            start = match.start()
            end = match.end()
            if entity_type == "URL":
                start, end = _trim_url_span(text, match.start(), match.end())
            if entity_type == "PERSON":
                # For PERSON, only capture the name part (group 1)
                if match.lastindex and match.lastindex >= 1:
                    start = match.start(1)
                    # keep only first line if multiple lines are captured
                    name_value = match.group(1).split("\n")[0].strip()
                    end = start + len(name_value)
                else:
                    continue  # If no group 1 match, skip
            detected.append({
                "entity_type": entity_type,
                "start": start,
                "end": end,
                "score": 1.0,
                "source": "pattern"
            })

    return detected

def merge_detections(presidio_results, pattern_results):
    """Merge Presidio and pattern-based detections, avoiding duplicates"""
    all_results = presidio_results + pattern_results

    # Sort by position and score
    all_results = sorted(all_results, key=lambda x: (x["start"], -x["score"]))
    # Remove overlaps, keeping highest confidence
    merged = []
    for r in all_results:
        if not any(r["start"] < m["end"] and r["end"] > m["start"] for m in merged):
            merged.append(r)

    return merged

def normalize_span(r, text):
    start = _get_detection_value(r, "start", 0)
    end = _get_detection_value(r, "end", 0)
    entity_type = _get_detection_value(r, "entity_type", "")
    score = _get_detection_value(r, "score", 0)

    if entity_type == "PERSON":
        value = re.split(
            r'[\n|/\\]+',
            text[start:end],
            maxsplit=1
        )[0].strip()

        end = start + len(value)

    return {
        "entity_type": entity_type,
        "start": start,
        "end": end,
        "score": score,
        "source": "presidio"
    }

# =========================================================
# MAIN PIPELINE
# =========================================================
def pii_pipeline(cv_text):
    # Step 1: Detect with Presidio
    results = analyzer.analyze(text=cv_text, language="en")
    results = [
        normalize_span(r, cv_text)
        for r in results
    ]

        # Exclude if whitelisted

    # Step 1b: Fallback pattern-based detection
    pattern_results = pattern_based_detection(cv_text)
    results = merge_detections(results, pattern_results)

    # Step 1c: Categorize URLs
    for r in results:
        if r["entity_type"] == "URL":
            url_text = cv_text[r["start"]:r["end"]]
            r["entity_type"] = categorize_url(url_text)

    # Step 2: Filter
    results = filter_entities(results, cv_text)

    # Step 3: Remove overlaps
    results = remove_overlaps(results)

    # Step 4: Mask + Mapping
    masked_text, mask_map = mask_with_mapping(cv_text, results)

    return {
        "masked_text": masked_text,
        "mask_map": mask_map,
        "entities": results
    }