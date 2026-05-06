import language_tool_python
import re
from .abbreviations_detector import detect_abbreviations

SKILLS_WHITELIST = {
    # Frameworks & Libraries
    "angular", "react", "vue", "svelte", "nextjs", "nuxtjs", "gatsby",
    "django", "fastapi", "flask", "spring", "springboot", "express", "nestjs",
    "pytorch", "tensorflow", "scikit-learn", "langchain", "huggingface",

    # Languages
    "python", "javascript", "typescript", "golang", "kotlin", "rust",
    "scala", "swift", "dart", "php", "elixir", "haskell",

    # Concepts & Patterns (commonly used as nouns in descriptions)
    "spa", "api", "rest", "crud", "orm", "cli", "sdk", "ui", "ux",
    "ci", "cd", "db", "sql", "nosql", "oop", "mvc", "mvp", "mvvm",
    "jwt", "oauth", "rbac", "iam", "sso", "saml",
    "etl", "elt", "dag", "mlops", "devops", "dataops",
    "microservice", "microservices", "monolith", "serverless",

    # Infrastructure & Tools
    "docker", "kubernetes", "terraform", "ansible", "jenkins", "grafana",
    "prometheus", "nginx", "apache", "rabbitmq", "kafka", "redis",
    "elasticsearch", "postgresql", "mongodb", "mysql", "sqlite",
    "aws", "gcp", "azure", "heroku", "vercel", "netlify",

    # Adjective forms used in CVs
    "restful", "dockerized", "containerized", "scalable", "microservices",
    "event-driven", "cloud-native", "open-source",
}

INSTITUTIONS_WHITELIST = {
    "iti", "nti", "eelu", "aast", "guc", "auc", "msa", "bue", "ejust",
    "mit", "ucla", "nyu", "cmu",
    "ccna", "ccnp", "ccie", "hcia", "hcip", "hcie",
    "rhca", "rhce", "rhcsa", "cka", "ckad", "cks",
    "pmp", "itil", "ceh", "oscp", "cissp",
    "ielts", "toefl", "bsc", "msc", "mba", "phd",
}

# Suffixes commonly added to tech acronyms in job descriptions
COMMON_SUFFIXES = ["s", "ed", "ing", "er", "ers", "ful", "ized", "ise", "ize"]


def normalize_token(token: str) -> list[str]:
    """
    Return the token + all suffix-stripped variants to check against whitelist.
    e.g. 'SPAs' -> ['spas', 'spa']
         'RESTful' -> ['restful', 'rest']
         'Dockerized' -> ['dockerized', 'docker']
         'APIs' -> ['apis', 'api']
    """
    lower = token.lower()
    candidates = [lower]

    for suffix in COMMON_SUFFIXES:
        if lower.endswith(suffix) and len(lower) - len(suffix) >= 2:
            candidates.append(lower[: -len(suffix)])

    return candidates


def extract_abbreviations(cv_text: str) -> set:
    """Auto-whitelist any ALL-CAPS word (2-6 chars) found in the CV."""
    abbreviations = detect_abbreviations(cv_text)
    return {a.lower() for a in abbreviations}


def build_personal_whitelist(user_info: dict) -> set:
    whitelist = set()
    for value in user_info.values():
        if not value:
            continue
        tokens = re.split(r'[\s\-\.\,\/\@\+]+', value)
        for token in tokens:
            cleaned = token.strip().lower()
            if cleaned:
                whitelist.add(cleaned)
    return whitelist


def is_whitelisted(flagged: str, whitelist: set) -> bool:
    """Check the token AND its de-suffixed variants against the whitelist."""
    for candidate in normalize_token(flagged):
        if candidate in whitelist:
            return True
    return False


def check_typos(cv_text: str, extra_skills: set = None, user_info: dict = None) -> list[dict]:
    # Build unified whitelist
    whitelist = SKILLS_WHITELIST | INSTITUTIONS_WHITELIST
    whitelist.update(extract_abbreviations(cv_text))
    if extra_skills:
        whitelist.update(extra_skills)
    if user_info:
        whitelist.update(build_personal_whitelist(user_info))

    try:
        tool = language_tool_python.LanguageTool('en-US', remote_server='https://api.languagetool.org/v2')
        matches = tool.check(cv_text)
    except Exception as e:
        print("Error checking typos:", e)
        matches = []
    issues = []

    for match in matches:
        flagged = cv_text[match.offset: match.offset + match.error_length]

        # Check token + suffix-stripped variants
        if is_whitelisted(flagged, whitelist):
            continue

        issues.append({
            "error":       flagged,
            "message":     match.message,
            "suggestions": match.replacements[:3],
            "offset":      match.offset,
            "rule_id":     match.rule_id,
            "category":    match.category,
        })

    return issues


def get_typos_with_suggestions(cv_text: str, user_info: dict, extra_skills: set = None) -> list[dict]:
    issues = check_typos(cv_text, user_info, extra_skills)
    return [
        {
            "error":       issue["error"],
            "suggestions": issue["suggestions"],
            "category":    issue["category"],
        }
        for issue in issues
    ]