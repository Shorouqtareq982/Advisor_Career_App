"""
CV Content Quality Checker
Analyzes CV text across 4 content quality dimensions.
"""

import re

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
    "education": 2, "academic background": 2, "academic qualifications": 2, "qualifications": 2,
    "degrees": 2, "degree": 2, "university": 2, "college": 2, "schooling": 2,
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
    "led", "managed", "directed", "oversaw", "supervised", "mentored","coached", "guided", "spearheaded", "chaired", "headed",
    "coordinated", "orchestrated", "delegated", "empowered", "inspired",
    # Achievement
    "achieved", "exceeded", "surpassed", "delivered", "accomplished","attained", "secured", "won", "earned", "outperformed",
    "triumphed", "realized", "reached", "completed","successfully executed",
    # Creation
    "developed", "built", "created", "designed", "established","launched", "implemented", "deployed", "engineered",
    "architected", "founded", "initiated", "pioneered","invented", "formulated", "composed", "produced", "crafted",
    # Improvement
    "improved", "optimized", "streamlined", "enhanced", "increased","reduced", "decreased", "accelerated", "boosted",
    "transformed", "revamped", "upgraded", "restructured","automated", "refined", "modernized", "scaled",
    "expanded", "cut", "saved", "rescued","turned around", "salvaged", "rejuvenated","revitalized", "revolutionized",
    # Analysis
    "analyzed", "assessed", "evaluated", "researched","identified", "diagnosed", "audited", "investigated",
    "monitored", "measured", "calculated", "forecasted","mapped", "surveyed", "uncovered", "discovered",
    "validated", "tested", "debugged", "troubleshot",
    # Communication
    "presented", "negotiated", "collaborated", "partnered","facilitated", "communicated", "advocated",
    "influenced", "persuaded", "articulated","mediated", "lobbied", "publicized",
    "promoted", "reported", "documented","published", "spoke", "taught", "trained",
    # Operations
    "executed", "administered", "operated", "maintained","supported", "ensured", "onboarded","recruited", "hired", "processed",
    "handled", "scheduled", "organized",
    # Finance / Sales
    "generated", "grew", "drove","acquired", "retained", "budgeted","closed", "converted", "sold","marketed",
    # Technical
    "programmed", "coded", "integrated", "configured", "engineered", "debugged", "tested", "deployed",
    "migrated", "refactored", "containerized","implemented", "tested", "reviewed","planned", "prioritized", "executed",
    "monitored", "tracked", "resolved","supported", "delivered", "maintained"
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
    r"\bhighly skilled\b",
    r"\bvarious tasks\b",
    r"\bexcellent interpersonal skills\b",
    r"\bworks well under pressure\b",
    r"\bmotivated individual\b",
    r"\bdynamic professional\b",
    r"\boutstanding communication skills\b",
    r"\bproven track record\b",
    r"\bgoal[\s-]?oriented\b",
    r"\bresults[\s-]?oriented\b",
    r"\bpeople person\b",
    r"\bquick learner\b",
    r"\bhit the ground running\b",
    r"\bcan-do attitude\b",
    r"\bhighly motivated\b",
    r"\bself-motivated\b",
]

# Quantifiable metric patterns
_YEAR_RE = re.compile(r"\b(?:19|20)\d{2}\b")

_DATE_RE = re.compile(
    r"\b\d{1,2}[/-]\d{4}\b"                 # 01/2023
    r"|\b\d{4}[/-]\d{1,2}\b"               # 2023/01
    r"|\b(?:19|20)\d{2}\s*[-–]\s*(?:19|20)\d{2}\b",  # 2020-2024
    re.IGNORECASE,
)
_PHONE_RE = re.compile(
    r"(?:\+\d{1,3}[-.\s]?)?"                  # optional country code
    r"(?:\(\d{2,4}\)[-.\s]?|\d{2,4}[-.\s])?"  # optional area code, parens or not
    r"\d{3,4}[-.\s]?\d{4}\b"                   # main number block
)

