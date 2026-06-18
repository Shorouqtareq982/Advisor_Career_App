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
    MIN_RESOURCE_SCORE = 5.0
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

        # Per service-instance circuit breaker.
        # PlanGenerationService creates this service for a generation flow, so if a
        # provider is rate-limited/unavailable once, later weeks skip it immediately.
        self.disabled_providers = set()
        self.provider_failure_reasons = {}

    # -----------------------------
    # Provider circuit breaker helpers
    # -----------------------------
    def _is_provider_enabled(self, provider: str) -> bool:
        return provider not in self.disabled_providers

    def _disable_provider(self, provider: str, reason: str) -> None:
        if provider not in self.disabled_providers:
            logger.warning(
                "Resource provider disabled for current generation | provider=%s | reason=%s",
                provider,
                reason,
            )
        self.disabled_providers.add(provider)
        self.provider_failure_reasons[provider] = reason

    def _should_disable_for_http_error(self, status_code: int) -> bool:
        return status_code in {401, 403, 408, 409, 425, 429, 500, 502, 503, 504}

    def provider_health_snapshot(self) -> Dict[str, Any]:
        return {
            "disabled_providers": sorted(self.disabled_providers),
            "failure_reasons": dict(self.provider_failure_reasons),
        }

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

    def _is_github_topics_url(self, url: str) -> bool:
        return "github.com/topics/" in (url or "").lower()

    def _is_real_youtube_url(self, url: str) -> bool:
        url = (url or "").lower()
        return "youtube.com/watch" in url or "youtu.be/" in url

    def _is_bad_resource_url(self, resource: Dict[str, Any]) -> bool:
        url = (resource.get("url") or "").strip().lower()
        r_type = (resource.get("type") or "").strip().lower()

        if not url:
            return True
        if self._is_domain_blacklisted(url):
            return True
        if self._is_github_topics_url(url):
            return True
        if r_type == "youtube" and not self._is_real_youtube_url(url):
            return True
        if url in self.GENERIC_ROOT_URLS:
            return True
        return False

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
        if not self._is_provider_enabled("youtube"):
            return {}
        if not self.youtube_api_key or not video_ids:
            return {}

        params = {
            "part": "contentDetails",
            "id": ",".join(video_ids),
            "key": self.youtube_api_key,
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(self.youtube_videos_base_url, params=params)
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code if e.response is not None else 0
            if self._should_disable_for_http_error(status_code):
                self._disable_provider("youtube", f"duration fetch HTTP {status_code}")
            logger.warning("YouTube duration fetch failed. Videos will require verified duration. reason=%s", e)
            return {}
        except Exception as e:
            # Do NOT fake video duration here. If duration cannot be verified,
            # YouTube videos will be skipped so we keep the >= 5 min quality rule.
            logger.warning("YouTube duration fetch failed. Videos will require verified duration. reason=%s", e)
            return {}

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
        if not self._is_provider_enabled("youtube"):
            return []
        if not self.youtube_api_key:
            self._disable_provider("youtube", "missing API key")
            logger.warning("YouTube API key is missing. Skipping YouTube search.")
            return []

        params = {
            "part": "snippet",
            "q": self._compress_query(query, max_words=10),
            "key": self.youtube_api_key,
            "type": "video",
            "maxResults": 10,
            "safeSearch": "strict",
            # Medium filters out most Shorts and very short clips at the API level.
            # We still verify exact duration below.
            "videoDuration": "medium",
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(self.youtube_base_url, params=params)
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code if e.response is not None else 0
            if self._should_disable_for_http_error(status_code):
                self._disable_provider("youtube", f"search HTTP {status_code}")
            logger.warning("YouTube search failed for query='%s': %s", query, e)
            return []
        except Exception as e:
            logger.warning("YouTube search failed for query='%s': %s", query, e)
            return []

        raw_items = data.get("items", []) or []
        if not raw_items:
            logger.info("YouTube returned 0 items for query='%s'", query)
            return []

        video_ids = []
        for item in raw_items:
            video_id = (((item.get("id") or {}) or {}).get("videoId"))
            if video_id:
                video_ids.append(video_id)

        durations = await self._fetch_youtube_durations(video_ids)

        min_ok, max_ok = self._ideal_youtube_duration_range(
            available_hours_per_week=available_hours_per_week,
            current_level=current_level,
            target_level=target_level,
        )

        results = []
        duration_verified = bool(durations)

        if not duration_verified:
            logger.warning(
                "YouTube returned videos but durations could not be verified. "
                "Using smart unverified-duration fallback. query='%s'",
                query,
            )

        for item in raw_items:
            snippet = item.get("snippet", {}) or {}
            video_id = (((item.get("id") or {}) or {}).get("videoId"))
            if not video_id:
                continue

            title_text = snippet.get("title", "") or title
            desc_text = snippet.get("description", "") or ""
            channel_title = snippet.get("channelTitle", "")

            if self._is_clickbait_youtube(title_text, desc_text):
                continue

            if duration_verified:
                youtube_minutes = int(durations.get(video_id) or 0)

                # Hard quality rule requested: no verified videos under 5 minutes.
                if youtube_minutes < self.MIN_YOUTUBE_MINUTES:
                    continue

                # Keep videos that are reasonable for the user's weekly hours.
                # Don't be too strict: allow up to 20 minutes above ideal max.
                if youtube_minutes > max_ok + 20:
                    continue

                duration = self._estimate_duration(
                    title_text,
                    desc_text,
                    "youtube",
                    youtube_minutes=youtube_minutes,
                )
                source_provider = "youtube_api"
            else:
                youtube_minutes = None
                duration = f"{min_ok}-{max_ok} min target (duration unverified)"
                source_provider = "youtube_api_duration_unverified"

            results.append({
                "title": title_text,
                "url": f"https://www.youtube.com/watch?v={video_id}",
                "type": "youtube",
                "snippet": desc_text,
                "channel_title": channel_title,
                "youtube_duration_minutes": youtube_minutes,
                "duration": duration,
                "query_context": query,
                "source_provider": source_provider,
                "duration_verified": duration_verified,
            })

            if not duration_verified and len(results) >= 2:
                break

        logger.info(
            "YouTube valid results | query='%s' | count=%s | duration_range=%s-%s | duration_verified=%s",
            query,
            len(results),
            min_ok,
            max_ok,
            duration_verified,
        )
        return results

    async def _search_tavily(self, query: str, resource_type: str, title: str) -> List[Dict[str, Any]]:
        if not self._is_provider_enabled("tavily"):
            return []
        if not self.tavily_api_key:
            self._disable_provider("tavily", "missing API key")
            return []

        payload = {
            "api_key": self.tavily_api_key,
            "query": self._compress_query(query, max_words=10),
            "search_depth": "advanced",
            "max_results": 6,
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.post(self.tavily_base_url, json=payload)
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code if e.response is not None else 0
            if self._should_disable_for_http_error(status_code):
                self._disable_provider("tavily", f"HTTP {status_code}")
            logger.warning("Tavily search failed for query='%s': %s", query, e)
            return []
        except Exception as e:
            logger.warning("Tavily search failed for query='%s': %s", query, e)
            return []

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
        if not self._is_provider_enabled("serpapi"):
            return []
        if not self.serpapi_api_key:
            self._disable_provider("serpapi", "missing API key")
            return []

        params = {
            "engine": "google",
            "q": self._compress_query(query, max_words=10),
            "api_key": self.serpapi_api_key,
            "num": 6,
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(self.serpapi_base_url, params=params)
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code if e.response is not None else 0
            if self._should_disable_for_http_error(status_code):
                self._disable_provider("serpapi", f"HTTP {status_code}")
            logger.warning("SerpAPI search failed for query='%s': %s", query, e)
            return []
        except Exception as e:
            logger.warning("SerpAPI search failed for query='%s': %s", query, e)
            return []

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
        if not self._is_provider_enabled("github"):
            return []
        if not self.github_token:
            self._disable_provider("github", "missing API token")
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

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(self.github_base_url, headers=headers, params=params)
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code if e.response is not None else 0
            if self._should_disable_for_http_error(status_code):
                self._disable_provider("github", f"HTTP {status_code}")
            logger.warning("GitHub search failed for query='%s': %s", query, e)
            return []
        except Exception as e:
            logger.warning("GitHub search failed for query='%s': %s", query, e)
            return []

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
    # DB retrieval fallback
    # -----------------------------
    def _get_supabase_rest_config(self) -> tuple[str, str]:
        supabase_url = (getattr(settings, "SUPABASE_URL", "") or "").rstrip("/")
        supabase_key = (
            getattr(settings, "SUPABASE_SERVICE_ROLE_KEY", "")
            or getattr(settings, "SUPABASE_ANON_KEY", "")
            or ""
        )
        return supabase_url, supabase_key

    async def _get_from_db_fallback(
        self,
        skill_id: Optional[int] = None,
        week_topic: Optional[str] = None,
        current_level: Optional[str] = None,
        target_level: Optional[str] = None,
        limit: int = 8,
        resource_type: Optional[str] = None,
        strict_level: bool = False,
    ) -> List[Dict[str, Any]]:
        """
        Retrieves previously validated dynamic resources from discovered_learning_resources.

        Fallback order should be:
        APIs -> DB retrieval -> curated/static fallback from WeeklyResourceOrchestrator.
        """
        supabase_url, supabase_key = self._get_supabase_rest_config()
        if not supabase_url or not supabase_key:
            return []

        clean_topic = self._clean_week_topic_for_matching(week_topic)
        endpoint = f"{supabase_url}/rest/v1/discovered_learning_resources"

        params: Dict[str, Any] = {
            "select": (
                "id,track_id,skill_id,plan_id,week_topic,canonical_topic,current_level,target_level,"
                "resource_type,title,url,snippet,source_provider,source_domain,"
                "estimated_duration_minutes,base_score,final_score,is_official,is_practical,was_fallback"
            ),
            "is_active": "eq.true",
            "order": "final_score.desc,updated_at.desc",
            "limit": str(limit),
        }

        if skill_id:
            params["skill_id"] = f"eq.{skill_id}"

        if clean_topic:
            params["canonical_topic"] = f"ilike.*{clean_topic.lower()}*"

        if resource_type:
            params["resource_type"] = f"eq.{resource_type}"

        normalized_target = self._normalize_level(target_level)
        if strict_level and normalized_target:
            params["target_level"] = f"eq.{normalized_target}"

        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Accept": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(endpoint, params=params, headers=headers)
                response.raise_for_status()
                rows = response.json() or []
        except Exception as e:
            logger.warning("DB fallback query failed. skill_id=%s topic=%s reason=%s", skill_id, clean_topic, e)
            return []

        formatted: List[Dict[str, Any]] = []
        for row in rows:
            url = row.get("url")
            title = row.get("title")
            if not url or not title:
                continue

            resource_type = (row.get("resource_type") or "docs").strip().lower()
            if self._is_bad_resource_url({"url": url, "type": resource_type}):
                continue
            minutes = row.get("estimated_duration_minutes")
            duration = f"{minutes} min" if minutes else self._estimate_duration(
                title,
                row.get("snippet", ""),
                resource_type,
            )

            formatted.append({
                "title": title,
                "url": url,
                "type": resource_type,
                "snippet": row.get("snippet") or "",
                "duration": duration,
                "query_context": clean_topic or row.get("canonical_topic") or row.get("week_topic") or title,
                "score": float(row.get("final_score") or row.get("base_score") or self.MIN_RESOURCE_SCORE),
                "source_provider": "db_fallback",
                "source_domain": row.get("source_domain"),
                "is_official": bool(row.get("is_official", False)),
                "is_practical": bool(row.get("is_practical", False)),
                "was_fallback": bool(row.get("was_fallback", False)),
            })

        logger.info(
            "DB fallback returned %s resources | skill_id=%s | topic=%s",
            len(formatted),
            skill_id,
            clean_topic,
        )
        return formatted

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

        if self._is_bad_resource_url(resource):
            score -= 100

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
            if self._is_real_youtube_url(url):
                score += 8
            else:
                score -= 100

            if self._is_trusted_channel(channel):
                score += 3
            if self._is_clickbait_youtube(title, snippet):
                score -= 6

            duration_verified = bool(resource.get("duration_verified", True))
            if duration_verified:
                if youtube_minutes < 6:
                    score -= 5
                score += self._youtube_duration_score(
                    minutes=youtube_minutes,
                    available_hours_per_week=available_hours_per_week,
                    current_level=current_level,
                    target_level=target_level,
                )
            else:
                # Duration unknown: keep it usable, but rank below verified videos.
                score += 0.5

            if "what is" in title.lower():
                score -= 2

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
        if not self._is_provider_enabled("llm_rerank"):
            return resources[:max_final]
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
7. Unless impossible, include at least: 1 docs/article, 1 practice, 1 project, 1 youtube.
8. YouTube must be a real youtube.com/watch or youtu.be video.
9. Reject github.com/topics pages because they are topic lists, not real projects.
10. Return JSON only.

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

    def _resource_type_counts(self, resources: List[Dict[str, Any]]) -> Dict[str, int]:
        counts = {"docs": 0, "article": 0, "youtube": 0, "practice": 0, "project": 0}
        for item in resources or []:
            r_type = (item.get("type") or "").strip().lower()
            if r_type in counts:
                counts[r_type] += 1
        return counts

    async def _fill_missing_types_from_db(
        self,
        resources: List[Dict[str, Any]],
        *,
        skill_id: Optional[int],
        week_topic: Optional[str],
        current_level: Optional[str],
        target_level: Optional[str],
        max_items: int,
    ) -> List[Dict[str, Any]]:
        """
        Fill missing weekly resource types from DB.
        Missing types are protected so sorting/slicing does not drop youtube/project.
        """
        if not skill_id:
            return [r for r in resources if not self._is_bad_resource_url(r)]

        return await self._enforce_resource_contract_from_db(
            resources,
            skill_id=skill_id,
            week_topic=week_topic,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=None,
            max_items=max_items,
        )


    def _duration_minutes_from_resource(self, resource: Dict[str, Any]) -> Optional[int]:
        raw_minutes = resource.get("estimated_duration_minutes")
        if raw_minutes is None:
            raw_minutes = resource.get("youtube_duration_minutes")

        try:
            if raw_minutes is not None:
                return int(raw_minutes)
        except Exception:
            pass

        duration_text = str(resource.get("duration") or "").lower()
        match = re.search(r"(\d+)\s*(min|mins|minute|minutes)", duration_text)
        if match:
            return int(match.group(1))

        if "hour" in duration_text:
            match = re.search(r"(\d+)\s*(hour|hours)", duration_text)
            if match:
                return int(match.group(1)) * 60

        return None

    def _resource_level_fit_score(
        self,
        resource: Dict[str, Any],
        current_level: Optional[str],
        target_level: Optional[str],
    ) -> float:
        text = f"{resource.get('title', '')} {resource.get('snippet', '')}".lower()
        detected = self._detect_difficulty(text)
        current = self._normalize_level(current_level)
        target = self._normalize_level(target_level)

        score = 0.0

        if current in {"none", "beginner"}:
            if detected == "beginner":
                score += 2.5
            elif detected == "intermediate":
                score += 1.0
            elif detected == "advanced":
                score -= 4.0

        elif current == "intermediate":
            if detected == "intermediate":
                score += 2.5
            elif detected == "advanced":
                score += 1.0
            elif detected == "beginner" and target in {"intermediate", "advanced"}:
                score -= 2.5

        elif current == "advanced":
            if detected == "advanced":
                score += 2.0
            elif detected == "beginner":
                score -= 4.0

        return score

    def _resource_time_fit_score(
        self,
        resource: Dict[str, Any],
        available_hours_per_week: Optional[int],
    ) -> float:
        minutes = self._duration_minutes_from_resource(resource)
        if minutes is None:
            return 0.0

        weekly_minutes = max(int(available_hours_per_week or 6) * 60, 60)

        # One weekly resource should not consume more than roughly 45% of user's weekly time.
        if minutes > weekly_minutes * 0.45:
            return -3.0

        if minutes <= weekly_minutes * 0.25:
            return 1.5

        return 0.5

    def _resource_memory_score(self, resource: Dict[str, Any]) -> float:
        def as_int(value: Any) -> int:
            try:
                return int(value or 0)
            except Exception:
                return 0

        selected = as_int(resource.get("times_selected"))
        validation = as_int(resource.get("times_validation_passed"))
        used = as_int(resource.get("times_used_in_final_plan"))

        score = 0.0
        score += min(selected, 10) * 0.15
        score += min(validation, 10) * 0.25
        score += min(used, 10) * 0.35
        return score

    def _db_personalized_score(
        self,
        resource: Dict[str, Any],
        *,
        week_topic: Optional[str],
        current_level: Optional[str],
        target_level: Optional[str],
        available_hours_per_week: Optional[int],
    ) -> float:
        base = float(resource.get("score") or resource.get("final_score") or resource.get("base_score") or 0)

        score = base
        score += self._resource_level_fit_score(resource, current_level, target_level)
        score += self._resource_time_fit_score(resource, available_hours_per_week)
        score += self._resource_memory_score(resource)

        r_type = (resource.get("type") or "").lower()
        url = (resource.get("url") or "").lower()
        domain = self._extract_domain(url)

        if r_type == "youtube":
            if self._is_real_youtube_url(url):
                score += 4
                minutes = self._duration_minutes_from_resource(resource)
                if minutes:
                    score += self._youtube_duration_score(
                        minutes=minutes,
                        available_hours_per_week=available_hours_per_week,
                        current_level=current_level,
                        target_level=target_level,
                    )
            else:
                score -= 100

        if r_type == "project":
            if "github.com/" in url and not self._is_github_topics_url(url):
                score += 3
            if self._is_github_topics_url(url):
                score -= 100

        if r_type == "practice":
            if domain in {"kaggle.com", "www.kaggle.com"}:
                score += 3
            if any(word in f"{resource.get('title', '')} {resource.get('snippet', '')}".lower() for word in ["exercise", "notebook", "hands-on", "practice"]):
                score += 2

        if r_type in {"docs", "article"}:
            if bool(resource.get("is_official")):
                score += 2

        clean_topic = self._clean_week_topic_for_matching(week_topic)
        if clean_topic:
            if self._is_relevant_to_topic(resource, clean_topic, None):
                score += 3
            else:
                score -= 2

        if bool(resource.get("was_fallback")):
            score -= 1

        return round(score, 3)

    async def _get_best_db_resource_of_type(
        self,
        *,
        skill_id: Optional[int],
        week_topic: Optional[str],
        current_level: Optional[str],
        target_level: Optional[str],
        wanted_type: str,
        seen_urls: Optional[set] = None,
        available_hours_per_week: Optional[int] = None,
    ) -> Optional[Dict[str, Any]]:
        if not skill_id:
            return None

        seen_urls = seen_urls or set()
        attempts = [(week_topic, wanted_type), (None, wanted_type)]

        if wanted_type == "docs":
            attempts.extend([(week_topic, "article"), (None, "article")])

        pool: List[Dict[str, Any]] = []

        for attempt_topic, attempt_type in attempts:
            candidates = await self._get_from_db_fallback(
                skill_id=skill_id,
                week_topic=attempt_topic,
                current_level=current_level,
                target_level=target_level,
                limit=15,
                resource_type=attempt_type,
                strict_level=False,
            )

            for candidate in candidates:
                url = (candidate.get("url") or "").strip().lower()
                if not url or url in seen_urls:
                    continue
                if self._is_bad_resource_url(candidate):
                    continue
                if wanted_type == "youtube" and not self._is_real_youtube_url(url):
                    continue

                candidate["source_provider"] = "db_fallback"
                candidate["personalized_db_score"] = self._db_personalized_score(
                    candidate,
                    week_topic=week_topic,
                    current_level=current_level,
                    target_level=target_level,
                    available_hours_per_week=available_hours_per_week,
                )
                pool.append(candidate)

        if not pool:
            return None

        pool.sort(key=lambda x: float(x.get("personalized_db_score") or x.get("score") or 0), reverse=True)
        best = pool[0]
        best["score"] = max(float(best.get("score") or 0), float(best.get("personalized_db_score") or 0))
        return best

    async def _enforce_resource_contract_from_db(
        self,
        resources: List[Dict[str, Any]],
        *,
        skill_id: Optional[int],
        week_topic: Optional[str],
        current_level: Optional[str],
        target_level: Optional[str],
        available_hours_per_week: Optional[int],
        max_items: int,
    ) -> List[Dict[str, Any]]:
        cleaned: List[Dict[str, Any]] = []
        seen_urls = set()

        for item in resources or []:
            url = (item.get("url") or "").strip().lower()
            if not url or url in seen_urls:
                continue
            if self._is_bad_resource_url(item):
                continue
            seen_urls.add(url)
            cleaned.append(item)

        counts = self._resource_type_counts(cleaned)

        missing: List[str] = []
        if counts["docs"] == 0 and counts["article"] == 0:
            missing.append("docs")
        if counts["practice"] == 0:
            missing.append("practice")
        if counts["project"] == 0:
            missing.append("project")
        if counts["youtube"] == 0:
            missing.append("youtube")

        for wanted_type in missing:
            candidate = await self._get_best_db_resource_of_type(
                skill_id=skill_id,
                week_topic=week_topic,
                current_level=current_level,
                target_level=target_level,
                wanted_type=wanted_type,
                seen_urls=seen_urls,
                available_hours_per_week=available_hours_per_week,
            )
            if not candidate:
                continue

            if "score" not in candidate:
                candidate["score"] = self._score_resource(
                    resource=candidate,
                    query=candidate.get("query_context") or week_topic or "",
                    current_level=current_level,
                    target_level=target_level,
                    track_name=None,
                    available_hours_per_week=available_hours_per_week,
                    week_topic=week_topic,
                )

            url = (candidate.get("url") or "").strip().lower()
            seen_urls.add(url)
            cleaned.append(candidate)

        required_order = ["docs", "practice", "project", "youtube"]
        final: List[Dict[str, Any]] = []
        used_urls = set()
        for item in cleaned:
            if item.get("source_provider") == "db_fallback":
                item["personalized_db_score"] = self._db_personalized_score(
                    item,
                    week_topic=week_topic,
                    current_level=current_level,
                    target_level=target_level,
                    available_hours_per_week=available_hours_per_week,
                )
                item["score"] = max(float(item.get("score") or 0), float(item.get("personalized_db_score") or 0))

        sorted_cleaned = sorted(
            cleaned,
            key=lambda x: float(x.get("personalized_db_score") or x.get("score") or 0),
            reverse=True,
        )

        for wanted_type in required_order:
            for item in sorted_cleaned:
                r_type = (item.get("type") or "").strip().lower()
                url = (item.get("url") or "").strip().lower()
                if not url or url in used_urls:
                    continue

                if wanted_type == "docs":
                    type_ok = r_type in {"docs", "article"}
                else:
                    type_ok = r_type == wanted_type

                if type_ok:
                    final.append(item)
                    used_urls.add(url)
                    break

        for item in sorted_cleaned:
            url = (item.get("url") or "").strip().lower()
            if url and url not in used_urls:
                final.append(item)
                used_urls.add(url)
            if len(final) >= max(max_items, self.MIN_WEEKLY_RESOURCES):
                break

        return final[:max(max_items, self.MIN_WEEKLY_RESOURCES)]


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
        skill_id: Optional[int] = None,
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
                # YouTube has lots of noise, so we try several query shapes.
                # We still keep strict duration and clickbait filtering in _search_youtube.
                youtube_extra_queries = []
                if primary_skill_name:
                    youtube_extra_queries.extend([
                        f"{primary_skill_name} tutorial",
                        f"{primary_skill_name} practical tutorial",
                        f"{primary_skill_name} full tutorial",
                        f"{primary_skill_name} examples",
                    ])
                if clean_week_topic:
                    youtube_extra_queries.extend([
                        f"{clean_week_topic} tutorial",
                        f"{clean_week_topic} python tutorial",
                        f"{clean_week_topic} data science tutorial",
                    ])

                for q in youtube_extra_queries:
                    q = self._compress_query(q, max_words=8)
                    if q and q not in retry_queries:
                        retry_queries.append(q)

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
            if self._is_bad_resource_url(item):
                continue

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

        # filter bad stuff, but never over-filter into empty results.
        # Important: short YouTube videos are always removed permanently.
        no_short_youtube = [
            item for item in deduped
            if not (
                item.get("type") == "youtube"
                and item.get("duration_verified", True) is True
                and int(item.get("youtube_duration_minutes") or 0) < self.MIN_YOUTUBE_MINUTES
            )
        ]
        deduped = no_short_youtube

        before_topic_score_filter = list(deduped)

        if clean_week_topic:
            soft_filtered = [
                item for item in deduped
                if self._is_relevant_to_topic(item, clean_week_topic, focus_skills)
            ]
            if soft_filtered:
                deduped = soft_filtered

        high_score = [r for r in deduped if float(r.get("score") or 0) >= self.MIN_RESOURCE_SCORE]
        if high_score:
            deduped = high_score
        elif before_topic_score_filter:
            deduped = before_topic_score_filter

        deduped.sort(key=lambda x: x.get("score", 0), reverse=True)

        # DB retrieval fallback:
        # 1) If APIs returned nothing, retrieve a full set from DB.
        # 2) If APIs returned partial results, fill missing resource types from DB.
        if not deduped:
            db_fallback = await self._get_from_db_fallback(
                skill_id=skill_id,
                week_topic=clean_week_topic,
                current_level=current_level,
                target_level=target_level,
                limit=max(max_per_week, 8),
            )
            if not db_fallback and skill_id:
                db_fallback = await self._get_from_db_fallback(
                    skill_id=skill_id,
                    week_topic=None,
                    current_level=current_level,
                    target_level=target_level,
                    limit=max(max_per_week, 8),
                )
            if db_fallback:
                deduped = db_fallback
        else:
            deduped = await self._fill_missing_types_from_db(
                resources=deduped,
                skill_id=skill_id,
                week_topic=clean_week_topic,
                current_level=current_level,
                target_level=target_level,
                max_items=max(max_per_week, 8),
            )

        # rerank candidates
        reranked = await self._llm_rerank_resources(
            resources=deduped,
            week_topic=clean_week_topic,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
            max_final=max(self.max_rerank_candidates, max_per_week, 8),
        )

        # ResourceSearchService returns ranked candidates only.
        # Weekly packaging / DB recovery is handled by WeeklyResourceOrchestrator.

        final_candidates = await self._enforce_resource_contract_from_db(
            reranked,
            skill_id=skill_id,
            week_topic=clean_week_topic,
            current_level=current_level,
            target_level=target_level,
            available_hours_per_week=available_hours_per_week,
            max_items=max(max_per_week, 8),
        )

        logger.info(
            "ResourceSearch final candidates | skill_id=%s | topic=%s | counts=%s",
            skill_id,
            clean_week_topic,
            self._resource_type_counts(final_candidates),
        )

        if self.disabled_providers:
            logger.info("Resource provider health | %s", self.provider_health_snapshot())

        return final_candidates[:max(max_per_week, 8)]
