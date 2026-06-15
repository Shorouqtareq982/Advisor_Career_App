import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import HTMLResponse
import pandas as pd
import threading
import sys
import time

from shared.helpers.loggers import get_logger
from shared.helpers.crawler_helpers import init_state
from ..services.market_service import MarketInsightsService
from collections import Counter
from statistics import mean

router = APIRouter(
    prefix="/market",
    tags=["market_insights"]
)

# =========================
# LOCKS
# =========================
LOCK = threading.Lock()
JOB_LOCK = threading.Lock()
BATCH_LOCK = threading.Lock()

SCHEDULER_RUNNING = False
SCHEDULE_HOUR = 18  
SCHEDULE_MINUTE = 50
# =========================
# GLOBAL STATE
# =========================

PRIORITY_JOB = None
CANCEL_RUNNING = False
BATCH_RUNNING = False
BATCH_PAUSED = False
BATCH_PAUSE_EVENT = threading.Event()
BATCH_PAUSE_EVENT.set()
BATCH_PAUSE_ACK_EVENT = threading.Event()
BATCH_PAUSE_ACK_EVENT.set()

AUTO_RUNNING = False

CURRENT_JOB_DONE = False
CURRENT_JOB_DATA = None
CURRENT_JOB_NAME = None
CURRENT_JOB_COUNT = 0
CURRENT_JOB_ROWS = []

SCRAPING_RUNNING = False


# =========================
# JOB LIST
# =========================
JOB_LIST = [
    "Backend Development",
    "Frontend Development",
    "Full Stack Development",
    "Mobile Development",
    "Data Science & Analytics",
    "DevOps & Cloud Engineering",
    "System Architecture",
    "Network Engineering",
    "Cybersecurity",
    "Quality Assurance & Testing",
    "IT Support & Administration",
    "Research & Development",
    "Hardware Engineering",
    "IT Management & Leadership",
    "AI Engineering",
    "Machine Learning Engineering",
    "Data Engineering",
    "Business Intelligence",
    "Product Management - Tech",
    "UI/UX Design",
    "Game Development",
    "Embedded Systems & IoT",
    "AR/VR & Spatial Computing",
    "Cloud Architecture",
    "AI Research",
    "Quantitative Finance & FinTech",
    "Digital Marketing & Analytics",
    "Data Governance & Quality",
    "Automation & Scripting",
    "Robotics Engineering",
    "Game AI & Simulation",
    "Technical Writing",
    "Low-Code / No-Code Development"
]

logger = get_logger(__name__)
service = MarketInsightsService()

