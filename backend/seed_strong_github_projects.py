"""
seed_strong_github_projects.py

Seeds strong PROJECT resources for skills into:
public.discovered_learning_resources

Run:
    python seed_strong_github_projects.py

Windows CMD batching:
    set PROJECT_SEED_SKILLS_LIMIT=30
    set PROJECT_SEED_START_OFFSET=0
    python seed_strong_github_projects.py

Required .env:
    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
    GITHUB_TOKEN
    TAVILY_API_KEY optional fallback

What it does:
- Reads skills from career_skills
- Searches GitHub repositories directly
- Falls back to Tavily if GitHub gives nothing
- Blocks github.com/topics and README/blob URLs
- Stores only real GitHub repo URLs as resource_type='project'
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
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")

GITHUB_SEARCH_URL = "https://api.github.com/search/repositories"
TAVILY_URL = "https://api.tavily.com/search"

SKILLS_LIMIT = int(os.getenv("PROJECT_SEED_SKILLS_LIMIT", "50"))
START_OFFSET = int(os.getenv("PROJECT_SEED_START_OFFSET", "0"))
MAX_PROJECTS_PER_SKILL = int(os.getenv("MAX_PROJECTS_PER_SKILL", "3"))

MIN_GITHUB_STARS = int(os.getenv("PROJECT_MIN_GITHUB_STARS", "10"))

BAD_DOMAINS = {
    "linkedin.com",
    "pinterest.com",
    "quora.com",
    "medium.com",
    "slideshare.net",
    "scribd.com",
}

BAD_REPO_WORDS = {
    "awesome",
    "cheatsheet",
    "cheat-sheet",
    "roadmap",
    "interview",
    "questions",
    "notes",
    "book",
    "books",
    "course-list",
    "resources",
    "tutorials-only",
}

GOOD_PROJECT_WORDS = {
    "project",
    "pipeline",
    "analysis",
    "dashboard",
    "prediction",
    "classification",
    "regression",
    "eda",
    "notebook",
    "app",
    "system",
    "case-study",
    "portfolio",
    "end-to-end",
}


def require_env() -> None:
    missing = []
    if not SUPABASE_URL:
        missing.append("SUPABASE_URL")
    if not SUPABASE_KEY:
        missing.append("SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY")
    if not GITHUB_TOKEN:
        missing.append("GITHUB_TOKEN")
    if missing:
        raise RuntimeError(f"Missing env vars: {', '.join(missing)}")


def domain_of(url: str) -> str:
    try:
        return urlparse(url).netloc.lower().replace("www.", "")
    except Exception:
        return ""


def normalize_url(url: str) -> str:
    return (url or "").strip().lower().rstrip("/")


def clean_skill_name(skill_name: str) -> str:
    text = skill_name or ""
    text = re.sub(r"\(.*?\)", " ", text)
    text = text.replace("&", " and ")
    text = re.sub(r"[/|,]", " ", text)
    return " ".join(text.split()).strip()


def is_real_github_repo_url(url: str) -> bool:
    url = normalize_url(url)
    if "github.com/" not in url:
        return False
    if "github.com/topics/" in url:
        return False
    if "/blob/" in url or "/tree/" in url:
        return False
    if "/search" in url:
        return False

    parsed = urlparse(url)
    parts = [p for p in parsed.path.split("/") if p]

    # github.com/owner/repo only
    return len(parts) == 2


def repo_name_from_url(url: str) -> str:
    parsed = urlparse(url)
    parts = [p for p in parsed.path.split("/") if p]
    if len(parts) >= 2:
        return f"{parts[0]}/{parts[1]}".lower()
    return ""


def has_bad_repo_word(url: str, title: str, description: str) -> bool:
    text = f"{url} {title} {description}".lower()
    return any(word in text for word in BAD_REPO_WORDS)


def project_quality_score(
    *,
    skill_name: str,
    title: str,
    description: str,
    url: str,
    stars: int = 0,
    forks: int = 0,
    language: Optional[str] = None,
) -> float:
    clean_skill = clean_skill_name(skill_name).lower()
    skill_words = [w for w in re.findall(r"[a-zA-Z0-9]+", clean_skill) if len(w) > 2]

    text = f"{title} {description} {url}".lower()
    score = 8.0

    # skill match
    hits = sum(1 for w in skill_words if w in text)
    if skill_words:
        score += min(4.0, (hits / max(len(skill_words), 1)) * 4)

    # repo popularity
    if stars >= 1000:
        score += 5
    elif stars >= 300:
        score += 4
    elif stars >= 100:
        score += 3
    elif stars >= 30:
        score += 2
    elif stars >= MIN_GITHUB_STARS:
        score += 1

    if forks >= 50:
        score += 1.5
    elif forks >= 10:
        score += 0.8

    if any(word in text for word in GOOD_PROJECT_WORDS):
        score += 3

    if has_bad_repo_word(url, title, description):
        score -= 5

    if language and language.lower() in {"python", "jupyter notebook", "sql", "r"}:
        score += 1.5

    return round(max(score, 1.0), 2)


def make_github_queries(skill_name: str, category: Optional[str]) -> List[str]:
    clean = clean_skill_name(skill_name)
    cat = f" {category}" if category else ""

    return [
        f'"{clean}" project data science stars:>{MIN_GITHUB_STARS}',
        f'"{clean}" notebook project stars:>{MIN_GITHUB_STARS}',
        f'"{clean}" real world project stars:>{MIN_GITHUB_STARS}',
        f'{clean}{cat} portfolio project python stars:>{MIN_GITHUB_STARS}',
        f'{clean}{cat} case study github stars:>{MIN_GITHUB_STARS}',
    ]


def make_tavily_queries(skill_name: str, category: Optional[str]) -> List[str]:
    clean = clean_skill_name(skill_name)
    cat = f" {category}" if category else ""

    return [
        f"{clean}{cat} real world project github repository",
        f"{clean}{cat} portfolio project github data science",
        f"{clean}{cat} end to end project github",
    ]


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


async def load_existing_project_urls(client: httpx.AsyncClient) -> Set[str]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/discovered_learning_resources",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Accept": "application/json",
        },
        params={
            "select": "url",
            "resource_type": "eq.project",
            "limit": "50000",
        },
    )
    response.raise_for_status()
    rows = response.json() or []
    return {normalize_url(row.get("url")) for row in rows if row.get("url")}


async def search_github_projects(
    client: httpx.AsyncClient,
    *,
    skill_name: str,
    category: Optional[str],
    existing_urls: Set[str],
) -> List[Dict[str, Any]]:
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    found: List[Dict[str, Any]] = []

    for query in make_github_queries(skill_name, category):
        if len(found) >= MAX_PROJECTS_PER_SKILL:
            break

        try:
            response = await client.get(
                GITHUB_SEARCH_URL,
                headers=headers,
                params={
                    "q": query,
                    "sort": "stars",
                    "order": "desc",
                    "per_page": 10,
                },
            )
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            print(f"WARNING GitHub failed | skill={skill_name!r} | query={query!r} | {e}")
            continue

        for item in data.get("items", []) or []:
            url = item.get("html_url") or ""
            normalized = normalize_url(url)

            if not is_real_github_repo_url(url):
                continue
            if normalized in existing_urls:
                continue

            title = item.get("full_name") or skill_name
            description = item.get("description") or ""
            stars = int(item.get("stargazers_count") or 0)
            forks = int(item.get("forks_count") or 0)
            language = item.get("language") or ""

            if stars < MIN_GITHUB_STARS:
                continue

            # avoid generic resource collections unless nothing else is found
            if has_bad_repo_word(url, title, description) and len(found) >= 1:
                continue

            score = project_quality_score(
                skill_name=skill_name,
                title=title,
                description=description,
                url=url,
                stars=stars,
                forks=forks,
                language=language,
            )

            found.append({
                "title": title,
                "url": url,
                "snippet": description,
                "source_domain": "github.com",
                "base_score": score,
                "final_score": score,
                "stars": stars,
                "forks": forks,
                "language": language,
            })

            existing_urls.add(normalized)

            if len(found) >= MAX_PROJECTS_PER_SKILL:
                break

        await asyncio.sleep(0.15)

    return found


async def search_tavily_projects(
    client: httpx.AsyncClient,
    *,
    skill_name: str,
    category: Optional[str],
    existing_urls: Set[str],
) -> List[Dict[str, Any]]:
    if not TAVILY_API_KEY:
        return []

    found: List[Dict[str, Any]] = []

    for query in make_tavily_queries(skill_name, category):
        if len(found) >= MAX_PROJECTS_PER_SKILL:
            break

        try:
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
        except Exception as e:
            print(f"WARNING Tavily failed | skill={skill_name!r} | query={query!r} | {e}")
            continue

        for item in data.get("results", []) or []:
            url = item.get("url") or ""
            normalized = normalize_url(url)

            if not is_real_github_repo_url(url):
                continue
            if normalized in existing_urls:
                continue

            title = item.get("title") or repo_name_from_url(url) or skill_name
            snippet = item.get("content") or item.get("snippet") or ""

            if has_bad_repo_word(url, title, snippet) and len(found) >= 1:
                continue

            score = project_quality_score(
                skill_name=skill_name,
                title=title,
                description=snippet,
                url=url,
                stars=0,
                forks=0,
                language=None,
            )

            found.append({
                "title": title[:300],
                "url": url,
                "snippet": snippet[:1000],
                "source_domain": "github.com",
                "base_score": score,
                "final_score": score,
                "stars": 0,
                "forks": 0,
                "language": None,
            })

            existing_urls.add(normalized)

            if len(found) >= MAX_PROJECTS_PER_SKILL:
                break

        await asyncio.sleep(0.15)

    return found


def build_db_rows(skill: Dict[str, Any], projects: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    skill_id = skill.get("skill_id")
    skill_name = skill.get("skill_name") or skill.get("name") or skill.get("title") or skill.get("skill")
    category = skill.get("category")
    track_id = skill.get("track_id") or skill.get("career_track_id")

    rows = []

    for project in projects:
        score = float(project.get("final_score") or project.get("base_score") or 10)

        rows.append({
            "track_id": track_id,
            "skill_id": skill_id,
            "plan_id": None,
            "week_topic": f"{skill_name} mini project implementation",
            "canonical_topic": f"{skill_name} mini project implementation".lower(),
            "current_level": "none",
            "target_level": "beginner",
            "resource_type": "project",
            "title": project["title"][:300],
            "url": project["url"],
            "snippet": (project.get("snippet") or "")[:1000],
            "source_provider": "github_project_seed",
            "source_domain": "github.com",
            "estimated_duration_minutes": None,
            "base_score": score,
            "final_score": score,
            "times_selected": 1,
            "times_validation_passed": 1,
            "times_used_in_final_plan": 1,
            "is_active": True,
            "is_official": False,
            "is_practical": True,
            "was_fallback": False,
        })

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
        existing_urls = await load_existing_project_urls(client)

        print(f"Loaded skills: {len(skills)}")
        print(f"Existing project URLs: {len(existing_urls)}")
        print(f"Start offset: {START_OFFSET} | limit: {SKILLS_LIMIT}")
        print("-" * 60)

        total = 0

        for idx, skill in enumerate(skills, start=1):
            skill_name = skill.get("skill_name") or skill.get("name") or skill.get("title") or skill.get("skill")
            category = skill.get("category")

            try:
                projects = await search_github_projects(
                    client,
                    skill_name=skill_name,
                    category=category,
                    existing_urls=existing_urls,
                )

                if len(projects) < MAX_PROJECTS_PER_SKILL:
                    fallback_projects = await search_tavily_projects(
                        client,
                        skill_name=skill_name,
                        category=category,
                        existing_urls=existing_urls,
                    )
                    projects.extend(fallback_projects)

                projects = projects[:MAX_PROJECTS_PER_SKILL]
                rows = build_db_rows(skill, projects)
                await insert_rows(client, rows)

                total += len(rows)
                print(f"OK {idx}/{len(skills)} {skill_name}: inserted {len(rows)} projects")

                await asyncio.sleep(0.4)

            except Exception as e:
                print(f"FAILED {idx}/{len(skills)} {skill_name}: {e}")

        print("-" * 60)
        print(f"Done. Total inserted: {total}")


if __name__ == "__main__":
    asyncio.run(main())
