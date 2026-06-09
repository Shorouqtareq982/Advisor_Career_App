"""
CV Content Quality Checker
Analyzes CV text across 4 content quality dimensions.
"""

import re

from shared.helpers.cv_pii_masker import pii_pipeline

from ..helpers.spelling_checker import get_typos_with_suggestions

# ══════════════════════════════════════════════════════════════════════════════
#  CONSTANTS
# ══════════════════════════════════════════════════════════════════════════════

STANDARD_HEADINGS = [
    "summary", "professional summary", "executive summary", "career summary",
    "objective", "career objective", "professional objective",
    "profile", "about me", "overview",
    "education", "academic background", "academic qualifications", "qualifications",
    "degrees", "degree", "university", "college", "schooling",
    "experience", "work experience", "professional experience", "employment experience",
    "work history", "employment history", "career history",
    "positions held", "employment", "professional background", "experience summary",
    "internships", "internship experience", "internships experience",
    "skills", "technical skills", "soft skills", "core skills", "key skills",
    "professional skills", "competency", "competencies",
    "expertise", "proficiencies", "capabilities",
    "projects", "personal projects", "key projects",
    "notable projects", "portfolio",
    "certifications", "certificates", "certification",
    "licenses and certifications", "credentials",
    "accreditations", "professional development",
    "awards", "achievements", "honors", "recognitions",
    "accomplishments", "distinctions",
    "publications", "papers", "research", "journals",
    "articles", "conference papers",
    "languages", "language proficiency", "linguistic skills",
    "volunteer", "volunteering", "volunteer experience",
    "community service", "community involvement",
    "civic activities", "social activities",
    "interests", "hobbies", "personal interests", "extracurricular",
    "hobbies and interests",
    "references", "referees",
    "contact", "contact information", "contact details",
    "personal information", "personal details",
]


# Logical order tiers (earlier tier should appear before later)
HEADING_TIERS = {
    "summary": 1, "professional summary": 1, "executive summary": 1, "career summary": 1,
    "objective": 1, "career objective": 1, "professional objective": 1,
    "profile": 1, "about me": 1, "overview": 1,
    "education": 3, "academic background": 3, "academic qualifications": 3, "qualifications": 3,
    "degrees": 3, "degree": 3, "university": 3, "college": 3, "schooling": 3,
    "experience": 2, "work experience": 2, "professional experience": 2, "employment experience": 2,
    "work history": 2, "employment history": 2, "career history": 2,
    "positions held": 2, "employment": 2, "professional background": 2, "experience summary": 2,
    "internships": 2, "internship experience": 2, "internships experience": 2,
    "skills": 4, "technical skills": 4, "soft skills": 4, "core skills": 4, "key skills": 4,
    "professional skills": 4, "competency": 4, "competencies": 4,
    "expertise": 4, "proficiencies": 4, "capabilities": 4,
    "projects": 5, "personal projects": 5, "key projects": 5,
    "notable projects": 5, "portfolio": 5,
    "certifications": 6, "certificates": 6, "certification": 6,
    "licenses and certifications": 6, "credentials": 6,
    "accreditations": 6, "professional development": 6,
    "awards": 7, "achievements": 7, "honors": 7, "recognitions": 7,
    "accomplishments": 7, "distinctions": 7,
    "publications": 8, "papers": 8, "research": 8, "journals": 8,
    "articles": 8, "conference papers": 8,
    "languages": 10, "language proficiency": 10, "linguistic skills": 10,
    "volunteer": 9, "volunteering": 9, "volunteer experience": 9,
    "community service": 9, "community involvement": 9,
    "civic activities": 9, "social activities": 9,
    "interests": 11, "hobbies": 11, "personal interests": 11, "extracurricular": 11,
    "hobbies and interests": 11,
    "references": 12, "referees": 12,
    "contact": 13, "contact information": 13, "contact details": 13,
    "personal information": 13, "personal details": 13,
}