# =========================
# RUN AUTO
# =========================
def _run_batch_background(batch_size: int, reset: bool):
    global CANCEL_RUNNING
    global BATCH_RUNNING

    try:
        with BATCH_LOCK:
            if BATCH_RUNNING:
                logger.info("Batch already running, continuing existing background task")
            else:
                BATCH_RUNNING = True

        if reset:
            service.repo.save_state("GLOBAL", {
                "job_index": 0,
                "last_run": None
            })

        state = service.repo.load_state("GLOBAL") or {}
        start = state.get("job_index", 0)

        if start >= len(JOB_LIST):
            start = 0

        end = min(start + batch_size, len(JOB_LIST))
        jobs_batch = JOB_LIST[start:end]

        for job in jobs_batch:

            if BATCH_PAUSED:
                logger.info(f"⏸️ Batch waiting to pause before job: {job}")
                BATCH_PAUSE_ACK_EVENT.set()
                BATCH_PAUSE_EVENT.wait()
                BATCH_PAUSE_ACK_EVENT.clear()
            else:
                BATCH_PAUSE_EVENT.wait()

            if CANCEL_RUNNING:
                logger.info("⛔ RUN CANCELLED")
                break

            job_clean = job.strip().lower()

            if PRIORITY_JOB and job_clean == PRIORITY_JOB:
                logger.info(f"⛔ Skipping batch job because it is running as priority: {job}")
                continue

            sheet = job_clean[:31]

            sheet_state = service.repo.load_state(sheet) or {}
            sheet_state = init_state(sheet_state, sheet)

            existing_df = service.repo.load_jobs(sheet)
            seen_urls = set()
            seen_ids = set()

            if existing_df is not None and not existing_df.empty:
                if "job_url" in existing_df.columns:
                    seen_urls = set(existing_df["job_url"].dropna().astype(str))
                if "job_id" in existing_df.columns:
                    seen_ids = set(existing_df["job_id"].dropna().astype(str))
                service.logger.info(f"Loaded {len(seen_urls)} URLs + {len(seen_ids)} IDs from Supabase")

            wuzzuf_rows = service.fetch_wuzzuf(
                job,
                seen_urls,
                service.wuzzuf_limit,
                sheet_state,
                sheet
            ) or []

            if wuzzuf_rows:
                service.repo.save_jobs(wuzzuf_rows)
                service.logger.info("✅ WUZZUF saved to Supabase")

            if CANCEL_RUNNING:
                logger.info(f"⛔ Batch cancelled after WUZZUF for {job}")
                break

            if BATCH_PAUSED:
                logger.info(f"⏸️ Batch paused after WUZZUF for {job}")
                BATCH_PAUSE_ACK_EVENT.set()
                BATCH_PAUSE_EVENT.wait()
                BATCH_PAUSE_ACK_EVENT.clear()

            adzuna_rows = service.fetch_adzuna(
                job,
                seen_ids,
                service.adzuna_limit,
                sheet_state,
                sheet
            ) or []

            if adzuna_rows:
                service.repo.save_jobs(adzuna_rows)
                service.logger.info("✅ ADZUNA saved to Supabase")

            if CANCEL_RUNNING:
                logger.info(f"⛔ Batch cancelled after ADZUNA for {job}")
                break

            if BATCH_PAUSED:
                logger.info(f"⏸️ Batch paused after ADZUNA for {job}")
                BATCH_PAUSE_ACK_EVENT.set()
                BATCH_PAUSE_EVENT.wait()
                BATCH_PAUSE_ACK_EVENT.clear()

            service.repo.save_state(sheet, sheet_state)

            logger.info("====================")
            logger.info(f"✅ DONE: {job}")
            logger.info(f"New rows: {len(wuzzuf_rows) + len(adzuna_rows)}")
            logger.info("====================")

        state["job_index"] = end
        if state["job_index"] >= len(JOB_LIST):
            state["job_index"] = 0

        state["last_run"] = datetime.now().isoformat()
        service.repo.save_state("GLOBAL", state)

        logger.info("🎯 BATCH FINISHED")

    except Exception as e:
        logger.error(f"Background batch failed: {e}")
        raise

    finally:
        with BATCH_LOCK:
            BATCH_RUNNING = False
            CANCEL_RUNNING = False

@router.post("/run")
async def run_batch(batch_size: int = 5, reset: bool = False, async_run: bool = False, background_tasks: BackgroundTasks = None):

    global CANCEL_RUNNING
    global BATCH_RUNNING

    try:

        logger.info(f"START AUTO RUN ({batch_size}) JOBS")

        if async_run:
            with BATCH_LOCK:
                if BATCH_RUNNING:
                    return {
                        "status": "already_running",
                        "message": "A batch run is already in progress"
                    }
                BATCH_RUNNING = True

            logger.info("Starting batch run in background")
            background_tasks.add_task(_run_batch_background, batch_size, reset)

            return {
                "status": "started",
                "batch_size": batch_size,
                "message": "Batch run started in background"
            }

        if reset:
            service.repo.save_state("GLOBAL", {
                "job_index": 0,
                "last_run": None
            })

        _run_batch_background(batch_size, reset)

        return {
            "status": "completed",
            "message": f"Batch run completed for {batch_size} jobs"
        }

    except Exception as e:
        logger.error(f"Error in run_batch: {e}")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

