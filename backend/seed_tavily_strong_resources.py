"""
seed_tavily_strong_resources.py

Seeds strong docs/practice/project resources from Tavily into:
public.discovered_learning_resources

Run:
    python seed_tavily_strong_resources.py

Batching on Windows CMD:
    set TAVILY_SEED_SKILLS_LIMIT=20
    set TAVILY_SEED_START_OFFSET=0
    python seed_tavily_strong_resources.py

Required .env:
    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
    TAVILY_API_KEY

Notes:
- YouTube is intentionally excluded here. Use YouTube API seeder for videos.
- Blocks weak/generic URLs like github.com/topics.
- Keeps only docs/practice/project.
"""

import asyncio
import os
import re
from typing import Dict, Any, List, Set, Optional
from urllib.parse import urlparse

import httpx
from dotenv import load_dotenv


load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")

TAVILY_URL = "https://api.tavily.com/search"

SKILLS_LIMIT = int(os.getenv("TAVILY_SEED_SKILLS_LIMIT", "30"))
START_OFFSET = int(os.getenv("TAVILY_SEED_START_OFFSET", "0"))

MAX_PER_TYPE_PER_SKILL = int(os.getenv("TAVILY_MAX_PER_TYPE_PER_SKILL", "2"))

RESOURCE_TYPES = ["docs", "practice", "project"]

BLACKLIST_DOMAINS = {
    "pinterest.com",
    "quora.com",
    "linkedin.com",
    "medium.com",
    "slideshare.net",
    "scribd.com",
    "facebook.com",
    "reddit.com",
}

LOW_QUALITY_DOMAINS = {
    "imarticus.org",
    "simplilearn.com",
    "intellipaat.com",
    "upgrad.com",
}

TRUSTED_DOC_DOMAINS = {
    "docs.python.org",
    "developer.mozilla.org",
    "learn.microsoft.com",
    "react.dev",
    "web.dev",
    "scikit-learn.org",
    "pandas.pydata.org",
    "numpy.org",
    "matplotlib.org",
    "seaborn.pydata.org",
    "fastapi.tiangolo.com",
    "postgresql.org",
    "kubernetes.io",
    "docs.docker.com",
    "aws.amazon.com",
    "cloud.google.com",
    "ibm.com",
}

TRUSTED_PRACTICE_DOMAINS = {
    "kaggle.com",
    "github.com",
    "freecodecamp.org",
    "realpython.com",
    "geeksforgeeks.org",
    "w3resource.com",
    "machinelearningplus.com",
}

TRUSTED_PROJECT_DOMAINS = {
    "github.com",
    "gitlab.com",
    "kaggle.com",
}


def require_env() -> None:
    missing = []
    if not SUPABASE_URL:
        missing.append("SUPABASE_URL")
    if not SUPABASE_KEY:
        missing.append("SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY")
    if not TAVILY_API_KEY:
        missing.append("TAVILY_API_KEY")
    if missing:
        raise RuntimeError(f"Missing env vars: {', '.join(missing)}")


def domain_of(url: str) -> str:
    try:
        return urlparse(url).netloc.lower().replace("www.", "")
    except Exception:
        return ""


def normalize_url(url: str) -> str:
    return (url or "").strip().lower().rstrip("/")


def is_github_topics(url: str) -> bool:
    return "github.com/topics/" in (url or "").lower()


def is_generic_root(url: str) -> bool:
    clean = normalize_url(url)
    return clean in {
        "https://github.com",
        "https://www.github.com",
        "https://kaggle.com",
        "https://www.kaggle.com",
    }


def is_bad_url(url: str) -> bool:
    if not url:
        return True
    d = domain_of(url)
    if not d:
        return True
    if any(bad in d for bad in BLACKLIST_DOMAINS):
        return True
    if is_github_topics(url):
        return True
    if is_generic_root(url):
        return True
    return False


def clean_skill_name(skill_name: str) -> str:
    text = skill_name or ""
    text = re.sub(r"\(.*?\)", " ", text)
    text = text.replace("&", " and ")
    text = re.sub(r"[/|,]", " ", text)
    text = " ".join(text.split())
    return text.strip()