STRONG_ACTION_VERBS = {
    # Leadership
    "led", "managed", "directed", "oversaw", "supervised", "mentored", "coached",
    "guided", "spearheaded", "chaired", "headed", "coordinated",
    # Achievement
    "achieved", "exceeded", "surpassed", "delivered", "accomplished", "attained",
    "secured", "won", "earned",
    # Creation
    "developed", "built", "created", "designed", "established", "launched",
    "implemented", "deployed", "engineered", "architected", "founded", "initiated",
    # Improvement
    "improved", "optimized", "streamlined", "enhanced", "increased", "reduced",
    "decreased", "accelerated", "boosted", "transformed", "revamped", "upgraded",
    "restructured", "automated",
    # Analysis
    "analyzed", "assessed", "evaluated", "researched", "identified", "diagnosed",
    "audited", "investigated",
    # Communication
    "presented", "negotiated", "collaborated", "partnered", "facilitated",
    "communicated", "advocated", "influenced", "persuaded",
    # Operations
    "executed", "administered", "operated", "maintained", "supported", "ensured",
    "trained", "onboarded", "recruited", "hired",
    # Finance/Sales
    "generated", "grew", "scaled", "drove", "expanded", "acquired", "retained",
    "forecasted", "budgeted", "negotiated", "closed",
}

PERSONAL_PRONOUNS = {"i", "me", "my", "myself", "mine", "we", "our", "ours", "ourselves"}

VAGUE_PHRASES = [
    r"\bhard[\s-]?working\b",
    r"\bteam[\s-]?player\b",
    r"\bself[\s-]?starter\b",
    r"\bdetail[\s-]?oriented\b",
    r"\bfast[\s-]?learner\b",
    r"\bpassionate about\b",
    r"\bexcellent communication skills?\b",
    r"\bstrong work ethic\b",
    r"\bresults[\s-]?driven\b",
    r"\bproactive\b",
    r"\bgo[\s-]?getter\b",
    r"\bthink outside the box\b",
    r"\bsynergy\b",
    r"\bstrategic thinker\b",
    r"\bproblem[\s-]?solver\b",
    r"\bmultitasker\b",
    r"\bresponsible for\b",
    r"\bhelped (with|to)\b",
    r"\bworked on\b",
    r"\binvolved in\b",
    r"\bfamiliar with\b",
    r"\bhighly skilled\b",
    r"\bknowledge of\b",
    r"\bexposure to\b",
    r"\bbasic understanding\b",
    r"\bgood (at|with|in)\b",
    r"\betc\\.?\b",
    r"\bvarious tasks\b",
    r"\bday[\s-]?to[\s-]?day\b",
]

# Quantifiable metric patterns
MONEY_PATTERN = re.compile(
    r"(\$|€|£|¥|USD|EUR|GBP)"  # currency symbols
    r"|(\d[\d,]*(\.\d+)?\s*(million|billion|thousand|k|m|b)\b)"  # 1.2M, 500K
    r"|(revenue|sales|cost|budget|profit|saving|spend|expenditure)",
    re.IGNORECASE,
)

MONEY_PERCENT_PATTERN = re.compile(
    r"\d+(\.\d+)?\s*%.*?(revenue|sales|cost|profit|saving|roi|margin|budget)"
    r"|(revenue|sales|cost|profit|saving|roi|margin|budget).*?\d+(\.\d+)?\s*%",
    re.IGNORECASE,
)

PERCENT_PATTERN = re.compile(r"\d+(\.\d+)?\s*%")

NUMBER_PATTERN = re.compile(
    r"\b\d[\d,]*(?:\.\d+)?(?:\+)?(?:-\d[\d,]*(?:\.\d+)?)?(?=\s|$)"
) # any standalone number with optional '+'

PEOPLE_KEYWORDS = re.compile(
    r"\b(\d+[\+]?[\s-]*?(people|person|employee|staff|customer|client|user|member|report|hire|recruit|team)s?)\b"
    r"|\b(team of \d+)\b"
    r"|\b(\d+[\+]?[\s-]*?(direct report|stakeholder)s?)\b",
    re.IGNORECASE,
)

TASK_KEYWORDS = re.compile(
    r"\b(\d+[\+]?\s*(hour|day|week|month|year|minute)s?\s*(saved|reduced|cut|faster|quicker))\b"
    r"|\b((\d+)x\s*(faster|improvement|increase|reduction|growth))\b"
    r"|\b(from \d+ to \d+)\b"
    r"|\b(\d+[\+]?\s*(request|ticket|deployment|release|transaction|order|project|application)s?)\b",
    re.IGNORECASE,
)

