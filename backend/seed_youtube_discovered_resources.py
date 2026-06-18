import asyncio
import os
import re
from typing import Dict, Any, List, Set

import httpx
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")

YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
YOUTUBE_VIDEOS_URL = "https://www.googleapis.com/youtube/v3/videos"

MIN_YOUTUBE_MINUTES = 10
MAX_VIDEOS_PER_SKILL = 4

# Use env vars to batch safely:
# set YOUTUBE_SEED_SKILLS_LIMIT=50
# set YOUTUBE_SEED_START_OFFSET=0
SKILLS_LIMIT = int(os.getenv("YOUTUBE_SEED_SKILLS_LIMIT", "40"))
START_OFFSET = int(os.getenv("YOUTUBE_SEED_START_OFFSET", "140"))

BAD_TITLE_WORDS = [
    "#shorts", "shorts", "meme", "funny", "tiktok", "status", "whatsapp", "motivation"
]

GOOD_CHANNEL_HINTS = [
    "freecodecamp", "statquest", "corey schafer", "sentdex", "codebasics",
    "data school", "deeplearningai", "google cloud", "microsoft developer",
    "ibm technology", "kaggle", "python programmer"
]


def require_env() -> None:
    missing = []
    if not SUPABASE_URL:
        missing.append("SUPABASE_URL")
    if not SUPABASE_KEY:
        missing.append("SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY")
    if not YOUTUBE_API_KEY:
        missing.append("YOUTUBE_API_KEY")
    if missing:
        raise RuntimeError(f"Missing env vars: {', '.join(missing)}")


def parse_iso_duration_to_minutes(duration: str) -> int:
    h = re.search(r"(\d+)H", duration or "")
    m = re.search(r"(\d+)M", duration or "")
    s = re.search(r"(\d+)S", duration or "")

    minutes = 0
    if h:
        minutes += int(h.group(1)) * 60
    if m:
        minutes += int(m.group(1))
    if s and int(s.group(1)) >= 30:
        minutes += 1
    return minutes


def canonical_topic_for(skill_name: str) -> str:
    return f"{skill_name} fundamentals".strip().lower()


def week_topic_for(skill_name: str) -> str:
    return f"{skill_name} fundamentals"


def is_bad_video(title: str, description: str) -> bool:
    text = f"{title} {description}".lower()
    return any(word in text for word in BAD_TITLE_WORDS)


def channel_quality_boost(channel_title: str) -> float:
    channel = (channel_title or "").lower()
    return 2.0 if any(hint in channel for hint in GOOD_CHANNEL_HINTS) else 0.0


def duration_score(minutes: int) -> float:
    if minutes < MIN_YOUTUBE_MINUTES:
        return -10.0
    if 8 <= minutes <= 45:
        return 3.0
    if 46 <= minutes <= 90:
        return 2.0
    if minutes > 180:
        return -2.0
    return 1.0


def make_queries(skill_name: str) -> List[str]:
    base = skill_name.strip()
    return [
        f"{base} tutorial",
        f"{base} practical tutorial",
        f"{base} beginner tutorial",
        f"{base} data science tutorial",
        f"{base} full course",
    ]


async def load_all_skills(client: httpx.AsyncClient) -> List[Dict[str, Any]]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/career_skills",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Accept": "application/json",
        },
        params={
            "select": "skill_id,skill_name,category",
            "order": "skill_id.asc",
            "limit": str(SKILLS_LIMIT),
            "offset": str(START_OFFSET),
        },
    )
    response.raise_for_status()
    return response.json() or []


async def load_existing_youtube_urls(client: httpx.AsyncClient) -> Set[str]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/discovered_learning_resources",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Accept": "application/json",
        },
        params={
            "select": "url",
            "resource_type": "eq.youtube",
            "limit": "20000",
        },
    )
    response.raise_for_status()
    rows = response.json() or []
    return {(row.get("url") or "").strip().lower() for row in rows if row.get("url")}


async def fetch_youtube_durations(client: httpx.AsyncClient, video_ids: List[str]) -> Dict[str, int]:
    if not video_ids:
        return {}

    response = await client.get(
        YOUTUBE_VIDEOS_URL,
        params={
            "part": "contentDetails",
            "id": ",".join(video_ids),
            "key": YOUTUBE_API_KEY,
        },
    )
    response.raise_for_status()
    data = response.json()

    duration_map: Dict[str, int] = {}
    for item in data.get("items", []):
        video_id = item.get("id")
        iso_duration = ((item.get("contentDetails") or {}).get("duration") or "")
        if video_id:
            duration_map[video_id] = parse_iso_duration_to_minutes(iso_duration)

    return duration_map