def infer_track_id(skill: Dict[str, Any]) -> Optional[int]:
    return skill.get("track_id") or skill.get("career_track_id") or None


def week_topic_for(skill_name: str, resource_type: str) -> str:
    skill = skill_name.strip()
    if resource_type == "docs":
        return f"{skill} fundamentals"
    if resource_type == "practice":
        return f"{skill} applied practice"
    return f"{skill} mini project implementation"


def canonical_topic_for(skill_name: str, resource_type: str) -> str:
    return week_topic_for(skill_name, resource_type).lower()


def make_query(skill_name: str, resource_type: str, category: Optional[str] = None) -> str:
    clean = clean_skill_name(skill_name)
    category_hint = f" {category}" if category else ""

    if resource_type == "docs":
        return f"{clean}{category_hint} official documentation tutorial guide"
    if resource_type == "practice":
        return f"{clean}{category_hint} exercises practice notebook hands-on"
    if resource_type == "project":
        return f"{clean}{category_hint} github project repository real world example"
    return f"{clean}{category_hint} learning resource"


def resource_type_ok(url: str, title: str, snippet: str, resource_type: str) -> bool:
    d = domain_of(url)
    text = f"{title} {snippet} {url}".lower()

    if is_bad_url(url):
        return False

    if resource_type == "docs":
        if d in TRUSTED_DOC_DOMAINS:
            return True
        return any(word in text for word in ["documentation", "docs", "tutorial", "guide", "manual"])

    if resource_type == "practice":
        if d in TRUSTED_PRACTICE_DOMAINS:
            return True
        return any(word in text for word in ["exercise", "practice", "notebook", "hands-on", "problems", "quiz"])

    if resource_type == "project":
        if d in TRUSTED_PROJECT_DOMAINS and not is_github_topics(url):
            return True
        return "github.com/" in url.lower() and not is_github_topics(url)

    return False


def score_resource(url: str, title: str, snippet: str, resource_type: str, skill_name: str) -> float:
    d = domain_of(url)
    text = f"{title} {snippet}".lower()
    skill_words = [w.lower() for w in re.findall(r"[a-zA-Z0-9]+", clean_skill_name(skill_name)) if len(w) > 2]

    score = 8.0

    if resource_type == "docs" and d in TRUSTED_DOC_DOMAINS:
        score += 5
    if resource_type == "practice" and d in TRUSTED_PRACTICE_DOMAINS:
        score += 4
    if resource_type == "project" and d in TRUSTED_PROJECT_DOMAINS:
        score += 5

    if d in LOW_QUALITY_DOMAINS:
        score -= 4

    hits = sum(1 for w in skill_words if w in text)
    if skill_words:
        score += min(3.0, hits / max(len(skill_words), 1) * 3)

    if resource_type == "project":
        if "github.com/topics" in url.lower():
            score -= 10
        if "github.com/" in url.lower() and len(urlparse(url).path.strip("/").split("/")) >= 2:
            score += 2

    if any(word in text for word in ["official", "documentation", "user guide"]):
        score += 1.5

    if any(word in text for word in ["exercise", "notebook", "hands-on", "project", "repository"]):
        score += 1.5

    return round(max(score, 1.0), 2)


async def load_skills(client: httpx.AsyncClient) -> List[Dict[str, Any]]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/career_skills",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Accept": "application/json",
        },
        params={
            "select": "*",
            "order": "skill_id.asc",
            "limit": str(SKILLS_LIMIT),
            "offset": str(START_OFFSET),
        },
    )
    response.raise_for_status()
    return response.json() or []


async def load_existing_urls(client: httpx.AsyncClient) -> Set[str]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/discovered_learning_resources",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Accept": "application/json",
        },
        params={
            "select": "url",
            "limit": "50000",
        },
    )
    response.raise_for_status()
    rows = response.json() or []
    return {normalize_url(row.get("url")) for row in rows if row.get("url")}


async def tavily_search(client: httpx.AsyncClient, query: str) -> List[Dict[str, Any]]:
    response = await client.post(
        TAVILY_URL,
        json={
            "api_key": TAVILY_API_KEY,
            "query": query,
            "search_depth": "advanced",
            "max_results": 8,
            "include_answer": False,
            "include_raw_content": False,
        },
    )
    response.raise_for_status()
    data = response.json()
    return data.get("results", []) or []