AWARD_KEYWORDS = re.compile(
    r"\b(award|recognition|prize|honor|honour|publication|paper|patent|certificate|rank(ed)?|top \d+%?)\b",
    re.IGNORECASE,
)


# ══════════════════════════════════════════════════════════════════════════════
#  HELPER: extract bullet-point / experience sentences
# ══════════════════════════════════════════════════════════════════════════════

def extract_experience_sentences(cv_parsed_content: dict, add_summary: bool = False) -> list[str]:
    """Return sentences likely describing job duties / accomplishments."""
    all_descriptions = []

    # Extract project descriptions
    for project in cv_parsed_content.get('projects', []):
        if 'description' in project and isinstance(project['description'], list):
            all_descriptions.extend(project['description'])

    # Extract work experience descriptions
    for experience in cv_parsed_content.get('work_experience', []):
        if 'description' in experience and isinstance(experience['description'], list):
            all_descriptions.extend(experience['description'])

    # Extract summary if requested
    if add_summary:
        summary = cv_parsed_content.get('summary')
        if isinstance(summary, str):
            all_descriptions.append(summary)

    # Print the combined list of descriptions
    return all_descriptions



# ══════════════════════════════════════════════════════════════════════════════
#  CHECK 1 – Headings in logical order and clearly defined
# ══════════════════════════════════════════════════════════════════════════════

def check_headings(headings_from_parsed_content: list[str]) -> dict:
    """
    Detect headings (ALL CAPS lines, Title Case short lines, or lines ending with ':')
    and verify they appear in a sensible logical order.
    """
    standardized_headings = []
    for h in headings_from_parsed_content:
        lower_h = h.lower()
        if "work experience" in lower_h or "employment" in lower_h:
            standardized_headings.append("work experience")
        elif "skills" in lower_h or "competencies" in lower_h:
            standardized_headings.append("skills")
        elif "education" in lower_h:
            standardized_headings.append("education")
        elif "projects" in lower_h:
            standardized_headings.append("projects")
        elif "summary" in lower_h or "profile" in lower_h or "about" in lower_h:
            standardized_headings.append("summary")
        elif "certifications" in lower_h:
            standardized_headings.append("certifications")
        elif "achievements" in lower_h or "awards" in lower_h or "honors" in lower_h:
            standardized_headings.append("achievements")
        elif "languages" in lower_h:
            standardized_headings.append("languages")
        elif lower_h in HEADING_TIERS: # Direct match for other standard headings
            standardized_headings.append(lower_h)
        else:
            # If no match, we can skip it or assign a default tier/handle as an unknown
            pass # For now, skip

    # Filter out any non-matched headings before checking tiers
    standardized_headings = [h for h in standardized_headings if h in HEADING_TIERS]

    if not standardized_headings:
        return {
            "pass": False,
            "details": "We could not identify clear standard section headings. Use headings like Summary, Work Experience, Education, and Skills.",
            "headings": [],
        }

    # Check logical order: tiers should be non-decreasing
    tiers = [HEADING_TIERS[h] for h in standardized_headings]
    out_of_order = []
    for i in range(1, len(tiers)):
        if tiers[i] < tiers[i - 1]:
            out_of_order.append(
                f"'{standardized_headings[i]}' appears after '{standardized_headings[i-1]}'"
            )

    passed = len(standardized_headings) >= 2 and not out_of_order
    details = (
        f"Detected {len(standardized_headings)} section headings: {', '.join(standardized_headings)}."
    )
    if out_of_order:
        details += f" Some sections are out of order: {'; '.join(out_of_order)}."

    return {"pass": passed, "details": details, "headings": standardized_headings}


# ══════════════════════════════════════════════════════════════════════════════
#  CHECK 2 – Action verbs used, no personal pronouns
# ══════════════════════════════════════════════════════════════════════════════