_NON_ACHIEVEMENT_NUMBER_RE = re.compile(
    r"\b\d+\+?\s*years?\s*(?:of\s*)?(?:experience|exp)\b"
    r"|\bpage\s*\d+\s*of\s*\d+\b"
    r"|\b(?:am|is|was|aged?)\s*\d+\s*years?\s*old\b",
    re.IGNORECASE,
)

# Money
MONEY_PATTERN = re.compile(
    r"(?:\$|€|£|¥|USD|EUR|GBP)\s*"
    r"\d[\d,]*(?:\.\d+)?\s*"
    r"(?:thousand|million|billion|k|m|b|mm|mn|bn)?\b"
    r"|"
    # number+scale-suffix REQUIRES an explicit currency word immediately
    r"\d[\d,]*(?:\.\d+)?\s*(?:thousand|million|billion|k|m|b|mm|mn|bn)\b\s*"
    r"(?:usd|eur|gbp|dollars?)"
    r"|"
    # money keyword BEFORE the number (e.g. "revenue by $2.5 million")
    r"(?:revenue|sales|cost|budget|profit|saving|savings|spend|"
    r"expenditure|income)s?\s*"
    r"(?:of|by|to|from|at)?\s*"
    r"(?:\$|€|£|¥)?\s*"
    r"\d[\d,]*(?:\.\d+)?\s*(?:thousand|million|billion|k|m|b|mm|mn|bn)?"
    r"|"
    # number+scale-suffix BEFORE a nearby money keyword (e.g. "500k in
    # operational costs", "3M in new sales pipeline")
    r"\d[\d,]*(?:\.\d+)?\s*(?:thousand|million|billion|k|m|b|mm|mn|bn)\b"
    r"[^.]{0,30}?"
    r"(?:revenue|sales|cost|budget|profit|saving|savings|spend|expenditure|income)",
    re.IGNORECASE,
)

MONEY_PERCENT_PATTERN = re.compile(
    r"\d+(?:\.\d+)?\s*%"
    r"[^.]{0,50}?"
    r"(?:revenue|sales|cost|profit|saving|roi|margin|budget)"

    r"|"

    r"(?:revenue|sales|cost|profit|saving|roi|margin|budget)"
    r"[^.]{0,50}?"
    r"\d+(?:\.\d+)?\s*%",

    re.IGNORECASE,
)

# Percentages
PERCENT_PATTERN = re.compile(
    r"\b\d+(?:\.\d+)?\s*%"
)

# Generic Numbers
NUMBER_PATTERN = re.compile(
    r"\b\d[\d,]*(?:\.\d+)?"
    r"\+?"
    r"(?:-\d[\d,]*(?:\.\d+)?)?"
    r"(?=\s|$|[.,!?])"
)

# People / Team Metrics
PEOPLE_KEYWORDS = re.compile(
    r"\b\d[\d,]*\+?\s*"
    r"(?:people|persons?|employees?|staff|customers?|clients?|"
    r"users?|members?|reports?|hires?|recruits?|engineers?|"
    r"developers?|interns?|teams?|stakeholders?)\b"

    r"|"

    r"\bteam of \d[\d,]*\b"

    r"|"

    r"\b\d[\d,]*\+?[-\s]*person\s+"
    r"(?:team|group|department|organization|organisation)\b"

    r"|"

    r"\b(?:led|managed|supervised|mentored|directed)\s+"
    r"\d[\d,]*\+?\s+"
    r"(?:people|employees?|staff|engineers?|developers?|"
    r"interns?|contractors?|teams?)",

    re.IGNORECASE,
)

# Scale Metrics
SCALE_PATTERN = re.compile(
    r"\b\d[\d,]*(?:\.\d+)?\s*"
    r"(?:thousand|million|billion|k|m|b)?\s*"
    r"(?:records?|rows?|requests?|transactions?|events?|"
    r"messages?|documents?|files?|orders?|tickets?|"
    r"downloads?|api calls?|queries?)\b",

    re.IGNORECASE,
)

