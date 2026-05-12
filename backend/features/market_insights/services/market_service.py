import logging
import requests
from bs4 import BeautifulSoup
import pandas as pd
import time
import os
import re
import json
import sys
from datetime import datetime, timedelta
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from threading import Lock
from typing import List, Dict, Set, Optional, Any, Tuple
from core.config import settings
from shared.helpers.loggers import get_logger
from shared.helpers.crawler_helpers import (
    normalize_date, extract_experience, get_experience_level,
    extract_governorate, normalize_governorate, init_state
)
from ..repositories.market_repository import MarketInsightsRepository


class MarketInsightsService:
    def __init__(self):
        self.logger = get_logger(__name__)
        self.repo = MarketInsightsRepository()
        self.headers = {"User-Agent": "Mozilla/5.0"}
        self.countries = ["gb", "us", "ca", "au", "de", "fr", "nl", "pl"]
        self.api_keys = settings.API_KEYS if settings.API_KEYS else [
            {"app_id": "982a7605", "app_key": "e32b481b7bdfec606882aa277da6dae0"},
            {"app_id": "ce3acf76", "app_key": "dfa8410abf621c7dfc3886333b2d6b4c"},
            {"app_id": "dd2a584f", "app_key": "68598106fa564a2be0dee0b9c751b154"},
            {"app_id": "bb3cc508", "app_key": "e5f863e22b59f6d9e8d4b981249e9a5b"},
            {"app_id": "62d866e2", "app_key": "e285fb980b776a0d9f71f3e9537e6a10"},
            {"app_id": "32b5eae7", "app_key": "7658511478e53a7ebaf8cb80024530ea"},
            {"app_id": "30bddffb", "app_key": "f39a4a37842279292f3c5c462d06c121"},
            {"app_id": "64b84881", "app_key": "3a47910b650649f4a9f1b8ab20c45ec1"},
            {"app_id": "9d91b03a", "app_key": "20dfa40d2c6d9a8db6a779c0167b39c0"}
        ]
        self.wuzzuf_limit = 10
        self.adzuna_limit = 10

    def fetch_wuzzuf(self, job: str, seen_urls: Set[str], limit: int, state: Dict[str, Any], sheet: str) -> List[Dict[str, Any]]:
        rows = []

        if sheet not in state:
            state[sheet] = {}

        state = init_state(state, sheet)

        # STATE
        saved_page = state[sheet]["wuzzuf"].get("page", 0)
        current_page = state[sheet]["wuzzuf"].get("current_page", saved_page)
        last_good_page = state[sheet]["wuzzuf"].get("last_good_page", saved_page)

        self.logger.info(f"\n🟡 WUZZUF START | Sheet: {sheet}")

        total_added = 0
        empty_streak = 0

        # 🔥 NEW SAFETY CONTROL
        reset_count = 0
        MAX_RESETS = 3

        # EXTRACT FUNCTION
        def extract_card(c):
            try:
                a_tag = c.find("h2")
                if not a_tag or not a_tag.find("a"):
                    return None

                a = a_tag.find("a")
                title = a.get_text(strip=True)
                job_url = "https://wuzzuf.net" + a.get("href", "")

                if job_url in seen_urls:
                    return None

                loc = c.find("span", class_="css-16x61xq")
                governorate = normalize_governorate(
                    extract_governorate(loc.get_text(strip=True)) if loc else ""
                )

                exp_container = c.find("div", class_="css-1rhj4yg")
                raw_exp = exp_container.get_text(" | ", strip=True) if exp_container else ""

                mn, mx, avg = extract_experience(raw_exp)
                if mn is None:
                    return None

                time_tag = c.find("div", class_="css-eg55jf") or c.find("div", class_="css-1jldrig")
                time_posted = normalize_date(time_tag.get_text(strip=True) if time_tag else "")

                skills_tags = c.find_all("a", class_="css-5x9pm1")
                skills = " | ".join([s.get_text(strip=True) for s in skills_tags]) if skills_tags else None

                return {
                    "job_title": title,
                    "source": "Wuzzuf",
                    "country": "EG",
                    "governorate": governorate,
                    "time_posted": time_posted,
                    "min_experience": mn,
                    "max_experience": mx,
                    "avg_experience": avg,
                    "experience_level": get_experience_level(raw_exp, avg, title),
                    "job_skills": skills,
                    "salary_min": None,
                    "salary_max": None,
                    "job_url": job_url,
                    "job_id": None,
                    "job_category": job,
                    "sheet": sheet
                }

            except:
                return None

        # PHASE 1
        self.logger.info("\n🔎 PHASE 1")

        phase1_has_data = False
        phase1_all_empty = True

        for page in [0, 1, 2]:

            if total_added >= limit:
                break

            url = f"https://wuzzuf.net/search/jobs/?a=hpb&q={job.replace(' ', '+')}&start={page}"
            r = requests.get(url, headers=self.headers, timeout=10)
            soup = BeautifulSoup(r.text, "html.parser")

            cards = soup.find_all("div", class_="css-pkv5jc")

            raw_count = len(cards)
            valid_jobs = 0

            for c in cards:
                job_data = extract_card(c)

                if job_data:
                    rows.append(job_data)
                    seen_urls.add(job_data["job_url"])
                    valid_jobs += 1
                    total_added += 1
                    self.logger.info(f"    • {job_data['job_title']} | {job_data['job_url']}")
                    sys.stdout.flush()

            self.logger.info(f"\n📄 Page {page}")
            self.logger.info(f"Raw Cards: {raw_count}")
            self.logger.info(f"🟢 Valid Jobs: {valid_jobs}")

            if valid_jobs > 0:
                phase1_has_data = True
                phase1_all_empty = False
                last_good_page = page

        # START POINT
        if phase1_all_empty:
            page = last_good_page
            self.logger.info(f"\n⏭️ PHASE1 EMPTY → Start from last_good_page: {page}")

        elif phase1_has_data:
            page = last_good_page + 1
            self.logger.info(f"\n🚀 Continue from last_good_page: {page}")

        else:
            page = current_page
            self.logger.info(f"\n⏭️ Start from current_page: {page}")

        # MAIN LOOP
        while total_added < limit:

            url = f"https://wuzzuf.net/search/jobs/?a=hpb&q={job.replace(' ', '+')}&start={page}"
            r = requests.get(url, headers=self.headers, timeout=10)
            soup = BeautifulSoup(r.text, "html.parser")

            cards = soup.find_all("div", class_="css-pkv5jc")

            raw_count = len(cards)
            valid_jobs = 0

            for c in cards:
                job_data = extract_card(c)

                if job_data:
                    rows.append(job_data)
                    seen_urls.add(job_data["job_url"])
                    valid_jobs += 1
                    total_added += 1
                    self.logger.info(f"    • {job_data['job_title']} | {job_data['job_url']}")
                    sys.stdout.flush()

            self.logger.info(f"\n📄 Page {page}")
            self.logger.info(f"Raw Cards: {raw_count}")
            self.logger.info(f"🟢 Valid Jobs: {valid_jobs}")

            if page > current_page:
                current_page = page

            if valid_jobs > 0:
                last_good_page = page
                empty_streak = 0
            else:
                empty_streak += 1

            # SAFE RESET LOGIC (FIXED)
            if empty_streak >= 3:
                reset_count += 1

                self.logger.info(f"\n🔁 RESET #{reset_count} → skip forward instead of looping")

                empty_streak = 0

                # 🔥 مهم: ما نرجعش لنفس current_page
                page = current_page + 5

                # 🚨 STOP CONDITION
                if reset_count >= MAX_RESETS:
                    self.logger.info("\n⛔ STOP WUZZUF: too many empty cycles")
                    break

                continue

            page += 1

            # safety limit
            if page > saved_page + 200:
                break

        # SAVE STATE
        state[sheet]["wuzzuf"]["page"] = current_page
        state[sheet]["wuzzuf"]["current_page"] = current_page
        state[sheet]["wuzzuf"]["last_good_page"] = last_good_page

        self.logger.info(f"\n====================\nTotal Jobs: {len(rows)}\n====================")

        return rows

    def fetch_adzuna(self, job: str, seen_ids: Set[str], limit: int, state: Dict[str, Any], sheet: str) -> List[Dict[str, Any]]:

        rows = []

        if sheet not in state:
            state[sheet] = {}

        state = init_state(state, sheet)

        saved_page = state[sheet]["adzuna"].get("page", 1)
        current_page = state[sheet]["adzuna"].get("current_page", saved_page)
        last_good_page = state[sheet]["adzuna"].get("last_good_page", saved_page)

        state[sheet].setdefault("adzuna_seen", [])
        seen_global = set(state[sheet]["adzuna_seen"])

        self.logger.info(f"\n🔵 ADZUNA START | Sheet: {sheet}")

        total_added = 0
        empty_streak = 0

        # NEW SAFETY CONTROL
        reset_count = 0
        MAX_RESETS = 3

        # PROCESS PAGE
        def process_page(page):

            nonlocal total_added, last_good_page

            self.logger.info(f"\n📄 Page {page}")

            page_has_data = False

            for country in self.countries:

                country_added = 0

                try:

                    self.logger.info(f"🌍 {country}")

                    key = self.api_keys[page % len(self.api_keys)]

                    url = f"https://api.adzuna.com/v1/api/jobs/{country}/search/{page}"

                    params = {
                        "app_id": key["app_id"],
                        "app_key": key["app_key"],
                        "what": job,
                        "results_per_page": 20
                    }

                    r = requests.get(
                        url,
                        params=params,
                        timeout=10
                    )

                    if r.status_code != 200:

                        self.logger.info(f"➡️ {country.upper()} | added: 0")
                        continue

                    data = r.json().get("results", [])

                    for j in data:

                        job_id = str(j.get("id"))

                        if not job_id:
                            continue

                        unique_key = f"{job_id}|{country}"

                        # SKIP DUPLICATES
                        if unique_key in seen_global:
                            continue

                        rows.append({
                            "job_title": j.get("title"),
                            "source": "Adzuna",
                            "governorate": None,
                            "country": country.upper(),
                            "time_posted": normalize_date(j.get("created")),
                            "min_experience": None,
                            "max_experience": None,
                            "avg_experience": None,
                            "experience_level": None,
                            "job_skills": None,
                            "salary_min": j.get("salary_min"),
                            "salary_max": j.get("salary_max"),
                            "job_url": j.get("redirect_url"),
                            "job_id": job_id,
                            "job_category": job,
                            "sheet": sheet
                        })
                        self.logger.info(f"      • {j.get('title')} | {j.get('redirect_url')}")
                        sys.stdout.flush()

                        seen_global.add(unique_key)

                        total_added += 1
                        country_added += 1

                        page_has_data = True

                        if total_added >= limit:
                            break

                    self.logger.info(f"➡️ {country.upper()} | added: {country_added}")

                except Exception as e:

                    self.logger.info(f"➡️ {country.upper()} | added: 0")

                    continue

            # UPDATE LAST GOOD PAGE
            if page_has_data:
                last_good_page = page

            return page_has_data

        # PHASE 1
        self.logger.info("\n🔎 PHASE 1")

        first3_empty = True

        for p in [1, 2, 3]:

            has_data = process_page(p)

            self.logger.info(f"🟢 Has Data: {has_data}")

            if has_data:
                first3_empty = False

            if total_added >= limit:
                break

        # START POINT LOGIC
        if first3_empty:

            page = last_good_page

            self.logger.info(f"\n⏭️ First 3 EMPTY → go to last_good_page: {page}")

        else:

            page = last_good_page + 1

            self.logger.info(f"\n🚀 Continue from last_good_page: {page}")

        # MAIN LOOP
        while total_added < limit:

            has_data = process_page(page)

            # UPDATE CURRENT PAGE
            if page > current_page:
                current_page = page

            # EMPTY TRACKING
            if has_data:

                empty_streak = 0

            else:

                empty_streak += 1

            # SAFE RESET LOGIC
            if empty_streak >= 3:

                reset_count += 1

                self.logger.info(f"\n🔁 RESET #{reset_count} → skip forward")

                empty_streak = 0

                # 🔥 مهم جدًا
                # متلفش حوالين نفس الصفحات
                page = current_page + 5

                # STOP CONDITION
                if reset_count >= MAX_RESETS:

                    self.logger.info("\n⛔ STOP ADZUNA: too many empty cycles")

                    break

            page += 1

            # SAFETY LIMIT
            if page > saved_page + 60:

                self.logger.info("\n⛔ STOP ADZUNA: safety limit")

                break

        # SAVE STATE
        state[sheet]["adzuna"]["page"] = current_page

        state[sheet]["adzuna"]["current_page"] = current_page

        state[sheet]["adzuna"]["last_good_page"] = last_good_page

        state[sheet]["adzuna_seen"] = list(seen_global)

        self.logger.info(f"\n====================\nADZUNA DONE | Total Jobs: {len(rows)}\n====================")

        return rows

    def run_crawler(self, job_list: List[str]) -> pd.DataFrame:
        all_rows = []

        self.logger.info(f"Running job batch: {job_list}")

        for job in job_list:

            job = job.strip().lower()
            sheet = job[:31]

            # STATE FIX (IMPORTANT)
            state = self.repo.load_state(sheet) or {}

            if sheet not in state:
                state[sheet] = {}

            state = init_state(state, sheet)

            rows = []

            # LOAD OLD DATA
            existing_df = self.repo.load_jobs(sheet)

            seen_urls = set()
            seen_ids = set()

            if existing_df is not None and not existing_df.empty:

                if "job_url" in existing_df.columns:
                    seen_urls = set(existing_df["job_url"].dropna().astype(str))

                if "job_id" in existing_df.columns:
                    seen_ids = set(existing_df["job_id"].dropna().astype(str))

                self.logger.info(f"Loaded {len(seen_urls)} URLs + {len(seen_ids)} IDs from Supabase")

            # WUZZUF
            wuzzuf_rows = self.fetch_wuzzuf(job, seen_urls, self.wuzzuf_limit, state, sheet) or []

            if wuzzuf_rows:
                self.repo.save_jobs(wuzzuf_rows)
                self.logger.info("✅ WUZZUF saved to Supabase")

            rows.extend(wuzzuf_rows)

            # ADZUNA
            adzuna_rows = self.fetch_adzuna(job, seen_ids, self.adzuna_limit, state, sheet) or []

            if adzuna_rows:
                self.repo.save_jobs(adzuna_rows)
                self.logger.info("✅ ADZUNA saved to Supabase")

            rows.extend(adzuna_rows)

            # SAVE STATE
            self.repo.save_state(sheet, state)

            all_rows.extend(rows)

            self.logger.info("====================")
            self.logger.info(f"✅ DONE: {job}")
            self.logger.info(f"New rows: {len(rows)}")
            self.logger.info("====================")

        return pd.DataFrame(all_rows)

    def run_auto(self, batch_size: int = 5) -> pd.DataFrame:
        """Run auto crawler for batch of jobs."""
        self.logger.info(f"\n🚀 AUTO RUN jobs batch_size: {batch_size} - STARTING")
        import sys
        sys.stdout.flush()  # Force flush output

        try:
            # For simplicity, run for a sample job list
            job_list = [
                "Backend Development",
                "Frontend Development",
                "Full Stack Development"
            ][:batch_size]

            self.logger.info(f"📋 Jobs to process: {job_list}")
            df = self.run_crawler(job_list)
            self.logger.info(f"✅ AUTO RUN completed: {len(df) if df is not None and not df.empty else 0} total jobs")
            return df
        except Exception as e:
            self.logger.info(f"❌ Error in run_auto: {str(e)}")
            import traceback
            traceback.print_exc()
            return pd.DataFrame()

    def run_single_job(self, job: str) -> Dict[str, Any]:
        """Run crawler for a single job."""
        self.logger.info(f"RUN SINGLE JOB: {job}")

        job = job.strip().lower()
        sheet = job[:31]

        state = self.repo.load_state(sheet) or init_state({}, sheet)

        existing_df = self.repo.load_jobs(sheet)

        seen_urls = set()
        seen_ids = set()

        if existing_df is not None and not existing_df.empty:
            if "job_url" in existing_df.columns:
                seen_urls = set(existing_df["job_url"].dropna().astype(str))
            if "job_id" in existing_df.columns:
                seen_ids = set(existing_df["job_id"].dropna().astype(str))

        # WUZZUF
        wuzzuf_rows = self.fetch_wuzzuf(job, seen_urls, self.wuzzuf_limit, state, sheet) or []

        if wuzzuf_rows:
            self.repo.save_jobs(wuzzuf_rows)
            self.logger.info(f"✅ WUZZUF SAVED: {len(wuzzuf_rows)}")

        # ADZUNA
        adzuna_rows = self.fetch_adzuna(job, seen_ids, self.adzuna_limit, state, sheet) or []

        if adzuna_rows:
            self.repo.save_jobs(adzuna_rows)
            self.logger.info(f"✅ ADZUNA SAVED: {len(adzuna_rows)}")

        # SAVE STATE
        self.repo.save_state(sheet, state)

        df = pd.DataFrame(wuzzuf_rows + adzuna_rows)

        if not df.empty:
            df = df.replace([float("inf"), float("-inf")], None).fillna("")

        return {
            "job": job,
            "total": len(df),
            "wuzzuf": len(wuzzuf_rows),
            "adzuna": len(adzuna_rows),
            "data": df.to_dict("records") if not df.empty else []
        }

    def analyze_market(self) -> Dict[str, Any]:
        """Analyze market insights from all jobs."""
        self.logger.info("\n📊 ANALYZING MARKET INSIGHTS...")

        all_jobs = []
        for job in ["Backend Development", "Frontend Development", "Full Stack Development"]:  # Sample
            jobs_df = self.repo.load_jobs(job)
            if not jobs_df.empty:
                all_jobs.extend(jobs_df.to_dict("records"))

        if not all_jobs:
            return {"error": "No jobs data available for analysis"}

        df = pd.DataFrame(all_jobs)

        insights = {
            "total_jobs": len(df),
            "jobs_by_source": df["source"].value_counts().to_dict(),
            "jobs_by_country": df["country"].value_counts().to_dict(),
            "jobs_by_experience_level": df["experience_level"].value_counts().to_dict(),
            "avg_experience_by_level": df.groupby("experience_level")["avg_experience"].mean().round(1).to_dict(),
            "salary_ranges": {
                "min": df["salary_min"].min(),
                "max": df["salary_max"].max(),
                "avg_min": df["salary_min"].mean(),
                "avg_max": df["salary_max"].mean()
            },
            "top_skills": df["job_skills"].str.split(" | ").explode().value_counts().head(10).to_dict() if "job_skills" in df.columns else {},
            "recent_jobs": len(df[df["time_posted"] >= (datetime.now() - pd.Timedelta(days=7))])
        }

        self.logger.info(f"✅ Analysis complete: {insights['total_jobs']} jobs analyzed")
        return insights
