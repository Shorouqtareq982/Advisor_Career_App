"""
Resource Search Service
Uses YouTube API and SerpApi to fetch real learning resources.

This version is:
- level-aware
- time-aware
- guarantees mixed weekly resources when possible
- prefers:
    1) one YouTube
    2) one trusted non-YouTube
    3) one practice/project
    4) one extra best match
"""

import logging
from typing import List, Dict, Any, Optional

import httpx

from core.config import settings

logger = logging.getLogger(__name__)


class ResourceSearchService:
    def __init__(self):
        self.youtube_api_key = getattr(settings, "YOUTUBE_API_KEY", "")
        self.serpapi_api_key = getattr(settings, "SERPAPI_API_KEY", "")

        self.youtube_base_url = "https://www.googleapis.com/youtube/v3/search"
        self.serpapi_base_url = "https://serpapi.com/search"

    async def search_resources(
        self,
        resource_queries: List[Dict[str, Any]],
        max_per_week: int = 4,
        current_level: Optional[str] = None,
        target_level: Optional[str] = None,
        available_hours_per_week: Optional[int] = None,
        week_number: Optional[int] = None,
        duration_weeks: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Build a balanced weekly resource set.

        Output preference:
        - 1 YouTube
        - 1 trusted non-YouTube docs/course/article
        - 1 practice/project
        - 1 extra best-ranked item

        Ranking considers:
        - trusted source
        - resource type
        - level suitability
        - week progression
        - available hours per week
        """
        youtube_results: List[Dict[str, Any]] = []
        non_youtube_results: List[Dict[str, Any]] = []

        for item in resource_queries or []:
            query = (item.get("query") or "").strip()
            resource_type = (item.get("type") or "article").strip().lower()
            title = (item.get("title") or query or "Learning Resource").strip()

            if not query:
                continue

            try:
                if resource_type == "youtube":
                    results = await self._search_youtube(query=query, title=title)
                    youtube_results.extend(results)
                else:
                    results = await self._search_serpapi(
                        query=query,
                        resource_type=resource_type,
                        title=title
                    )
                    non_youtube_results.extend(results)
            except Exception as e:
                logger.warning(f"Resource search failed for query='{query}': {e}")

        youtube_ranked = self._rank_and_deduplicate(
            items=youtube_results,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
            week_number=week_number,
            duration_weeks=duration_weeks,
        )

        non_youtube_ranked = self._rank_and_deduplicate(
            items=non_youtube_results,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
            week_number=week_number,
            duration_weeks=duration_weeks,
        )

        final_results: List[Dict[str, Any]] = []
        used_urls = set()

        def try_add_first(items: List[Dict[str, Any]], preferred_types: Optional[List[str]] = None) -> None:
            for item in items:
                url = item.get("url")
                item_type = item.get("type")
                if not url or url in used_urls:
                    continue
                if preferred_types and item_type not in preferred_types:
                    continue
                final_results.append(item)
                used_urls.add(url)
                return

        # 1) force one YouTube if possible
        try_add_first(youtube_ranked)

        # 2) force one trusted non-YouTube explanatory resource
        try_add_first(non_youtube_ranked, preferred_types=["docs", "course", "article"])

        # 3) force one hands-on resource if possible
        try_add_first(non_youtube_ranked, preferred_types=["practice", "project"])

        # 4) fill remaining slots by best overall ranking
        combined = self._rank_and_deduplicate(
            items=youtube_ranked + non_youtube_ranked,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
            week_number=week_number,
            duration_weeks=duration_weeks,
        )

        for item in combined:
            if len(final_results) >= max_per_week:
                break

            url = item.get("url")
            if not url or url in used_urls:
                continue

            final_results.append(item)
            used_urls.add(url)

        return final_results[:max_per_week]

    async def _search_youtube(self, query: str, title: str) -> List[Dict[str, Any]]:
        if not self.youtube_api_key:
            logger.warning("YOUTUBE_API_KEY missing, skipping YouTube search")
            return []

        params = {
            "part": "snippet",
            "q": query,
            "type": "video",
            "maxResults": 6,
            "key": self.youtube_api_key,
            "videoEmbeddable": "true",
            "safeSearch": "moderate",
        }

        logger.info(f"[YouTube] searching for: {query}")

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(self.youtube_base_url, params=params)
            response.raise_for_status()
            data = response.json()

        results = []
        for index, item in enumerate(data.get("items", []), start=1):
            video_id = item.get("id", {}).get("videoId")
            snippet = item.get("snippet", {})
            if not video_id:
                continue

            results.append({
                "title": snippet.get("title") or title,
                "url": f"https://www.youtube.com/watch?v={video_id}",
                "type": "youtube",
                "snippet": snippet.get("description") or snippet.get("channelTitle"),
                "source": "YouTube",
                "position": index,
                "thumbnail": (
                    snippet.get("thumbnails", {})
                    .get("high", {})
                    .get("url")
                ),
            })

        return results

    async def _search_serpapi(
        self,
        query: str,
        resource_type: str,
        title: str
    ) -> List[Dict[str, Any]]:
        if not self.serpapi_api_key:
            logger.warning("SERPAPI_API_KEY missing, skipping SerpApi search")
            return []

        params = {
            "engine": "google",
            "q": self._build_google_query(query, resource_type),
            "api_key": self.serpapi_api_key,
            "hl": "en",
            "gl": "eg",
            "num": 6,
        }

        logger.info(f"[SerpApi] searching for: {params['q']}")

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(self.serpapi_base_url, params=params)
            response.raise_for_status()
            data = response.json()

        results = []
        for item in data.get("organic_results", [])[:6]:
            link = item.get("link")
            if not link:
                continue

            normalized_type = resource_type
            if "youtube.com" in link.lower() or "youtu.be" in link.lower():
                # لو طلع يوتيوب من جوجل، اعتبره يوتيوب عشان الميكس يبقى منطقي
                normalized_type = "youtube"

            results.append({
                "title": item.get("title") or title,
                "url": link,
                "type": normalized_type,
                "snippet": item.get("snippet"),
                "source": item.get("source") or "Google",
                "position": item.get("position", 999),
                "thumbnail": None,
            })

        return results

    def _build_google_query(self, query: str, resource_type: str) -> str:
        if resource_type == "docs":
            return f"{query} official documentation"

        if resource_type == "course":
            return f"{query} full course OR roadmap OR tutorial"

        if resource_type in ("practice", "project"):
            return f"{query} practice exercises OR project OR hands-on"

        if resource_type == "article":
            return f"{query} guide OR article OR tutorial"

        return query

    def _rank_and_deduplicate(
        self,
        items: List[Dict[str, Any]],
        current_level: Optional[str] = None,
        target_level: Optional[str] = None,
        available_hours_per_week: Optional[int] = None,
        week_number: Optional[int] = None,
        duration_weeks: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        seen = set()
        unique_items = []

        trusted_domains = [
            "docs.python.org",
            "pandas.pydata.org",
            "numpy.org",
            "matplotlib.org",
            "seaborn.pydata.org",
            "spark.apache.org",
            "hadoop.apache.org",
            "kaggle.com",
            "coursera.org",
            "datacamp.com",
            "freecodecamp.org",
            "youtube.com",
            "youtu.be",
            "w3schools.com",
            "geeksforgeeks.org",
            "scikit-learn.org",
            "developers.google.com",
            "learn.microsoft.com",
            "codecademy.com",
            "realpython.com",
        ]

        current_level = (current_level or "").lower()
        target_level = (target_level or "").lower()
        available_hours_per_week = available_hours_per_week or 6
        week_number = week_number or 1
        duration_weeks = duration_weeks or max(week_number, 1)

        project_stage_ratio = week_number / max(duration_weeks, 1)

        def score(item: Dict[str, Any]) -> int:
            url = (item.get("url") or "").lower()
            title = (item.get("title") or "").lower()
            snippet = (item.get("snippet") or "").lower()
            item_type = (item.get("type") or "").lower()

            score_value = 0

            if any(domain in url for domain in trusted_domains):
                score_value += 12

            # type preference
            if item_type == "youtube":
                score_value += 8
            elif item_type == "docs":
                score_value += 7
            elif item_type == "practice":
                score_value += 9
            elif item_type == "project":
                score_value += 9
            elif item_type == "course":
                score_value += 6
            elif item_type == "article":
                score_value += 4

            # search rank
            position = item.get("position", 999)
            score_value += max(0, 10 - min(position, 10))

            text = f"{title} {snippet}"

            # level-awareness
            if current_level == "none":
                if "beginner" in text or "introduction" in text or "getting started" in text:
                    score_value += 8
                if "advanced" in text:
                    score_value -= 4

            elif current_level == "beginner" and target_level == "intermediate":
                if "intermediate" in text:
                    score_value += 7
                if "beginner" in text:
                    score_value += 4
                if "advanced" in text:
                    score_value -= 2

            elif current_level == "intermediate" and target_level == "advanced":
                if "advanced" in text:
                    score_value += 8
                if "intermediate" in text:
                    score_value += 4
                if "beginner" in text:
                    score_value -= 4

            # project progression: early weeks easier, late weeks harder
            easy_keywords = ["beginner", "intro", "introduction", "getting started", "basic"]
            hard_keywords = ["advanced", "real-world", "capstone", "case study", "production"]

            if project_stage_ratio <= 0.33:
                if any(k in text for k in easy_keywords):
                    score_value += 5
                if any(k in text for k in hard_keywords):
                    score_value -= 3
            elif project_stage_ratio >= 0.75:
                if any(k in text for k in hard_keywords):
                    score_value += 5

            # weekly time awareness
            if available_hours_per_week <= 5:
                if "full course" in text or "12-hour" in text or "complete masterclass" in text:
                    score_value -= 4
                if "quick" in text or "guide" in text or "exercise" in text:
                    score_value += 3
            elif available_hours_per_week >= 10:
                if "full course" in text or "project" in text or "case study" in text:
                    score_value += 3

            return score_value

        for item in sorted(items, key=score, reverse=True):
            url = item.get("url")
            if not url or url in seen:
                continue
            seen.add(url)
            unique_items.append(item)

        return unique_items