# Performance Metrics
PERFORMANCE_PATTERN = re.compile(
    r"\b\d+(?:\.\d+)?x\b"

    r"|"

    r"\b99(?:\.\d+)?%\s*uptime\b"

    r"|"

    r"\b\d+(?:\.\d+)?\s*"
    r"(?:ms|milliseconds?|s|sec|seconds?|minutes?)\b"

    r"|"

    r"\b(?:latency|response time|throughput|availability|uptime)"
    r"[^.]{0,40}?"
    r"\d+(?:\.\d+)?",

    re.IGNORECASE,
)

# Task / Productivity Metrics
TASK_KEYWORDS = re.compile(
    r"\b(?:saved|reduced|cut|decreased|improved|increased)\b"
    r"[^.]{0,50}?"
    r"\d[\d,]*\+?\s*"
    r"(?:hour|day|week|month|year|minute)s?\b"

    r"|"

    r"\b\d[\d,]*\+?\s*"
    r"(?:hour|day|week|month|year|minute)s?\b"
    r"[^.]{0,50}?"
    r"\b(?:saved|reduced|cut|decreased|faster|quicker)\b"

    r"|"

    r"\b\d+(?:\.\d+)?x\s*"
    r"(?:faster|improvement|increase|reduction|growth)\b"

    r"|"

    r"\b\d[\d,]*\+?\s*"
    r"(?:requests?|tickets?|deployments?|releases?|transactions?|"
    r"orders?|projects?|applications?)\b",

    re.IGNORECASE,
)

# Awards / Recognition
AWARD_KEYWORDS = re.compile(
    r"\b(?:awards?|recognitions?|prizes?|honou?rs?|patents?|"
    r"publications?|papers?|certificates?|"
    r"ranked|ranking|rankings?|top\s+\d+%?)\b",
    re.IGNORECASE,
)

# Helper Functions
def is_year_like(text: str) -> bool:
    return bool(_YEAR_RE.fullmatch(text.strip()))

def is_date_like(text: str) -> bool:
    return bool(_DATE_RE.search(text))

def is_phone_like(text: str) -> bool:
    return bool(_PHONE_RE.search(text))

def is_non_achievement_number(text: str) -> bool:
    return bool(_NON_ACHIEVEMENT_NUMBER_RE.search(text))


# ---------------------------------------------------------------------------
# Pattern -> category, ordered from most-specific to least-specific.
# Only the FIRST matching pattern for a sentence determines its category,
# so a single sentence contributes exactly one quantifiable-impact result instead of one per matching regex.
# ---------------------------------------------------------------------------
PATTERNS = [
    # Highest confidence
    (MONEY_PERCENT_PATTERN, "Money/Finance", "money_percent"),
    (MONEY_PATTERN, "Money/Finance", "money"),
    # Operational impact
    (PERFORMANCE_PATTERN, "Performance", "performance"),
    (SCALE_PATTERN, "Scale", "scale"),
    (PEOPLE_KEYWORDS, "People", "people"),
    (TASK_KEYWORDS, "Tasks/Operations", "task"),
    # Recognition
    (AWARD_KEYWORDS, "Recognition", "award"),
    # Lowest confidence
    (PERCENT_PATTERN, "Performance", "percent"),
    (NUMBER_PATTERN, "General Metrics", "number"),
]


def find_all_matches(sentence: str):
    matches = []
    if not sentence:
        return matches
    if _NON_ACHIEVEMENT_NUMBER_RE.search(sentence):
        return matches
    for rx, category, label in PATTERNS:
        if label == "number":
            for m in rx.finditer(sentence):
                token = m.group(0).strip()

                if is_year_like(token):
                    continue

                if is_date_like(token):
                    continue

                matches.append((category, token, label))

            continue

        for m in rx.finditer(sentence):
            matches.append(
                (category, m.group(0).strip(), label)
            )

    return matches
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