def check_action_verbs_and_pronouns(cv_text: str) -> dict:
    words = re.findall(r"\b[a-z']+\b", cv_text.lower())

    found_pronouns = [w for w in words if w in PERSONAL_PRONOUNS]
    found_verbs = [w for w in words if w in STRONG_ACTION_VERBS]

    pronoun_ok = len(found_pronouns) == 0
    verb_ok = len(found_verbs) >= 5  # at least 5 distinct action verb usages

    passed = pronoun_ok and verb_ok

    details_parts = []
    success_parts = []
    if verb_ok:
        unique_verbs = sorted(set(found_verbs))
        success_parts.append(
            f"Found {len(found_verbs)} action-verb usage(s) "
            f"({', '.join(unique_verbs[:8])}{'...' if len(unique_verbs) > 8 else ''})."
        )
    else:
        details_parts.append(
            f"Only {len(found_verbs)} strong action verb(s) found. Aim for at least 5 to make achievements clearer."
        )

    if pronoun_ok:
        success_parts.append("No personal pronouns detected.")
    else:
        uniq = sorted(set(found_pronouns))
        details_parts.append(
            f"Personal pronouns found: {', '.join(uniq)} "
            f"({len(found_pronouns)} occurrence(s)). Consider rewriting bullets without first-person pronouns."
        )

    return {
        "pass": passed,
        "details": " ".join(details_parts),
        "success_message": " ".join(success_parts),
        "action_verbs_count": len(found_verbs),
        "pronouns_found": sorted(set(found_pronouns)),
    }


# ══════════════════════════════════════════════════════════════════════════════
#  CHECK 3 – Clear and specific wording (no vague/generic phrases)
# ══════════════════════════════════════════════════════════════════════════════

def check_clarity(cv_text: str) -> dict:
    lower = cv_text.lower()
    found_vague = []

    for pattern in VAGUE_PHRASES:
        matches = re.findall(pattern, lower)
        if matches:
            # Get the readable pattern for reporting
            readable = re.sub(r"\\b|\\s\?|\[\\s\-\]\?|\(\?:.*?\)|[()\\]", "", pattern).strip()
            found_vague.append((readable, len(matches)))

    passed = len(found_vague) == 0

    if passed:
        details = "No vague or generic phrases detected."
    else:
        items = [f"'{p}' ×{c}" for p, c in found_vague[:10]]
        details = (
            f"Found {len(found_vague)} vague phrase type(s): {', '.join(items)}."
            " Replace these with specific, measurable statements."
        )

    return {"pass": passed, "details": details, "vague_phrases": found_vague}


# ══════════════════════════════════════════════════════════════════════════════
#  CHECK 4 – Quantifiable impact: ≥ 5 measurable results
# ══════════════════════════════════════════════════════════════════════════════

def check_quantifiable_impact(cv_parsed_content: dict) -> dict:
    sentences = extract_experience_sentences(cv_parsed_content)
    results = []  # list of (sentence, category, matched_text)
    seen_keys = set()

    PATTERNS = [
        # (compiled_regex, category, unique_label)
        (MONEY_PERCENT_PATTERN, 'Money/Finance', 'money_percent'),
        (AWARD_KEYWORDS,'Other','award'),
        (TASK_KEYWORDS, 'Tasks/Operations','task'),
        (PEOPLE_KEYWORDS,'People','people'),
        (MONEY_PATTERN,'Money/Finance','money'),
        (PERCENT_PATTERN,'Tasks/Operations','percent'),
        (NUMBER_PATTERN,'Tasks/Operations','number'),
    ]

    for sent in sentences:
        for rx, category, label in PATTERNS:
            match = rx.search(sent)
            if match:
                key = f"{sent[:60].lower()}::{label}"
                if key not in seen_keys:
                    seen_keys.add(key)
                    matched_text = match.group(0).strip()
                    results.append((sent[:120], category, matched_text))

    count = len(results)
    passed = count >= 5

    details_parts = [
        f"Found {count} measurable result(s). Minimum target is 5."
    ]

    if results:
        by_cat: dict = {}
        for _, cat, _ in results:
            by_cat[cat] = by_cat.get(cat, 0) + 1
        cat_summary = ", ".join(f"{cat}: {n}" for cat, n in sorted(by_cat.items()))
        details_parts.append(f"Category breakdown: {cat_summary}.")

    if not passed:
        details_parts.append(
            "Add more metrics such as percentages, dollar impact, team size, delivery volume, or time saved."
        )

    return {
        "pass": passed,
        "details": " ".join(details_parts),
        "count": count,
        "results": results,  # now (sentence, category, matched_text)
    }