async def search_youtube_for_skill(
    client: httpx.AsyncClient,
    *,
    skill: Dict[str, Any],
    existing_urls: Set[str],
) -> List[Dict[str, Any]]:
    skill_id = skill.get("skill_id")
    skill_name = skill.get("skill_name")
    track_id = None

    if not skill_id or not skill_name:
        return []

    current_level = "beginner"
    target_level = "intermediate"
    week_topic = week_topic_for(skill_name)
    canonical_topic = canonical_topic_for(skill_name)

    collected: List[Dict[str, Any]] = []
    seen_video_ids: Set[str] = set()

    for query in make_queries(skill_name):
        if len(collected) >= MAX_VIDEOS_PER_SKILL:
            break

        try:
            response = await client.get(
                YOUTUBE_SEARCH_URL,
                params={
                    "part": "snippet",
                    "q": query,
                    "key": YOUTUBE_API_KEY,
                    "type": "video",
                    "maxResults": 10,
                    "safeSearch": "strict",
                    "videoDuration": "medium",
                },
            )
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            print(f"WARNING: YouTube search failed for {skill_name!r} query={query!r}: {e}")
            continue

        items = data.get("items", []) or []
        video_ids = []
        for item in items:
            video_id = ((item.get("id") or {}).get("videoId") or "").strip()
            if video_id and video_id not in seen_video_ids:
                video_ids.append(video_id)

        try:
            durations = await fetch_youtube_durations(client, video_ids)
        except Exception as e:
            print(f"WARNING: Duration fetch failed for {skill_name!r}: {e}")
            durations = {}

        for item in items:
            video_id = ((item.get("id") or {}).get("videoId") or "").strip()
            if not video_id or video_id in seen_video_ids:
                continue

            youtube_url = f"https://www.youtube.com/watch?v={video_id}"
            normalized_url = youtube_url.lower()

            if normalized_url in existing_urls:
                seen_video_ids.add(video_id)
                continue

            snippet = item.get("snippet", {}) or {}
            title = snippet.get("title") or f"{skill_name} tutorial"
            description = snippet.get("description") or ""
            channel_title = snippet.get("channelTitle") or ""

            minutes = int(durations.get(video_id) or 0)
            if minutes < MIN_YOUTUBE_MINUTES:
                continue

            if is_bad_video(title, description):
                continue

            score = 10.0 + duration_score(minutes) + channel_quality_boost(channel_title)

            collected.append({
                "track_id": track_id,
                "skill_id": skill_id,
                "plan_id": None,
                "week_topic": week_topic,
                "canonical_topic": canonical_topic,
                "current_level": current_level,
                "target_level": target_level,
                "resource_type": "youtube",
                "title": title,
                "url": youtube_url,
                "snippet": description[:1000],
                "source_provider": "youtube_seed_all",
                "source_domain": "youtube.com",
                "estimated_duration_minutes": minutes,
                "base_score": round(score, 2),
                "final_score": round(score, 2),
                "times_selected": 1,
                "times_validation_passed": 1,
                "times_used_in_final_plan": 1,
                "is_active": True,
                "is_official": False,
                "is_practical": True,
                "was_fallback": False,
            })

            existing_urls.add(normalized_url)
            seen_video_ids.add(video_id)

            if len(collected) >= MAX_VIDEOS_PER_SKILL:
                break

    return collected


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

    async with httpx.AsyncClient(timeout=30.0) as client:
        skills = await load_all_skills(client)
        existing_urls = await load_existing_youtube_urls(client)

        print(f"Loaded skills: {len(skills)}")
        print(f"Existing youtube URLs: {len(existing_urls)}")
        print(f"Start offset: {START_OFFSET} | limit: {SKILLS_LIMIT}")
        print("-" * 60)

        total_inserted = 0

        for index, skill in enumerate(skills, start=1):
            skill_name = skill.get("skill_name")
            try:
                rows = await search_youtube_for_skill(
                    client,
                    skill=skill,
                    existing_urls=existing_urls,
                )
                await insert_rows(client, rows)
                total_inserted += len(rows)

                print(f"OK {index}/{len(skills)} {skill_name}: inserted {len(rows)} videos")
                await asyncio.sleep(0.5)

            except Exception as e:
                print(f"FAILED {index}/{len(skills)} {skill_name}: {e}")

        print("-" * 60)
        print(f"Done. Total inserted: {total_inserted}")


if __name__ == "__main__":
    asyncio.run(main())