def check_action_verbs_occurrences(cv_text: str) -> dict:
    words = re.findall(r"\b[a-z']+\b", cv_text.lower())

    found_verbs = [w for w in words if w in STRONG_ACTION_VERBS]

    passed = len(found_verbs) >= 5  # at least 5 distinct action verb usages

    details_parts = []
    success_parts = []
    if passed:
        unique_verbs = sorted(set(found_verbs))
        success_parts.append(
            f"Found {len(found_verbs)} action-verb usage(s) "
            f"({', '.join(unique_verbs[:8])}{'...' if len(unique_verbs) > 8 else ''})."
        )
    else:
        if len(found_verbs) == 0:
            details_parts.append(
                "No strong action verbs were detected. Use action-oriented verbs like 'led', 'developed', 'implemented', or 'achieved' to clearly demonstrate your contributions."
            )
        else:
            details_parts.append(
                f"We found {len(found_verbs)} strong action verb(s). Consider using a wider variety of action verbs throughout your CV to better showcase your accomplishments (recommended: at least 5)."
            )

    return {
        "pass": passed,
        "details": " ".join(details_parts),
        "success_message": " ".join(success_parts),
        "action_verbs_count": len(found_verbs),
    }

def check_pronouns(cv_text: str) -> dict:
    words = re.findall(r"\b[a-z']+\b", cv_text.lower())
    found_pronouns = [w for w in words if w in PERSONAL_PRONOUNS]
    passed = len(found_pronouns) == 0

    if passed:
        success_message = "No personal pronouns detected."
    else:
        details = (
            f"Found {len(found_pronouns)} personal pronoun occurrence(s). "
            "CVs are typically written without first-person language. Start statements with action verbs instead."
        )

    return {
        "pass": passed,
        "details": details if not passed else "",
        "success_message": success_message if passed else "",
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
        items = [f"'{p}'" for p, c in found_vague[:5]]
        details = (
            f"We found {len(found_vague)} phrase(s) that may weaken the impact of your CV: "
            f"{', '.join(items)}. Recruiters and ATS systems respond better to concrete "
            "examples backed by achievements and metrics."
        )

    return {"pass": passed, "details": details, "vague_phrases": found_vague}


# ══════════════════════════════════════════════════════════════════════════════
#  CHECK 4 – Quantifiable impact: ≥ 5 measurable results
# ══════════════════════════════════════════════════════════════════════════════
def check_quantifiable_impact(cv_parsed_content: dict) -> dict:
    sentences = extract_experience_sentences(cv_parsed_content)
    results = []

    for sent in sentences:
        matches = find_all_matches(sent)

        if not matches:
            continue

        for category, matched_text, label in matches:
            results.append({
                "sentence": sent[:150],
                "category": category,
                "type": label,
                "match": matched_text
            })

    count = len(results)
    passed = count >= 5
    details = (
            f"Your CV has only {count} measurable achievement(s). " if len(results)>0 else "No measurable achievement(s) Found. "
            "Add more impact using metrics like percentages, revenue, team size, time saved, or scale of work."
        ) if not passed else "Your CV contains sufficient measurable achievements. Great job!"

    return {
        "pass": passed,
        "details": details,
        "count": count,
        "results": results,
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
    checks = [
        {
            "id": 1,
            "name": "Headings in logical order and clearly defined",
            **check_headings(cv_parsed_content['all_sections_in_order']),
        },
        {
            "id": 2,
            "name": "Action verbs used, no personal pronouns",
            **check_action_verbs_occurrences(cv_text),
        },
        {
            "id": 3,
            "name": "no personal pronouns used",
            **check_pronouns(cv_text),
        },
        {
            "id": 4,
            "name": "Clear and specific wording (no vague/generic phrases)",
            **check_clarity(cv_text),
        },
        {
            "id": 5,
            "name": "Quantifiable impact: ≥ 5 measurable results",
            **check_quantifiable_impact(cv_parsed_content),
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