# =========================
# RUN SINGLE JOB BACKGROUND
# =========================
def _run_single_job_background(job: str):
    global CANCEL_RUNNING
    global SCRAPING_RUNNING
    global CURRENT_JOB_NAME
    global CURRENT_JOB_ROWS
    global CURRENT_JOB_COUNT
    global CURRENT_JOB_DATA
    global CURRENT_JOB_DONE
    global BATCH_RUNNING
    global BATCH_PAUSED

    try:
        if BATCH_RUNNING:
            BATCH_PAUSED = True
            BATCH_PAUSE_EVENT.clear()
            BATCH_PAUSE_ACK_EVENT.clear()
            logger.info("⏸️ Pausing batch due to priority single job")
            if not BATCH_PAUSE_ACK_EVENT.wait(timeout=10):
                logger.warning("Batch pause acknowledgement not received before starting priority single job")

        job_clean = job.strip().lower()

        CURRENT_JOB_NAME = job_clean
        CURRENT_JOB_DONE = False
        CURRENT_JOB_ROWS = []
        CURRENT_JOB_COUNT = 0

        SCRAPING_RUNNING = True

        sheet = job_clean[:31]
        state = service.repo.load_state(sheet) or init_state({}, sheet)

        existing_df = service.repo.load_jobs(sheet)

        seen_urls = set()
        seen_ids = set()

        if existing_df is not None and not existing_df.empty:
            if "job_url" in existing_df.columns:
                seen_urls = set(existing_df["job_url"].dropna().astype(str))
            if "job_id" in existing_df.columns:
                seen_ids = set(existing_df["job_id"].dropna().astype(str))

        wuzzuf_rows = service.fetch_wuzzuf(
            job_clean,
            seen_urls,
            service.wuzzuf_limit,
            state,
            sheet
        ) or []

        CURRENT_JOB_ROWS.extend(wuzzuf_rows)
        CURRENT_JOB_COUNT = len(CURRENT_JOB_ROWS)

        if wuzzuf_rows:
            service.repo.save_jobs(wuzzuf_rows)
            logger.info(f"✅ WUZZUF SAVED: {len(wuzzuf_rows)} for {job_clean}")

        adzuna_rows = service.fetch_adzuna(
            job_clean,
            seen_ids,
            service.adzuna_limit,
            state,
            sheet
        ) or []

        CURRENT_JOB_ROWS.extend(adzuna_rows)
        CURRENT_JOB_COUNT = len(CURRENT_JOB_ROWS)

        if adzuna_rows:
            service.repo.save_jobs(adzuna_rows)
            logger.info(f"✅ ADZUNA SAVED: {len(adzuna_rows)} for {job_clean}")

        service.repo.save_state(sheet, state)

        df = pd.DataFrame(CURRENT_JOB_ROWS)

        if not df.empty:
            df = df.replace([float("inf"), float("-inf")], None).fillna("")

        CURRENT_JOB_DATA = df

        return len(df)

    except Exception as e:
        logger.error(f"❌ Single job failed: {job} - {e}")
        CURRENT_JOB_DATA = pd.DataFrame()
        return 0

    finally:
        SCRAPING_RUNNING = False
        CURRENT_JOB_DONE = True

        if BATCH_PAUSED:
            BATCH_PAUSED = False
            BATCH_PAUSE_EVENT.set()
            logger.info("▶️ Resuming batch after priority single job")

        global PRIORITY_JOB
        PRIORITY_JOB = None