async def search_resources_for_skill(
    client: httpx.AsyncClient,
    *,
    skill: Dict[str, Any],
    existing_urls: Set[str],
) -> List[Dict[str, Any]]:
    skill_id = skill.get("skill_id")
    skill_name = skill.get("skill_name") or skill.get("name") or skill.get("title") or skill.get("skill")
    category = skill.get("category")
    track_id = infer_track_id(skill)

    if not skill_id or not skill_name:
        return []

    rows: List[Dict[str, Any]] = []

    for resource_type in RESOURCE_TYPES:
        query = make_query(skill_name, resource_type, category=category)

        try:
            results = await tavily_search(client, query)
        except Exception as e:
            print(f"WARNING Tavily failed | skill={skill_name!r} | type={resource_type} | {e}")
            continue

        added_for_type = 0

        for item in results:
            url = item.get("url") or ""
            title = item.get("title") or skill_name
            snippet = item.get("content") or item.get("snippet") or ""

            normalized = normalize_url(url)
            if not normalized or normalized in existing_urls:
                continue

            if not resource_type_ok(url, title, snippet, resource_type):
                continue

            score = score_resource(url, title, snippet, resource_type, skill_name)

            row = {
                "track_id": track_id,
                "skill_id": skill_id,
                "plan_id": None,
                "week_topic": week_topic_for(skill_name, resource_type),
                "canonical_topic": canonical_topic_for(skill_name, resource_type),
                "current_level": "none",
                "target_level": "beginner",
                "resource_type": resource_type,
                "title": title[:300],
                "url": url,
                "snippet": snippet[:1000],
                "source_provider": "tavily_seed",
                "source_domain": domain_of(url),
                "estimated_duration_minutes": 30 if resource_type == "docs" else 120 if resource_type == "practice" else None,
                "base_score": score,
                "final_score": score,
                "times_selected": 1,
                "times_validation_passed": 1,
                "times_used_in_final_plan": 1,
                "is_active": True,
                "is_official": domain_of(url) in TRUSTED_DOC_DOMAINS,
                "is_practical": resource_type in {"practice", "project"},
                "was_fallback": False,
            }

            rows.append(row)
            existing_urls.add(normalized)
            added_for_type += 1

            if added_for_type >= MAX_PER_TYPE_PER_SKILL:
                break

        await asyncio.sleep(0.15)

    return rows


async def insert_rows(client: httpx.AsyncClient, rows: List[Dict[str, Any]]) -> None:
    if not rows:
        return

    response = await client.post(
        f"{SUPABASE_URL}/rest/v1/discovered_learning_resources",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates",
        },
        json=rows,
    )

    if response.status_code not in (200, 201):
        print("Insert failed")
        print(response.status_code)
        print(response.text)
        response.raise_for_status()


async def main() -> None:
    require_env()

    async with httpx.AsyncClient(timeout=35.0) as client:
        skills = await load_skills(client)
        existing_urls = await load_existing_urls(client)

        print(f"Loaded skills: {len(skills)}")
        print(f"Existing URLs: {len(existing_urls)}")
        print(f"Start offset: {START_OFFSET} | limit: {SKILLS_LIMIT}")
        print("-" * 60)

        total = 0

        for idx, skill in enumerate(skills, start=1):
            skill_name = skill.get("skill_name") or skill.get("name") or skill.get("title") or skill.get("skill")

            try:
                rows = await search_resources_for_skill(
                    client,
                    skill=skill,
                    existing_urls=existing_urls,
                )
                await insert_rows(client, rows)
                total += len(rows)

                counts = {}
                for r in rows:
                    counts[r["resource_type"]] = counts.get(r["resource_type"], 0) + 1

                print(f"OK {idx}/{len(skills)} {skill_name}: inserted {len(rows)} {counts}")
                await asyncio.sleep(0.3)

            except Exception as e:
                print(f"FAILED {idx}/{len(skills)} {skill_name}: {e}")

        print("-" * 60)
        print(f"Done. Total inserted: {total}")


if __name__ == "__main__":
    asyncio.run(main())
