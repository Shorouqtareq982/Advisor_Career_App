import json
import logging
import re
from collections import Counter
from typing import List, Dict, Any, Optional
from urllib.parse import urlparse

import httpx

from core.config import settings
from shared.providers.llm_models.llm_provider import create_llm_provider

logger = logging.getLogger(__name__)


class ResourceSearchService:
    MIN_YOUTUBE_MINUTES = 5
    MIN_RESOURCE_SCORE = 8.0
    MIN_WEEKLY_RESOURCES = 4  # docs + practice + project + youtube(min 1)
    MAX_SAME_DOMAIN_COUNT = 2

    TRUSTED_YOUTUBE_CHANNELS = {
        "freeCodeCamp.org", "Traversy Media", "The Net Ninja", "Programming with Mosh",
        "Web Dev Simplified", "Fireship", "Academind", "Corey Schafer",
        "Real Python", "Tech With Tim", "3Blue1Brown", "StatQuest",
        "Codebasics", "freeCodeCamp", "JavaScript Mastery"
    }

    WHITELIST_DOMAINS = {
        "developer.mozilla.org", "learn.microsoft.com", "react.dev", "web.dev",
        "freecodecamp.org", "kaggle.com", "scikit-learn.org", "docs.python.org",
        "pandas.pydata.org", "numpy.org", "matplotlib.org", "realpython.com",
        "github.com", "javascript.info", "typescriptlang.org", "postgresql.org",
        "fastapi.tiangolo.com", "docs.docker.com", "kubernetes.io", "aws.amazon.com",
        "ibm.com", "analyticsvidhya.com", "codesignal.com", "coursera.org",
        "oreilly.com", "geeksforgeeks.org", "seaborn.pydata.org"
    }

    BLACKLIST_DOMAINS = {
        "linkedin.com", "pinterest.com", "quora.com", "skillshare.com",
        "scribd.com", "slideshare.net", "medium.com", "youtube.com/user"
    }

    GENERIC_ROOT_URLS = {
        "https://github.com",
        "https://github.com/",
        "https://www.github.com",
        "https://www.github.com/",
        "https://kaggle.com",
        "https://kaggle.com/",
        "https://www.kaggle.com",
        "https://www.kaggle.com/",
    }

    CLICKBAIT_PATTERNS = [
        r"shorts?",
        r"in \d+ (seconds?|mins?|minute)",
        r"top \d+",
        r"everything in \d+ (hour|min)",
        r"\?\?\?",
        r"(shocking|amazing|incredible|mind-blowing|nobody knows)",
        r"must watch",
    ]

    DIFFICULTY_KEYWORDS = {
        "beginner": ["beginner", "basics", "fundamentals", "introduction", "getting started", "101"],
        "intermediate": ["intermediate", "practical", "real-world", "hands-on"],
        "advanced": ["advanced", "expert", "patterns", "optimization", "architecture", "production", "best practices"],
    }

    TRACK_PROFILES = {
        "data science": {
            "keywords": ["data analysis", "machine learning", "statistics", "model evaluation", "notebook", "dataset"],
            "preferred_domains": {
                "scikit-learn.org", "pandas.pydata.org", "numpy.org",
                "kaggle.com", "matplotlib.org", "realpython.com", "ibm.com", "seaborn.pydata.org"
            },
        },
        "backend": {
            "keywords": ["backend", "api", "database", "authentication", "server", "scalability"],
            "preferred_domains": {
                "docs.python.org", "learn.microsoft.com", "fastapi.tiangolo.com",
                "postgresql.org", "developer.mozilla.org"
            },
        },
        "frontend": {
            "keywords": ["frontend", "ui", "browser", "component", "state", "dom", "responsive"],
            "preferred_domains": {
                "react.dev", "developer.mozilla.org", "web.dev",
                "javascript.info", "typescriptlang.org"
            },
        },
        "full stack": {
            "keywords": ["frontend", "backend", "full stack", "architecture", "database", "api"],
            "preferred_domains": {
                "developer.mozilla.org", "github.com", "fastapi.tiangolo.com",
                "react.dev", "postgresql.org"
            },
        },
    }

    SKILL_RESOURCE_QUERY_MAP = {
        "Feature Engineering": [
            "feature engineering fundamentals tutorial data science",
            "feature engineering official documentation guide",
            "feature engineering exercises pandas sklearn practice",
            "feature engineering case study project github repo",
        ],
        "Model Evaluation & Metrics": [
            "model evaluation metrics accuracy precision recall f1 roc auc tutorial",
            "model evaluation metrics official documentation scikit learn classification metrics",
            "model evaluation metrics exercises confusion matrix precision recall practice",
            "model evaluation metrics case study cross validation hyperparameter tuning project",
        ],
        "Seaborn": [
            "seaborn fundamentals tutorial plots visualization beginner",
            "seaborn official documentation plotting tutorial",
            "seaborn exercises notebook practice data visualization",
            "seaborn visualization project github repo",
        ],
        "Python": [
            "python programming tutorial practical examples",
            "python official documentation beginner guide",
            "python beginner exercises practice",
            "python mini project github repo",
        ],
    }

    def __init__(self):
        self.youtube_api_key = getattr(settings, "YOUTUBE_API_KEY", "")
        self.serpapi_api_key = getattr(settings, "SERPAPI_API_KEY", "")
        self.tavily_api_key = getattr(settings, "TAVILY_API_KEY", "")
        self.github_token = getattr(settings, "GITHUB_TOKEN", "")

        self.youtube_base_url = "https://www.googleapis.com/youtube/v3/search"
        self.youtube_videos_base_url = "https://www.googleapis.com/youtube/v3/videos"
        self.serpapi_base_url = "https://serpapi.com/search"
        self.tavily_base_url = "https://api.tavily.com/search"
        self.github_base_url = "https://api.github.com/search/repositories"

        self.enable_llm_rerank = getattr(settings, "ENABLE_LLM_RERANK", True)
        self.max_rerank_candidates = getattr(settings, "MAX_RERANK_CANDIDATES", 10)

        try:
            self.llm = create_llm_provider()
        except Exception as e:
            logger.warning("LLM init failed inside ResourceSearchService. Continuing without LLM reranking: %s", e)
            self.llm = None

    # -----------------------------
    # Helpers
    # -----------------------------
    def _normalize_level(self, level: Optional[str]) -> str:
        level = (level or "beginner").strip().lower()
        return level if level in {"none", "beginner", "intermediate", "advanced"} else "beginner"

    def _normalize_track_name(self, track_name: Optional[str]) -> str:
        return " ".join((track_name or "").strip().lower().split())

    def _get_track_profile(self, track_name: Optional[str]) -> Dict[str, Any]:
        normalized = self._normalize_track_name(track_name)
        for key, profile in self.TRACK_PROFILES.items():
            if key in normalized:
                return profile
        return {"keywords": [], "preferred_domains": set()}

    def _extract_domain(self, url: str) -> str:
        try:
            return urlparse(url).netloc.lower()
        except Exception:
            return ""

    def _is_domain_whitelisted(self, url: str) -> bool:
        domain = self._extract_domain(url)
        return any(item in domain for item in self.WHITELIST_DOMAINS)

    def _is_domain_blacklisted(self, url: str) -> bool:
        domain = self._extract_domain(url)
        return any(item in domain for item in self.BLACKLIST_DOMAINS)

    def _compress_query(self, text: str, max_words: int = 16) -> str:
        words = []
        seen = set()
        for token in re.split(r"\s+", (text or "").strip()):
            clean = token.strip()
            if not clean:
                continue
            key = clean.lower()
            if key in seen:
                continue
            seen.add(key)
            words.append(clean)
            if len(words) >= max_words:
                break
        return " ".join(words)

    def _clean_week_topic_for_matching(self, topic: Optional[str]) -> str:
        text = (topic or "").strip()
        text = re.sub(r"—\s*applied progression variant\s*\d+", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\bvariant\s*\d+\b", "", text, flags=re.IGNORECASE)
        return " ".join(text.split())

    def _get_skill_seed_queries(self, skill_name: str) -> List[str]:
        return self.SKILL_RESOURCE_QUERY_MAP.get(skill_name, [])

    def _pick_seed_query_for_type(self, seeds: List[str], resource_type: str) -> str:
        if not seeds:
            return ""
        if resource_type == "youtube":
            return seeds[0]
        if resource_type == "docs":
            return seeds[1] if len(seeds) > 1 else seeds[0]
        if resource_type == "practice":
            return seeds[2] if len(seeds) > 2 else seeds[0]
        if resource_type == "project":
            return seeds[3] if len(seeds) > 3 else seeds[-1]
        return seeds[0]

    def _is_clickbait_youtube(self, title: str, description: str) -> bool:
        text = f"{title} {description}".lower()
        return any(re.search(pattern, text, re.IGNORECASE) for pattern in self.CLICKBAIT_PATTERNS)

    def _is_trusted_channel(self, channel_title: str) -> bool:
        return channel_title in self.TRUSTED_YOUTUBE_CHANNELS

    def _detect_difficulty(self, text: str) -> str:
        text = (text or "").lower()
        for level in ("advanced", "intermediate", "beginner"):
            if any(keyword in text for keyword in self.DIFFICULTY_KEYWORDS[level]):
                return level
        return "intermediate"

    def _difficulty_penalty(self, resource_difficulty: str, current_level: str) -> int:
        current_level = self._normalize_level(current_level)
        if current_level in ("intermediate", "advanced") and resource_difficulty == "beginner":
            return -4
        if current_level == "beginner" and resource_difficulty == "advanced":
            return -2
        return 0

    def _semantic_distance(self, text1: str, text2: str) -> float:
        words1 = set((text1 or "").lower().split())
        words2 = set((text2 or "").lower().split())
        if not words1 or not words2:
            return 0.0
        intersection = len(words1 & words2)
        union = len(words1 | words2)
        return intersection / union if union > 0 else 0.0

    def _is_relevant_to_topic(self, resource: Dict[str, Any], topic: str, focus_skills: Optional[List[str]] = None) -> bool:
        text = f"{resource.get('title', '')} {resource.get('snippet', '')}".lower()
        topic_words = [w for w in re.findall(r"[a-zA-Z0-9]+", topic.lower()) if len(w) > 3]
        skill_words = [w.lower() for w in (focus_skills or []) if len(w) > 2]

        must_have = False
        if skill_words:
            must_have = any(skill in text for skill in skill_words)

        if topic_words:
            hits = sum(1 for word in topic_words if word in text)
            ratio = hits / max(len(topic_words), 1)
        else:
            ratio = 1.0

        if skill_words and not must_have and ratio < 0.45:
            return False

        return ratio >= 0.30 or must_have

    def _youtube_count_for_hours(self, available_hours_per_week: Optional[int]) -> int:
        hours = available_hours_per_week or 6
        return 1 if hours <= 6 else 3

    def _parse_iso8601_duration_to_minutes(self, duration: str) -> int:
        if not duration:
            return 0
        pattern = re.compile(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?")
        match = pattern.fullmatch(duration)
        if not match:
            return 0
        hours = int(match.group(1) or 0)
        minutes = int(match.group(2) or 0)
        seconds = int(match.group(3) or 0)
        total_minutes = hours * 60 + minutes
        if seconds > 0 and total_minutes == 0:
            total_minutes += 1
        return total_minutes

    def _ideal_youtube_duration_range(
        self,
        available_hours_per_week: Optional[int],
        current_level: Optional[str],
        target_level: Optional[str],
    ) -> tuple[int, int]:
        hours = available_hours_per_week or 6
        level = self._normalize_level(target_level or current_level)
        if hours <= 3:
            return (5, 12)
        if hours <= 6:
            return (6, 20)
        if hours <= 10:
            return (8, 25)
        if hours <= 15:
            return (10, 35) if level != "advanced" else (12, 45)
        return (10, 50)

    def _youtube_duration_score(
        self,
        minutes: int,
        available_hours_per_week: Optional[int],
        current_level: Optional[str],
        target_level: Optional[str],
    ) -> float:
        if minutes < self.MIN_YOUTUBE_MINUTES:
            return -100.0

        min_ok, max_ok = self._ideal_youtube_duration_range(
            available_hours_per_week=available_hours_per_week,
            current_level=current_level,
            target_level=target_level,
        )
        if min_ok <= minutes <= max_ok:
            return 5.0
        if minutes < min_ok:
            return -2.0
        if minutes <= max_ok + 20:
            return 1.0
        return -5.0

    def _estimate_duration(
        self,
        title: str,
        snippet: str,
        resource_type: str,
        youtube_minutes: Optional[int] = None
    ) -> str:
        if resource_type == "youtube" and youtube_minutes is not None:
            return f"{youtube_minutes} min"
        if resource_type == "docs":
            return "30 min"
        if resource_type == "article":
            return "30 min"
        if resource_type == "practice":
            return "2 hours"
        if resource_type == "project":
            return "full course"
        return "30 min"

    # -----------------------------
    # Query building
    # -----------------------------
    def _enrich_query(
        self,
        query: str,
        resource_type: str,
        week_topic: Optional[str],
        current_level: Optional[str],
        target_level: Optional[str],
        context_keywords: Optional[List[str]] = None,
        skill_name: Optional[str] = None,
    ) -> str:
        primary_skill = (skill_name or "").strip()
        clean_topic = self._clean_week_topic_for_matching(week_topic)
        normalized_target = self._normalize_level(target_level or current_level) or "beginner"

        if not primary_skill:
            primary_skill = (context_keywords or [clean_topic or query or "general topic"])[0]

        if not clean_topic:
            seeds = self._get_skill_seed_queries(primary_skill)
            if seeds:
                clean_topic = self._pick_seed_query_for_type(seeds, resource_type)
            else:
                clean_topic = query or primary_skill

        clean_topic = self._compress_query(clean_topic, max_words=6)

        if resource_type == "youtube":
            final_query = f"{primary_skill} {clean_topic} {normalized_target} tutorial"
        elif resource_type == "docs":
            final_query = f"{primary_skill} {clean_topic} official documentation"
        elif resource_type == "practice":
            final_query = f"{primary_skill} {clean_topic} exercises notebook practice"
        elif resource_type == "project":
            final_query = f"{primary_skill} {clean_topic} project github repo"
        else:
            final_query = f"{primary_skill} {clean_topic}"

        return self._compress_query(final_query, max_words=10)

    def _build_retry_queries(
        self,
        query: str,
        resource_type: str,
        skill_name: Optional[str],
        week_topic: Optional[str],
    ) -> List[str]:
        retries: List[str] = []
        q1 = self._compress_query(query, max_words=10)
        if q1:
            retries.append(q1)

        clean_topic = self._clean_week_topic_for_matching(week_topic)

        if skill_name or clean_topic:
            if resource_type == "docs":
                q2 = f"{skill_name or ''} {clean_topic or ''} official documentation"
            elif resource_type == "practice":
                q2 = f"{skill_name or ''} {clean_topic or ''} exercises notebook practice"
            elif resource_type == "project":
                q2 = f"{skill_name or ''} {clean_topic or ''} project github repo"
            elif resource_type == "youtube":
                q2 = f"{skill_name or ''} {clean_topic or ''} beginner tutorial"
            else:
                q2 = f"{skill_name or ''} {clean_topic or ''}"
            q2 = self._compress_query(q2, max_words=8)
            if q2 and q2 not in retries:
                retries.append(q2)

        seeds = self._get_skill_seed_queries(skill_name or "")
        if seeds:
            seed = self._pick_seed_query_for_type(seeds, resource_type)
            seed = self._compress_query(seed, max_words=8)
            if seed and seed not in retries:
                retries.append(seed)

        if skill_name:
            broad_q = f"{skill_name} tutorial examples documentation"
            broad_q = self._compress_query(broad_q, max_words=6)
            if broad_q and broad_q not in retries:
                retries.append(broad_q)

        if clean_topic and "case" in clean_topic.lower():
            case_q = f"{skill_name or ''} case study examples"
            case_q = self._compress_query(case_q, max_words=6)
            if case_q and case_q not in retries:
                retries.append(case_q)

        return retries

    # -----------------------------
    # Search providers
    # -----------------------------
    async def _fetch_youtube_durations(self, video_ids: List[str]) -> Dict[str, int]:
        if not self.youtube_api_key or not video_ids:
            return {}

        params = {
            "part": "contentDetails",
            "id": ",".join(video_ids),
            "key": self.youtube_api_key,
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(self.youtube_videos_base_url, params=params)
            response.raise_for_status()
            data = response.json()

        duration_map = {}
        for item in data.get("items", []):
            video_id = item.get("id")
            iso_duration = ((item.get("contentDetails") or {}).get("duration") or "")
            duration_map[video_id] = self._parse_iso8601_duration_to_minutes(iso_duration)
        return duration_map

    async def _search_youtube(
        self,
        query: str,
        title: str,
        current_level: Optional[str],
        target_level: Optional[str],
        available_hours_per_week: Optional[int],
    ) -> List[Dict[str, Any]]:
        if not self.youtube_api_key:
            return []

        params = {
            "part": "snippet",
            "q": self._compress_query(query, max_words=10),
            "key": self.youtube_api_key,
            "type": "video",
            "maxResults": 10,
            "safeSearch": "strict",
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(self.youtube_base_url, params=params)
            response.raise_for_status()
            data = response.json()

        raw_items = data.get("items", [])
        video_ids = []
        for item in raw_items:
            video_id = (((item.get("id") or {}) or {}).get("videoId"))
            if video_id:
                video_ids.append(video_id)

        durations = await self._fetch_youtube_durations(video_ids)

        results = []
        for item in raw_items:
            snippet = item.get("snippet", {}) or {}
            video_id = (((item.get("id") or {}) or {}).get("videoId"))
            if not video_id:
                continue

            youtube_minutes = int(durations.get(video_id) or 0)
            if youtube_minutes < self.MIN_YOUTUBE_MINUTES:
                continue

            results.append({
                "title": snippet.get("title") or title,
                "url": f"https://www.youtube.com/watch?v={video_id}",
                "type": "youtube",
                "snippet": snippet.get("description", ""),
                "channel_title": snippet.get("channelTitle", ""),
                "youtube_duration_minutes": youtube_minutes,
                "duration": self._estimate_duration(
                    snippet.get("title", ""),
                    snippet.get("description", ""),
                    "youtube",
                    youtube_minutes=youtube_minutes
                ),
                "query_context": query,
            })

        return results

    async def _search_tavily(self, query: str, resource_type: str, title: str) -> List[Dict[str, Any]]:
        if not self.tavily_api_key:
            return []

        payload = {
            "api_key": self.tavily_api_key,
            "query": self._compress_query(query, max_words=10),
            "search_depth": "advanced",
            "max_results": 6,
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(self.tavily_base_url, json=payload)
            response.raise_for_status()
            data = response.json()

        results = []
        for item in data.get("results", []):
            url = item.get("url", "")
            if not url or self._is_domain_blacklisted(url):
                continue
            results.append({
                "title": item.get("title") or title,
                "url": url,
                "type": resource_type,
                "snippet": item.get("content", ""),
                "duration": self._estimate_duration(item.get("title", ""), item.get("content", ""), resource_type),
                "query_context": query,
            })
        return results

    async def _search_serpapi(self, query: str, resource_type: str, title: str) -> List[Dict[str, Any]]:
        if not self.serpapi_api_key:
            return []

        params = {
            "engine": "google",
            "q": self._compress_query(query, max_words=10),
            "api_key": self.serpapi_api_key,
            "num": 6,
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(self.serpapi_base_url, params=params)
            response.raise_for_status()
            data = response.json()

        results = []
        for item in data.get("organic_results", []):
            url = item.get("link", "")
            if not url or self._is_domain_blacklisted(url):
                continue
            results.append({
                "title": item.get("title") or title,
                "url": url,
                "type": resource_type,
                "snippet": item.get("snippet", ""),
                "duration": self._estimate_duration(item.get("title", ""), item.get("snippet", ""), resource_type),
                "query_context": query,
            })
        return results

    async def _search_github(self, query: str, resource_type: str, title: str) -> List[Dict[str, Any]]:
        if not self.github_token:
            return []

        headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {self.github_token}",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        params = {
            "q": f"{self._compress_query(query, max_words=8)} in:name,description stars:>50",
            "sort": "stars",
            "order": "desc",
            "per_page": 6,
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(self.github_base_url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()

        results = []
        for item in data.get("items", []):
            url = item.get("html_url", "")
            if not url or self._is_domain_blacklisted(url):
                continue

            github_type = "project" if resource_type == "project" else "practice"
            results.append({
                "title": item.get("full_name") or title,
                "url": url,
                "type": github_type,
                "snippet": item.get("description") or "",
                "duration": self._estimate_duration(item.get("full_name", ""), item.get("description", ""), github_type),
                "query_context": query,
                "stars": item.get("stargazers_count", 0),
            })
        return results

    # -----------------------------
    # Curated bank / fallback
    # -----------------------------
    async def _load_curated_resources(
        self,
        skill_name: Optional[str],
        canonical_topic: Optional[str],
        current_level: Optional[str],
        target_level: Optional[str],
    ) -> List[Dict[str, Any]]:
        # مؤقتًا static curated pack
        curated = []

        if (skill_name or "").lower() == "feature engineering":
            curated.extend([
                {
                    "title": "Feature Engineering in Machine Learning: A Practical Guide | DataCamp",
                    "url": "https://www.datacamp.com/tutorial/feature-engineering",
                    "type": "docs",
                    "snippet": "Hands-on guide to encoding, scaling, handling missing values, and creating features in Python.",
                    "duration": "30 min",
                    "query_context": canonical_topic or skill_name,
                    "score": 14.0,
                },
                {
                    "title": "Feature Engineering Data Preprocessing Exercise - Kaggle",
                    "url": "https://www.kaggle.com/code/mehmetisik/feature-engineering-data-preprocessing-exercise",
                    "type": "practice",
                    "snippet": "Notebook-style exercise covering missing values, encoding, scaling, and feature engineering workflow.",
                    "duration": "2 hours",
                    "query_context": canonical_topic or skill_name,
                    "score": 14.0,
                },
                {
                    "title": "Feature Engineering project examples on GitHub",
                    "url": "https://github.com/topics/feature-engineering",
                    "type": "project",
                    "snippet": "Curated GitHub topic page for feature engineering implementations and examples.",
                    "duration": "full course",
                    "query_context": canonical_topic or skill_name,
                    "score": 13.0,
                },
                {
                    "title": "Feature Engineering Tutorial for Beginners",
                    "url": "https://www.youtube.com/results?search_query=feature+engineering+tutorial+beginner",
                    "type": "youtube",
                    "snippet": "Curated search results for beginner-friendly feature engineering videos.",
                    "channel_title": "",
                    "youtube_duration_minutes": 10,
                    "duration": "10 min",
                    "query_context": canonical_topic or skill_name,
                    "score": 12.0,
                },
            ])

        elif (skill_name or "").lower() == "model evaluation & metrics":
            curated.extend([
                {
                    "title": "What is Model Evaluation? | IBM",
                    "url": "https://www.ibm.com/think/topics/model-evaluation",
                    "type": "docs",
                    "snippet": "Beginner-friendly overview of accuracy, precision, recall, F1 and evaluation tradeoffs.",
                    "duration": "30 min",
                    "query_context": canonical_topic or skill_name,
                    "score": 14.0,
                },
                {
                    "title": "Model evaluation exercises with scikit-learn",
                    "url": "https://amueller.github.io/aml/04-model-evaluation/10-evaluation-metrics.html",
                    "type": "practice",
                    "snippet": "Practical exercises around ROC, precision-recall, confusion matrix, and metrics.",
                    "duration": "2 hours",
                    "query_context": canonical_topic or skill_name,
                    "score": 13.0,
                },
                {
                    "title": "Machine learning evaluation project examples",
                    "url": "https://github.com/topics/model-evaluation",
                    "type": "project",
                    "snippet": "GitHub topic page with model evaluation examples and project implementations.",
                    "duration": "full course",
                    "query_context": canonical_topic or skill_name,
                    "score": 13.0,
                },
                {
                    "title": "How to evaluate ML models",
                    "url": "https://www.youtube.com/watch?v=LbX4X71-TFI",
                    "type": "youtube",
                    "snippet": "Evaluation metrics overview for machine learning.",
                    "channel_title": "AssemblyAI",
                    "youtube_duration_minutes": 10,
                    "duration": "10 min",
                    "query_context": canonical_topic or skill_name,
                    "score": 12.0,
                },
            ])

        elif (skill_name or "").lower() == "seaborn":
            curated.extend([
                {
                    "title": "Seaborn official tutorial",
                    "url": "https://seaborn.pydata.org/tutorial.html",
                    "type": "docs",
                    "snippet": "Official Seaborn tutorial for plotting, relational, categorical, and distribution charts.",
                    "duration": "30 min",
                    "query_context": canonical_topic or skill_name,
                    "score": 14.0,
                },
                {
                    "title": "Visualization exercises with Matplotlib and Seaborn",
                    "url": "https://github.com/4GeeksAcademy/visualization-exercises-with-matplot-and-seaborn",
                    "type": "practice",
                    "snippet": "Hands-on practice repo with visualization exercises.",
                    "duration": "2 hours",
                    "query_context": canonical_topic or skill_name,
                    "score": 13.0,
                },
                {
                    "title": "Seaborn project examples",
                    "url": "https://github.com/topics/seaborn",
                    "type": "project",
                    "snippet": "GitHub topic page with Seaborn-based data visualization projects.",
                    "duration": "full course",
                    "query_context": canonical_topic or skill_name,
                    "score": 13.0,
                },
                {
                    "title": "Seaborn tutorial for beginners",
                    "url": "https://www.youtube.com/results?search_query=seaborn+tutorial+beginner",
                    "type": "youtube",
                    "snippet": "Curated search results for beginner-friendly Seaborn tutorials.",
                    "channel_title": "",
                    "youtube_duration_minutes": 10,
                    "duration": "10 min",
                    "query_context": canonical_topic or skill_name,
                    "score": 12.0,
                },
            ])

        return curated

    def _get_fallback_resources(
        self,
        query: str,
        resource_type: str,
        title: str,
        track_name: Optional[str] = None,
        current_level: Optional[str] = None,
        target_level: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        profile = self._get_track_profile(track_name)
        preferred_domains = list(profile.get("preferred_domains", []))
        docs_domain = "https://scikit-learn.org/stable/user_guide.html"
        if preferred_domains:
            docs_domain = f"https://{list(preferred_domains)[0]}"

        fallback_by_type = {
            "docs": docs_domain,
            "article": docs_domain,
            "practice": "https://www.kaggle.com/",
            "project": "https://github.com/topics/machine-learning",
            "youtube": "https://www.youtube.com/results?search_query=beginner+tutorial",
        }
        fallback_url = fallback_by_type.get(resource_type, docs_domain)

        return [{
            "title": title,
            "url": fallback_url,
            "type": resource_type,
            "snippet": f"Fallback resource for: {query}",
            "duration": self._estimate_duration(title, query, resource_type),
            "query_context": query,
            "score": self.MIN_RESOURCE_SCORE,
        }]

    # -----------------------------
    # Validation
    # -----------------------------
    def _validate_week_resources(self, resources: List[Dict[str, Any]]) -> Dict[str, Any]:
        failed_rules = []

        has_reference_resource = any(r.get("type") in {"docs", "article"} for r in resources)
        has_practical_resource = any(r.get("type") in {"practice"} for r in resources)
        has_project_resource = any(r.get("type") in {"project"} for r in resources)

        has_generic_root_url = any((r.get("url") or "").strip() in self.GENERIC_ROOT_URLS for r in resources)
        has_short_video = any(
            r.get("type") == "youtube" and int(r.get("youtube_duration_minutes") or 999) < self.MIN_YOUTUBE_MINUTES
            for r in resources
        )
        has_low_score_resource = any(float(r.get("score") or 0) < self.MIN_RESOURCE_SCORE for r in resources)

        domain_counts = Counter(
            self._extract_domain(r.get("url") or "") for r in resources if r.get("url")
        )
        excessive_duplicate_domains = any(count > self.MAX_SAME_DOMAIN_COUNT for count in domain_counts.values())

        if len(resources) < self.MIN_WEEKLY_RESOURCES:
            failed_rules.append("min_resource_count")
        if not has_reference_resource:
            failed_rules.append("missing_reference_resource")
        if not has_practical_resource:
            failed_rules.append("missing_practice_resource")
        if not has_project_resource:
            failed_rules.append("missing_project_resource")
        if has_generic_root_url:
            failed_rules.append("generic_root_url")
        if has_short_video:
            failed_rules.append("short_video")
        if has_low_score_resource:
            failed_rules.append("low_score_resource")
        if excessive_duplicate_domains:
            failed_rules.append("duplicate_domains")

        return {
            "passed": len(failed_rules) == 0,
            "resource_count": len(resources),
            "failed_rules": failed_rules,
            "has_reference_resource": has_reference_resource,
            "has_practical_resource": has_practical_resource,
            "has_project_resource": has_project_resource,
            "has_generic_root_url": has_generic_root_url,
            "has_short_video": has_short_video,
            "has_low_score_resource": has_low_score_resource,
            "excessive_duplicate_domains": excessive_duplicate_domains,
        }

    def _merge_resource_sets(self, primary: List[Dict[str, Any]], secondary: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        merged = []
        seen_urls = set()

        for group in [primary, secondary]:
            for item in group:
                url = (item.get("url") or "").strip().lower()
                if not url or url in seen_urls:
                    continue
                seen_urls.add(url)
                merged.append(item)

        return merged

    # -----------------------------
    # Scoring / reranking
    # -----------------------------
    def _score_resource(
        self,
        resource: Dict[str, Any],
        query: str,
        current_level: Optional[str],
        target_level: Optional[str],
        track_name: Optional[str],
        available_hours_per_week: Optional[int],
        week_topic: Optional[str],
        focus_skills: Optional[List[str]] = None,
    ) -> float:
        title = (resource.get("title") or "").strip()
        snippet = (resource.get("snippet") or "").strip()
        url = (resource.get("url") or "").strip()
        source_type = (resource.get("type") or "article").lower()
        channel = (resource.get("channel_title") or "").strip()
        youtube_minutes = int(resource.get("youtube_duration_minutes") or 0)

        profile = self._get_track_profile(track_name)
        text = f"{title} {snippet}".lower()
        difficulty = self._detect_difficulty(text)
        score = 0.0

        if self._is_domain_blacklisted(url):
            score -= 10

        if self._is_domain_whitelisted(url):
            score += 4

        if "github.com" in self._extract_domain(url):
            stars = int(resource.get("stars") or 0)
            if stars >= 500:
                score += 3
            elif stars >= 100:
                score += 1.5

        if any(domain in self._extract_domain(url) for domain in profile.get("preferred_domains", set())):
            score += 4

        if any(keyword in text for keyword in profile.get("keywords", [])):
            score += 2

        score += self._difficulty_penalty(difficulty, current_level or "beginner")
        score += self._semantic_distance(query, f"{title} {snippet}") * 6

        clean_topic = self._clean_week_topic_for_matching(week_topic)
        if clean_topic and self._is_relevant_to_topic(resource, clean_topic, focus_skills):
            score += 4
        elif clean_topic:
            score -= 4

        if source_type == "youtube":
            if self._is_trusted_channel(channel):
                score += 3
            if self._is_clickbait_youtube(title, snippet):
                score -= 6
            if youtube_minutes < 6:
                score -= 5
            if "what is" in title.lower():
                score -= 2
            score += self._youtube_duration_score(
                minutes=youtube_minutes,
                available_hours_per_week=available_hours_per_week,
                current_level=current_level,
                target_level=target_level,
            )

        if source_type in ("docs", "practice", "project"):
            score += 1.5

        if "dev.to" in url and source_type == "project":
            score -= 5

        return round(score, 3)

    def _serialize_resources_for_rerank(self, resources: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        serialized = []
        for idx, item in enumerate(resources):
            serialized.append({
                "index": idx,
                "title": item.get("title", ""),
                "url": item.get("url", ""),
                "type": item.get("type", ""),
                "snippet": (item.get("snippet", "") or "")[:400],
                "duration": item.get("duration", ""),
                "score": item.get("score", 0),
                "youtube_duration_minutes": item.get("youtube_duration_minutes"),
            })
        return serialized

    def _safe_parse_rerank_output(self, raw: Any) -> List[int]:
        if raw is None:
            return []
        if isinstance(raw, dict):
            selected = raw.get("selected_indices", [])
            if isinstance(selected, list):
                return [int(x) for x in selected if str(x).isdigit()]
        text = str(raw).strip()
        try:
            parsed = json.loads(text)
            if isinstance(parsed, dict):
                return [int(x) for x in parsed.get("selected_indices", []) if str(x).isdigit()]
        except Exception:
            pass
        match = re.search(r"\[(.*?)\]", text, re.DOTALL)
        if match:
            nums = re.findall(r"\d+", match.group(1))
            return [int(x) for x in nums]
        return []

    async def _llm_rerank_resources(
        self,
        resources: List[Dict[str, Any]],
        week_topic: Optional[str],
        current_level: Optional[str],
        target_level: Optional[str],
        available_hours_per_week: Optional[int],
        max_final: int,
    ) -> List[Dict[str, Any]]:
        if not self.llm or not self.enable_llm_rerank or not resources:
            return resources[:max_final]

        candidates = resources[:self.max_rerank_candidates]
        serialized = self._serialize_resources_for_rerank(candidates)

        prompt = f"""
You are selecting the best weekly learning resources.

User context:
- Week topic: {week_topic or ""}
- Current level: {current_level or "beginner"}
- Target level: {target_level or "beginner"}
- Available hours: {available_hours_per_week or 6}

Rules:
1. Keep the mix balanced and useful.
2. Prefer exact topic match.
3. Prefer beginner-safe resources if level is none/beginner.
4. Reject weak or generic videos.
5. Prefer official docs for theory.
6. Prefer practice/project resources that are implementable.
7. Return JSON only.

Candidates:
{json.dumps(serialized, ensure_ascii=False, indent=2)}

Return:
{{"selected_indices": [0,1,2,3]}}
"""

        try:
            response = await self.llm.get_response(
                prompt=prompt,
                need_json_output=True,
                temperature=0.1,
            )
            indices = self._safe_parse_rerank_output(response)
            if not indices:
                return resources[:max_final]

            final = []
            seen = set()
            for idx in indices:
                if 0 <= idx < len(candidates) and idx not in seen:
                    final.append(candidates[idx])
                    seen.add(idx)
                if len(final) >= max_final:
                    break

            if len(final) < min(2, len(candidates)):
                return resources[:max_final]

            return final
        except Exception as e:
            logger.warning("LLM reranking failed. Reason: %s", e)
            return resources[:max_final]

    # -----------------------------
    # Week packaging
    # -----------------------------
    def _pick_best_of_type(self, resources: List[Dict[str, Any]], resource_type: str, count: int = 1) -> List[Dict[str, Any]]:
        candidates = [r for r in resources if r.get("type") == resource_type]
        return candidates[:count]

    def _build_week_package(
        self,
        ranked_resources: List[Dict[str, Any]],
        available_hours_per_week: Optional[int],
    ) -> List[Dict[str, Any]]:
        youtube_needed = self._youtube_count_for_hours(available_hours_per_week)

        final = []
        final.extend(self._pick_best_of_type(ranked_resources, "docs", 1))
        if not any(r.get("type") == "docs" for r in final):
            final.extend(self._pick_best_of_type(ranked_resources, "article", 1))

        final.extend(self._pick_best_of_type(
            [r for r in ranked_resources if r not in final],
            "practice",
            1
        ))

        final.extend(self._pick_best_of_type(
            [r for r in ranked_resources if r not in final],
            "project",
            1
        ))

        final.extend(self._pick_best_of_type(
            [r for r in ranked_resources if r not in final],
            "youtube",
            youtube_needed
        ))

        return final

    # -----------------------------
    # Main
    # -----------------------------
    async def search_resources(
        self,
        resource_queries: List[Dict[str, Any]],
        max_per_week: int = 5,
        current_level: Optional[str] = None,
        target_level: Optional[str] = None,
        available_hours_per_week: Optional[int] = None,
        week_number: Optional[int] = None,
        duration_weeks: Optional[int] = None,
        context_keywords: Optional[List[str]] = None,
        track_name: Optional[str] = None,
        week_topic: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        focus_skills = context_keywords or []
        primary_skill_name = focus_skills[0] if focus_skills else None
        clean_week_topic = self._clean_week_topic_for_matching(week_topic)

        youtube_results: List[Dict[str, Any]] = []
        non_youtube_results: List[Dict[str, Any]] = []

        for item in resource_queries or []:
            original_query = (item.get("query") or "").strip()
            resource_type = (item.get("type") or "article").strip().lower()
            title = (item.get("title") or original_query or "Learning Resource").strip()

            if not original_query:
                continue

            query = self._enrich_query(
                query=original_query,
                resource_type=resource_type,
                week_topic=clean_week_topic,
                current_level=current_level,
                target_level=target_level,
                context_keywords=context_keywords,
                skill_name=primary_skill_name,
            )

            retry_queries = self._build_retry_queries(
                query=query,
                resource_type=resource_type,
                skill_name=primary_skill_name,
                week_topic=clean_week_topic,
            )

            if resource_type == "youtube":
                for retry_query in retry_queries:
                    try:
                        yt = await self._search_youtube(
                            query=retry_query,
                            title=title,
                            current_level=current_level,
                            target_level=target_level,
                            available_hours_per_week=available_hours_per_week,
                        )
                        if yt:
                            youtube_results.extend(yt)
                            break
                    except Exception as e:
                        logger.warning("YouTube retry failed for query '%s': %s", retry_query, e)
                continue

            got_results = False
            for retry_query in retry_queries:
                try:
                    tavily_results = await self._search_tavily(retry_query, resource_type, title)
                    if tavily_results:
                        non_youtube_results.extend(tavily_results)
                        got_results = True
                        break
                except Exception as e:
                    logger.warning("Tavily retry failed for query '%s': %s", retry_query, e)

                try:
                    serp_results = await self._search_serpapi(retry_query, resource_type, title)
                    if serp_results:
                        non_youtube_results.extend(serp_results)
                        got_results = True
                        break
                except Exception as e:
                    logger.warning("SerpAPI retry failed for query '%s': %s", retry_query, e)

                if resource_type in {"project", "practice"}:
                    try:
                        gh_results = await self._search_github(retry_query, resource_type, title)
                        if gh_results:
                            non_youtube_results.extend(gh_results)
                            got_results = True
                            break
                    except Exception as e:
                        logger.warning("GitHub retry failed for query '%s': %s", retry_query, e)

            if not got_results:
                non_youtube_results.extend(
                    self._get_fallback_resources(
                        query=query,
                        resource_type=resource_type,
                        title=title,
                        track_name=track_name,
                        current_level=current_level,
                        target_level=target_level,
                    )
                )

        all_results = youtube_results + non_youtube_results

        # dedupe
        deduped = []
        seen = set()
        for item in all_results:
            key = (
                (item.get("url") or "").strip().lower(),
                (item.get("title") or "").strip().lower()
            )
            if key in seen:
                continue
            seen.add(key)
            item["score"] = self._score_resource(
                resource=item,
                query=item.get("query_context") or "",
                current_level=current_level,
                target_level=target_level,
                track_name=track_name,
                available_hours_per_week=available_hours_per_week,
                week_topic=clean_week_topic,
                focus_skills=focus_skills,
            )
            deduped.append(item)

        # filter bad stuff
        deduped = [
            item for item in deduped
            if not (
                item.get("type") == "youtube" and int(item.get("youtube_duration_minutes") or 0) < self.MIN_YOUTUBE_MINUTES
            )
        ]

        if clean_week_topic:
            deduped = [
                item for item in deduped
                if self._is_relevant_to_topic(item, clean_week_topic, focus_skills)
            ]

        deduped = [r for r in deduped if float(r.get("score") or 0) >= self.MIN_RESOURCE_SCORE]
        deduped.sort(key=lambda x: x.get("score", 0), reverse=True)

        # rerank candidates
        reranked = await self._llm_rerank_resources(
            resources=deduped,
            week_topic=clean_week_topic,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
            max_final=max(self.max_rerank_candidates, 8),
        )

        # fixed structure package
        packaged = self._build_week_package(
            ranked_resources=reranked,
            available_hours_per_week=available_hours_per_week,
        )

        validation = self._validate_week_resources(packaged)
        if validation["passed"]:
            return packaged

        logger.warning("Week validation failed. Rules=%s", validation["failed_rules"])

        # Retry by merging curated bank
        curated = await self._load_curated_resources(
            skill_name=primary_skill_name,
            canonical_topic=clean_week_topic,
            current_level=current_level,
            target_level=target_level,
        )

        merged = self._merge_resource_sets(packaged, curated)

        # rescore merged if some curated items have no score
        rescored = []
        for item in merged:
            if "score" not in item:
                item["score"] = self._score_resource(
                    resource=item,
                    query=item.get("query_context") or clean_week_topic or "",
                    current_level=current_level,
                    target_level=target_level,
                    track_name=track_name,
                    available_hours_per_week=available_hours_per_week,
                    week_topic=clean_week_topic,
                    focus_skills=focus_skills,
                )
            rescored.append(item)

        rescored.sort(key=lambda x: x.get("score", 0), reverse=True)

        packaged_2 = self._build_week_package(
            ranked_resources=rescored,
            available_hours_per_week=available_hours_per_week,
        )

        validation_2 = self._validate_week_resources(packaged_2)
        if validation_2["passed"]:
            return packaged_2

        # force-fill by type
        final = list(packaged_2)

        def add_if_missing(resource_type: str, count: int = 1):
            existing_count = sum(1 for r in final if r.get("type") == resource_type)
            needed = max(0, count - existing_count)
            if needed == 0:
                return

            pool = [r for r in rescored if r not in final and r.get("type") == resource_type]
            for item in pool[:needed]:
                final.append(item)

            while sum(1 for r in final if r.get("type") == resource_type) < count:
                fallback_item = self._get_fallback_resources(
                    query=clean_week_topic or "learning resource",
                    resource_type=resource_type,
                    title=f"{clean_week_topic or 'Weekly Topic'} {resource_type}",
                    track_name=track_name,
                    current_level=current_level,
                    target_level=target_level,
                )[0]
                if all((fallback_item.get("url") or "") != (x.get("url") or "") for x in final):
                    final.append(fallback_item)
                else:
                    break

        add_if_missing("docs", 1)
        add_if_missing("practice", 1)
        add_if_missing("project", 1)
        add_if_missing("youtube", self._youtube_count_for_hours(available_hours_per_week))

        # last cleanup
        cleaned_final = []
        seen_urls = set()
        for item in final:
            url = (item.get("url") or "").strip().lower()
            if not url or url in seen_urls:
                continue
            if url in {u.lower() for u in self.GENERIC_ROOT_URLS}:
                continue
            seen_urls.add(url)
            cleaned_final.append(item)

        # make sure structure still holds after cleanup
        if len(cleaned_final) < self.MIN_WEEKLY_RESOURCES:
            for item in rescored:
                url = (item.get("url") or "").strip().lower()
                if not url or url in seen_urls:
                    continue
                cleaned_final.append(item)
                seen_urls.add(url)
                if len(cleaned_final) >= self.MIN_WEEKLY_RESOURCES:
                    break

        return cleaned_final[:max(4, 3 + self._youtube_count_for_hours(available_hours_per_week))]