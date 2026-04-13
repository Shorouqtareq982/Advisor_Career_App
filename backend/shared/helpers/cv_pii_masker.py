import re
from presidio_analyzer import AnalyzerEngine, RecognizerResult
from presidio_anonymizer import AnonymizerEngine

# Initialize once
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()


# =========================================================
# Top Region Helper (first N lines)
# =========================================================
def get_top_region_end(text, max_lines=5):
    lines = text.split("\n")[:max_lines]
    return len("\n".join(lines))


# =========================================================
# Filter Entities (your improved logic)
# =========================================================
def filter_entities(results, text, max_top_region=350):
    excluded = {"DATE_TIME"}
    thresholds = {"URL": 0.6}

    top_end = min(get_top_region_end(text), max_top_region)
    print(f"top_end = {top_end}")
    filtered = []

    for r in results:
        if r.entity_type in excluded:
            continue

        # PERSON or PHONE → only if in top
        if r.entity_type == "PERSON" or r.entity_type == "PHONE_NUMBER":
            if r.start < top_end:
                filtered.append(r)
            continue

        # EMAIL → always keep (important for CVs)
        if r.entity_type == "EMAIL_ADDRESS":
            filtered.append(r)
            continue

        # Others → use score
        min_score = thresholds.get(r.entity_type, 0)
        if r.score >= min_score:
            filtered.append(r)

    return filtered


# =========================================================
# Remove Overlaps (keep best span)
# =========================================================
def remove_overlaps(results):
    results = sorted(results, key=lambda x: (x.start, -x.score))
    filtered = []

    for r in results:
        if not any(r.start < f.end and r.end > f.start for f in filtered):
            filtered.append(r)

    return filtered


# =========================================================
# Mask + Mapping (CORE PART)
# =========================================================
def mask_with_mapping(text, results):
    results = sorted(results, key=lambda x: x.start)

    masked_text = text
    offset = 0
    mask_map = {}
    counters = {}

    for r in results:
        label = r.entity_type

        counters[label] = counters.get(label, 0)
        token = f"<{label}_{counters[label]}>"
        counters[label] += 1

        original_value = text[r.start:r.end]

        start = r.start + offset
        end = r.end + offset

        # Replace safely
        masked_text = masked_text[:start] + token + masked_text[end:]

        # Update offset
        offset += len(token) - (r.end - r.start)

        # Store mapping
        mask_map[token] = {
            "value": original_value,
            "type": label,
            "start": r.start,
            "end": r.end
        }

    return masked_text, mask_map


# =========================================================
# Unmask
# =========================================================
def unmask_text(text, mask_map):
    for token, data in mask_map.items():
        text = text.replace(token, data["value"])
    return text


# =========================================================
# MAIN PIPELINE
# =========================================================
def pii_pipeline(cv_text):
    # Step 1: Detect
    results = analyzer.analyze(text=cv_text, language="en")

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