# ══════════════════════════════════════════════════════════════════════════════
#  CHECK 5 – Spelling and grammar quality
# ══════════════════════════════════════════════════════════════════════════════
def check_spelling_and_grammar(cv_text: str, extra_skills: set = None, user_info: dict = None) -> dict:
    typos = get_typos_with_suggestions(cv_text, user_info, extra_skills)
    VALID_CATEGORIES = {"TYPOS"}
    typos = [t for t in typos if t.get('category') in VALID_CATEGORIES]
    passed = len(typos) <= 2  # Allow up to 2 minor issues without failing

    details_parts = []
    if len(typos) == 0:
        details_parts.append("No spelling or grammar issues detected.")
    else:
        details_parts.append(
            f"Found {len(typos)} potential spelling/grammar issue(s)."
        )
        for t in typos[:5]:  # Show up to 5 issues
            error = t['error']
            suggestions = ", ".join(t['suggestions'][:3]) if t['suggestions'] else "no suggestions"
            details_parts.append(f"- '{error}' Suggested fixes: {suggestions}")

    return {
        "pass": passed,
        "details": ". ".join(details_parts),
        "typos": typos,
    }

# ══════════════════════════════════════════════════════════════════════════════
#  MAIN ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════

def check_cv_content_quality(cv_text: str, cv_parsed_content: dict) -> dict:
    """
    Run all 5 content-quality checks on the provided CV text.

    Returns a dict with keys:
        overall_pass  – bool
        score         – "X / 5"
        checks        – list of individual check results
    """
    masked_text = pii_pipeline(cv_text)['masked_text'] if cv_text else ""
    user_info = {
        "name": cv_parsed_content.get("name"),
        "email": cv_parsed_content.get("email"),
        "phone": cv_parsed_content.get("phone"),
    }
    checks = [
        {
            "id": 1,
            "name": "Headings in logical order and clearly defined",
            **check_headings(cv_parsed_content['all_sections_in_order']),
        },
        {
            "id": 2,
            "name": "Action verbs used, no personal pronouns",
            **check_action_verbs_and_pronouns(cv_text),
        },
        {
            "id": 3,
            "name": "Clear and specific wording (no vague/generic phrases)",
            **check_clarity(cv_text),
        },
        {
            "id": 4,
            "name": "Quantifiable impact: ≥ 5 measurable results",
            **check_quantifiable_impact(cv_parsed_content),
        },
        {
            "id": 5,
            "name": "Spelling and grammar quality",
            **check_spelling_and_grammar(masked_text, extra_skills=set(cv_parsed_content.get("skills", [])), user_info=user_info),
        },

    ]

    passed_count = sum(1 for c in checks if c["pass"])

    return {
        "overall_pass": passed_count == 5,
        "score": f"{passed_count} / 5",
        "checks": checks,
    }


# ══════════════════════════════════════════════════════════════════════════════
#  CLI / pretty print
# ══════════════════════════════════════════════════════════════════════════════

def print_report(result: dict) -> None:
    sep = "═" * 60
    print(f"\n{sep}")
    print("  CV CONTENT QUALITY REPORT")
    print(sep)
    print(f"  Overall Score : {result['score']}")
    print(f"  Overall Result: {'✅ PASS' if result['overall_pass'] else '❌ FAIL'}")
    print(sep)

    for check in result["checks"]:
        status = "✅ PASS" if check["pass"] else "❌ FAIL"
        print(f"\n  Check {check['id']}: {check['name']}")
        print(f"  Result : {status}")
        print(f"  Details: {check['details']}")

        # Extra detail for check 4
        if check["id"] == 4 and check.get("results"):
            print("\n  Detected measurable results:")
            for i, (sent, cat, match) in enumerate(check["results"][:10], 1):
                print(f"    {i:2}. [{cat}] matched: '{match}' → {sent[:90]}{'...' if len(sent) > 90 else ''}")

    print(f"\n{sep}\n")