# =========================
# RUN SINGLE JOB
# =========================
@router.post("/run-job")
async def run_single_job(job: str, background_tasks: BackgroundTasks = None):

    global CURRENT_JOB_NAME
    global CURRENT_JOB_DONE
    global PRIORITY_JOB
    global BATCH_PAUSED

    try:

        job_clean = job.strip().lower()
        PRIORITY_JOB = job_clean
        BATCH_PAUSED = True
        BATCH_PAUSE_EVENT.clear()

        CURRENT_JOB_NAME = job_clean
        CURRENT_JOB_DONE = False

        if background_tasks:
            background_tasks.add_task(_run_single_job_background, job)
            return {
                "status": "running",
                "job": job_clean
            }

        result = _run_single_job_background(job)

        return {
            "status": "completed",
            "job": job_clean,
            "rows": result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# =========================
# STATUS
# =========================
@router.get("/status")
async def get_status():

    state = service.repo.load_state("GLOBAL") or {}

    return {
        "job_index": state.get("job_index", 0),
        "last_run": state.get("last_run"),
        "total_jobs": len(JOB_LIST),
        "scraping_running": SCRAPING_RUNNING,
        "batch_running": BATCH_RUNNING
    }

# =========================
# JOB STATUS
# =========================
@router.get("/job-status")
async def job_status():

    global CURRENT_JOB_NAME
    global SCRAPING_RUNNING
    global CURRENT_JOB_DONE
    global CURRENT_JOB_COUNT

    sheet = (CURRENT_JOB_NAME or "").lower()[:31]

    db_count = service.repo.get_jobs_count(sheet) if sheet else 0

    # أثناء التشغيل اعرض اللايف كاونت
    live_count = max(db_count, CURRENT_JOB_COUNT)

    return {
        "job": CURRENT_JOB_NAME or "",
        "done": CURRENT_JOB_DONE,
        "loading": SCRAPING_RUNNING,
        "rows": live_count
    }

# =========================
# RESET SYSTEM
# =========================
@router.post("/reset")
async def reset_system():

    global CANCEL_RUNNING
    global PRIORITY_JOB
    global AUTO_RUNNING

    CANCEL_RUNNING = True

    PRIORITY_JOB = None
    AUTO_RUNNING = True

    service.repo.save_state("GLOBAL", {
        "job_index": 0,
        "last_run": None
    })

    CANCEL_RUNNING = False

    return {
        "message": "System reset completed"
    }

# =========================
# RESET JOB
# =========================
@router.post("/reset-job")
async def reset_job(job: str):

    global PRIORITY_JOB
    global CURRENT_JOB_NAME
    global CURRENT_JOB_DONE

    job_clean = job.strip().lower()

    PRIORITY_JOB = job_clean
    CURRENT_JOB_NAME = job_clean
    CURRENT_JOB_DONE = False

    service.repo.save_state(job_clean[:31], {})

    return {
        "status": "restarted",
        "job": job_clean
    }

# =========================
# JOBS LIST
# =========================
@router.get("/jobs")
async def get_jobs():
    return {
        "jobs": JOB_LIST
    }

# =========================================
# MARKET ANALYTICS (FIXED SALARY + EXPERIENCE_LEVEL)
# =========================================
@router.get("/market")
async def market_analytics(job: str):

    try:
        sheet = job.strip().lower()[:31]

        df = service.repo.load_jobs(sheet)

        if df is None or df.empty:
            return {
                "status": "empty",
                "job": job,
                "total_jobs": 0,
                "salary": {},
                "top_skills": [],
                "experience_distribution": {},
                "avg_experience": 0,
                "market_growth": 0,
                "governorates": {},
                "monthly_demand": {}
            }

        df = df.copy()

        # =========================
        # CLEAN SALARY DATA
        # =========================
        salary_values = []

        for col in ["salary_min", "salary_max"]:
            if col in df.columns:
                vals = pd.to_numeric(df[col], errors="coerce").dropna()
                vals = vals[vals > 0]
                salary_values.extend(vals.tolist())

        salary_data = {
            "min": int(min(salary_values)) if salary_values else 0,
            "max": int(max(salary_values)) if salary_values else 0,
            "avg": int(sum(salary_values) / len(salary_values)) if salary_values else 0
        }

        # =========================
        # TOP SKILLS
        # =========================
        skills_counter = Counter()

        if "job_skills" in df.columns:
            for row in df["job_skills"]:
                if not isinstance(row, str):
                    continue

                cleaned = (
                    row.replace("·", "|")
                       .replace("•", "|")
                       .replace("/", "|")
                       .replace(",", "|")
                )

                skills = [s.strip() for s in cleaned.split("|") if s.strip()]
                skills_counter.update(skills)

        top_skills = [
            {"skill": k, "count": v}
            for k, v in skills_counter.most_common(10)
        ]

        # =========================
        # EXPERIENCE (FROM experience_level - FIXED)
        # =========================
        exp_distribution = {
            "Entry Level": 0,
            "Junior": 0,
            "Mid Level": 0,
            "Senior": 0,
            "Expert": 0
        }

        avg_experience = 0

        if "experience_level" in df.columns:

            levels = df["experience_level"].astype(str).str.strip().str.lower()

            for lvl in levels:

                if lvl in ["entry", "entry level", "intern", "trainee"]:
                    exp_distribution["Entry Level"] += 1

                elif lvl in ["junior", "jr", "junior level"]:
                    exp_distribution["Junior"] += 1

                elif lvl in ["mid", "mid level", "middle", "intermediate"]:
                    exp_distribution["Mid Level"] += 1

                elif lvl in ["senior", "sr", "senior level"]:
                    exp_distribution["Senior"] += 1

                elif lvl in ["expert", "lead", "principal", "staff", "architect"]:
                    exp_distribution["Expert"] += 1

                else:
                    # لو قيمة جديدة مش معروفة نحطها في Junior افتراضي
                    exp_distribution["Junior"] += 1

        # fallback (optional) لو العمود مش موجود
        elif {"min_experience", "max_experience"}.issubset(df.columns):

            df["min_experience"] = pd.to_numeric(df["min_experience"], errors="coerce")
            df["max_experience"] = pd.to_numeric(df["max_experience"], errors="coerce")

            valid = df.dropna(subset=["min_experience", "max_experience"])

            valid = valid[
                (valid["min_experience"] >= 0) &
                (valid["max_experience"] >= 0) &
                (valid["min_experience"] <= valid["max_experience"])
            ]

            if not valid.empty:

                avg_experience = round(
                    ((valid["min_experience"] + valid["max_experience"]) / 2).mean(),
                    2
                )

                exp_distribution = {
                    "Entry Level": len(valid[valid["max_experience"] <= 1.5]),
                    "Junior": len(valid[(valid["max_experience"] > 1.5) & (valid["max_experience"] <= 3)]),
                    "Mid Level": len(valid[(valid["max_experience"] > 3) & (valid["max_experience"] <= 5)]),
                    "Senior": len(valid[valid["max_experience"] > 5])
                }

        # =========================
        # MARKET GROWTH
        # =========================
        market_growth = 0

        if "time_posted" in df.columns:

            dates = pd.to_datetime(df["time_posted"], errors="coerce").dropna()

            if len(dates) > 1:

                monthly = (
                    dates.dt.to_period("M")
                    .astype(str)
                    .value_counts()
                    .sort_index()
                )

                if len(monthly) >= 2:
                    first = monthly.iloc[0]
                    last = monthly.iloc[-1]

                    if first != 0:
                        market_growth = round(((last - first) / first) * 100, 2)

        # =========================
        # GOVERNORATES
        # =========================
        egypt_governorates = {
            "Cairo", "Giza", "Alexandria", "Dakahlia", "Red Sea",
            "Beheira", "Fayoum", "Gharbia", "Ismailia", "Menofia",
            "Minya", "Qaliubiya", "New Valley", "Suez", "Aswan",
            "Assiut", "Beni Suef", "Port Said", "Damietta",
            "Sharkia", "South Sinai", "North Sinai", "Luxor"
        }

        governorates = {}

        if "governorate" in df.columns:

            gov = df["governorate"].astype(str).str.strip()

            gov = gov[gov.isin(egypt_governorates)]

            governorates = gov.value_counts().head(10).to_dict()

        # =========================
        # MONTHLY DEMAND
        # =========================
        monthly_demand = {}

        if "time_posted" in df.columns:

            dates = pd.to_datetime(df["time_posted"], errors="coerce").dropna()

            monthly = (
                dates.dt.to_period("M")
                .astype(str)
                .value_counts()
                .sort_index()
            )

            monthly_demand = monthly.to_dict()

        # =========================
        # RESPONSE
        # =========================
        return {
            "status": "success",
            "job": job,
            "total_jobs": len(df),

            "salary": salary_data,
            "top_skills": top_skills,

            "experience_distribution": exp_distribution,
            "avg_experience": avg_experience,

            "market_growth": market_growth,

            "governorates": governorates,
            "monthly_demand": monthly_demand
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



def _daily_scheduler():
    global SCHEDULER_RUNNING

    SCHEDULER_RUNNING = True

    logger.info("🕒 Scheduler started (24h cycle)")

    while SCHEDULER_RUNNING:

        now = datetime.now()

        # هل الوقت وصل؟
        if now.hour == SCHEDULE_HOUR and now.minute == SCHEDULE_MINUTE:

            if not BATCH_RUNNING:

                logger.info("🚀 Triggering daily batch run")

                try:
                    _run_batch_background(batch_size=5, reset=False)
                except Exception as e:
                    logger.error(f"Scheduler batch failed: {e}")

            else:
                logger.info("⏳ Batch already running, skipping today")

            # نام 60 ثانية عشان ما يكرر
            time.sleep(60)

        else:
            # check كل دقيقة
            time.sleep(60)


@router.on_event("startup")
def start_scheduler():
    thread = threading.Thread(target=_daily_scheduler, daemon=True)
    thread.start()
    logger.info("✅ Scheduler thread started on FastAPI startup")