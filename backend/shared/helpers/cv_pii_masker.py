import re
from typing import Optional
from presidio_analyzer import AnalyzerEngine, RecognizerResult
from presidio_anonymizer import AnonymizerEngine

# Initialize once
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()


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
def get_top_region_end(text, max_lines=5):
    lines = text.split("\n")[:max_lines]
    return len("\n".join(lines))


def _get_detection_value(detection, key, default=None):
    if isinstance(detection, dict):
        return detection.get(key, default)
    return getattr(detection, key, default)


# =========================================================
# Filter Entities (your improved logic)
# =========================================================
def filter_entities(results, text, max_top_region=350):
    excluded = {"DATE_TIME","NRP"}
    thresholds = {"URL": 0.6}

    top_end = min(get_top_region_end(text), max_top_region)
    filtered = []

    for r in results:
        entity_type = _get_detection_value(r, "entity_type")
        start = _get_detection_value(r, "start", 0)
        score = _get_detection_value(r, "score", 0)

        if entity_type in excluded:
            continue

        # PERSON or PHONE → only if in top
        if entity_type == "PERSON" or entity_type == "PHONE_NUMBER":
            if start < top_end:
                filtered.append(r)
            continue

        # EMAIL → always keep (important for CVs)
        if entity_type == "EMAIL_ADDRESS":
            filtered.append(r)
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
# Mask + Mapping (CORE PART)
# =========================================================
def mask_with_mapping(text, results):
    results = sorted(results, key=lambda x: _get_detection_value(x, "start", 0))

    masked_text = text
    offset = 0
    mask_map = {}
    counters = {}

    for r in results:
        label = _get_detection_value(r, "entity_type")
        start = _get_detection_value(r, "start", 0)
        end = _get_detection_value(r, "end", 0)

        if label == "URL":
            start, end = _trim_url_span(text, start, end)

        counters[label] = counters.get(label, 0)
        token = f"<{label}_{counters[label]}>"
        counters[label] += 1

        original_value = text[start:end]

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
            "end": end
        }

    return masked_text, mask_map


# =========================================================
# Unmask
# =========================================================
def unmask_text(text, mask_map):
    """Unmask text with resilience to token formatting variations."""
    for token, data in mask_map.items():
        original_value = data["value"]
        
        # Extract the base token (without angle brackets)
        # e.g., "<PERSON_0>" -> "PERSON_0"
        base_token = token.strip("<>")
        
        # Try multiple variations the LLM might produce
        variations = [
            token,                           # <PERSON_0>
            base_token,                      # PERSON_0
            base_token.lower(),              # person_0
            base_token.upper(),              # PERSON_0 (already uppercase, but for symmetry)
            f"< {base_token} >",             # < PERSON_0 >
            f"{base_token}",                 # Already covered above
        ]
        
        # Also handle with optional spaces
        variations.extend([
            re.sub(r'([<>])', r'\\s*\1\\s*', token),  # Flexible bracket spacing
        ])
        
        for var in variations:
            if isinstance(var, str) and var in text:
                text = text.replace(var, original_value)
                break
            elif isinstance(var, str):
                # Try as regex if it's a variation with flexible spacing
                try:
                    text = re.sub(var, original_value, text, flags=re.IGNORECASE)
                except:
                    pass
    
    return text


# =========================================================
# Pattern-Based Masking (Fallback)
# =========================================================
PATTERN_CONFIGS = {
    "EMAIL_ADDRESS": {
        "pattern": r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        "priority": 1
    },
    "PHONE_NUMBER": {
        "pattern": r'(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b',
        "priority": 2
    },
    "URL": {
        "pattern": r'https?://[^\s]+',
        "priority": 3
    },
    "SSN": {
        "pattern": r'\b\d{3}-\d{2}-\d{4}\b',
        "priority": 4
    },
    "CREDIT_CARD": {
        "pattern": r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b',
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
            detected.append({
                "entity_type": entity_type,
                "start": match.start(),
                "end": match.end(),
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


# =========================================================
# MAIN PIPELINE
# =========================================================
def pii_pipeline(cv_text):
    # Step 1: Detect with Presidio
    results = analyzer.analyze(text=cv_text, language="en")
    results = [
        {
            "entity_type": r.entity_type,
            "start": r.start,
            "end": r.end,
            "score": r.score,
            "source": "presidio"
        }
        for r in results
    ]
    
    # Step 1b: Fallback pattern-based detection
    pattern_results = pattern_based_detection(cv_text)
    results = merge_detections(results, pattern_results)

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