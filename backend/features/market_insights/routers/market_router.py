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


# =========================
# DASHBOARD
# =========================
@router.get("/dashboard", response_class=HTMLResponse)
def dashboard(job: str):

    job_clean = job.strip().lower()

    global PRIORITY_JOB, AUTO_RUNNING
    global CURRENT_JOB_NAME, CURRENT_JOB_DONE
    global SCRAPING_RUNNING, BATCH_PAUSED, BATCH_PAUSE_EVENT

    should_start_thread = not SCRAPING_RUNNING or CURRENT_JOB_NAME != job_clean

    # =========================
    # START JOB
    # =========================
    PRIORITY_JOB = job_clean
    AUTO_RUNNING = False
    CURRENT_JOB_NAME = job_clean
    CURRENT_JOB_DONE = False
    BATCH_PAUSED = True
    BATCH_PAUSE_EVENT.clear()

    # =========================
    # START THREAD SAFELY
    # =========================
    import threading

    if should_start_thread:
        threading.Thread(
            target=_run_single_job_background,
            args=(job_clean,),
            daemon=True
        ).start()

    return f"""
    <html>

    <head>

        <title>Dashboard</title>

        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

        <style>

            * {{
                margin:0;
                padding:0;
                box-sizing:border-box;
            }}

            body {{
                background:#0f172a;
                color:white;
                font-family:Arial;
                text-align:center;
                padding:30px;
            }}

            h1 {{
                margin-bottom:10px;
            }}

            h3 {{
                color:#cbd5e1;
                margin-bottom:20px;
            }}

            button {{
                padding:10px 20px;
                border:none;
                border-radius:8px;
                background:#22c55e;
                color:white;
                cursor:pointer;
                margin:5px;
                transition:0.2s;
            }}

            button:hover {{
                opacity:0.9;
            }}

            #count {{
                margin-top:25px;
                font-size:32px;
                color:#22c55e;
            }}

            .popup {{
                display:none;
                position:fixed;
                top:0;
                left:0;
                width:100%;
                height:100%;
                background:rgba(0,0,0,0.7);
                justify-content:center;
                align-items:center;
                z-index:999;
            }}

            .box {{
                background:#1e293b;
                padding:30px;
                border-radius:12px;
                min-width:320px;
                box-shadow:0 0 20px rgba(0,0,0,0.4);
            }}

            .loader {{
                width:50px;
                height:50px;
                border:5px solid #334155;
                border-top:5px solid #22c55e;
                border-radius:50%;
                margin:auto;
                animation: spin 1s linear infinite;
            }}

            #status {{
                margin-top:20px;
                color:#cbd5e1;
            }}

            canvas {{
                margin-top:30px;
                max-width:900px;
                max-height:400px;
            }}

            @keyframes spin {{
                100% {{
                    transform:rotate(360deg);
                }}
            }}

        </style>

    </head>

    <body>

        <h1>📊 Dashboard</h1>

        <h3>{job}</h3>

        <button onclick="goHome()">
            Change
        </button>

        <button onclick="resetJob()">
            Reset
        </button>

        <h2 id="count">0 jobs</h2>

        <canvas id="chart"></canvas>

        <div class="popup" id="popup">

            <div class="box">

                <div class="loader"></div>

                <p id="status">
                    Loading...
                </p>

            </div>

        </div>

        <script>

            const job = "{job_clean}";

            const popup =
                document.getElementById("popup");

            popup.style.display = "flex";

            // =========================
            // GO HOME
            // =========================
            function goHome() {{

                window.location.href =
                    "/api/v1/market/";
            }}

            // =========================
            // RESET JOB
            // =========================
            function resetJob() {{

                fetch(
                    "/api/v1/market/reset-job?job="
                    + encodeURIComponent(job),
                    {{
                        method: "POST"
                    }}
                )
                .then(() => location.reload());
            }}

            // =========================
            // CHART
            // =========================
            const ctx =
                document.getElementById("chart");

            const chart = new Chart(ctx, {{

                type: "line",

                data: {{

                    labels: [],

                    datasets: [{{
                        label: "Jobs Found",
                        data: [],
                        borderColor: "#22c55e",
                        backgroundColor: "rgba(34,197,94,0.2)",
                        tension: 0.3
                    }}]
                }},

                options: {{

                    responsive: true,

                    scales: {{

                        y: {{
                            beginAtZero: true
                        }}
                    }}
                }}
            }});

            let tick = 0;

            // =========================
            // CHECK STATUS
            // =========================
            async function check() {{

                try {{

                    const res = await fetch(
                        "/api/v1/market/job-status?job="
                        + encodeURIComponent(job)
                    );

                    const data =
                        await res.json();

                    // =========================
                    // UPDATE COUNT
                    // =========================
                    document.getElementById(
                        "count"
                    ).innerText =
                        data.rows + " jobs";

                    // =========================
                    // UPDATE STATUS
                    // =========================
                    document.getElementById(
                        "status"
                    ).innerText =
                        "Loading... "
                        + data.rows
                        + " jobs found";

                    // =========================
                    // UPDATE CHART
                    // =========================
                    tick++;

                    chart.data.labels.push(tick);

                    chart.data.datasets[0].data.push(
                        data.rows
                    );

                    // prevent huge arrays
                    if(chart.data.labels.length > 20) {{

                        chart.data.labels.shift();

                        chart.data.datasets[0]
                        .data
                        .shift();
                    }}

                    chart.update();

                    // =========================
                    // LOADING POPUP
                    // =========================
                    if (data.done) {{

                        popup.style.display =
                            "none";

                        document.getElementById(
                            "status"
                        ).innerText =
                            "Completed";

                    }} else {{

                        popup.style.display =
                            "flex";
                    }}

                }}

                catch (err) {{

                    console.log(err);

                    document.getElementById(
                        "status"
                    ).innerText =
                        "Connection error...";
                }}
            }}

            // =========================
            // AUTO REFRESH
            // =========================
            setInterval(check, 1500);

            check();

        </script>

    </body>

    </html>
    """

# =========================================================
# HOME PAGE
# =========================================================

@router.get("/", response_class=HTMLResponse)
async def home():
    """Home page with job search interface."""

    return f"""
    <html>

    <head>

        <title>Market Insights</title>

        <meta charset="UTF-8">

        <style>

            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }}

            body {{

                background: linear-gradient(
                    135deg,
                    #0f172a,
                    #111827,
                    #1e293b
                );

                color: white;

                font-family: Arial, sans-serif;

                min-height: 100vh;

                display: flex;
                justify-content: center;
                align-items: center;
            }}

            .container {{

                width: 90%;
                max-width: 700px;

                background: rgba(30, 41, 59, 0.85);

                padding: 40px;

                border-radius: 20px;

                box-shadow: 0 0 30px rgba(0,0,0,0.4);

                text-align: center;
            }}

            h1 {{
                font-size: 40px;
                margin-bottom: 10px;
            }}

            p {{
                color: #cbd5e1;
                margin-bottom: 30px;
            }}

            .search-box {{
                position: relative;
                width: 100%;
            }}

            input {{

                width: 100%;

                padding: 15px;

                border-radius: 12px;

                border: none;

                outline: none;

                font-size: 16px;

                background: #0f172a;

                color: white;
            }}

            input::placeholder {{
                color: #94a3b8;
            }}

            ul {{

                list-style: none;

                padding: 0;

                margin-top: 10px;

                width: 100%;

                max-height: 250px;

                overflow-y: auto;
            }}

            li {{

                padding: 12px;

                cursor: pointer;

                background: #1e293b;

                margin-top: 6px;

                border-radius: 10px;

                transition: 0.2s;
            }}

            li:hover {{
                background: #334155;
            }}

            .buttons {{
                margin-top: 25px;
            }}

            button {{

                padding: 12px 22px;

                border: none;

                border-radius: 12px;

                cursor: pointer;

                font-size: 15px;

                margin: 5px;

                transition: 0.2s;
            }}

            .search-btn {{
                background: #22c55e;
                color: white;
            }}

            .search-btn:hover {{
                background: #16a34a;
            }}

            .run-btn {{
                background: #3b82f6;
                color: white;
            }}

            .run-btn:hover {{
                background: #2563eb;
            }}

            .status-box {{

                margin-top: 25px;

                background: #0f172a;

                padding: 15px;

                border-radius: 12px;

                color: #cbd5e1;

                font-size: 14px;
            }}

            .loading {{
                color: #22c55e;
                font-weight: bold;
            }}

        </style>

    </head>

    <body>

        <div class="container">

            <h1>🔍 Market Insights</h1>

            <p>
                Search jobs and analyze market trends
            </p>

            <div class="search-box">

                <input
                    id="jobInput"
                    placeholder="Type job name..."
                    onkeyup="filterJobs(event)"
                />

                <ul id="suggestions"></ul>

            </div>

            <div class="buttons">

                <button
                    class="search-btn"
                    onclick="goDashboard()"
                >
                    Open Dashboard
                </button>

                <button
                    class="run-btn"
                    onclick="runBatch()"
                >
                    Run Batch
                </button>

            </div>

            <div class="status-box" id="statusBox">

                Ready...

            </div>

        </div>

        <script>

            const jobs = {str(JOB_LIST)};

            // =========================================
            // FILTER JOBS
            // =========================================
            function filterJobs(event) {{

                let input =
                    document.getElementById("jobInput")
                    .value
                    .toLowerCase();

                let list =
                    document.getElementById("suggestions");

                list.innerHTML = "";

                if(input.length === 0)
                    return;

                jobs
                .filter(j =>
                    j.toLowerCase().includes(input)
                )
                .slice(0, 10)
                .forEach(j => {{

                    let li =
                        document.createElement("li");

                    li.innerHTML = j;

                    li.onclick = () => {{

                        document.getElementById(
                            "jobInput"
                        ).value = j;

                        list.innerHTML = "";
                    }};

                    list.appendChild(li);
                }});
            }}

            // =========================================
            // ENTER SUPPORT
            // =========================================
            document
            .getElementById("jobInput")
            .addEventListener(
                "keydown",
                function(e) {{

                    if(e.key === "Enter") {{
                        goDashboard();
                    }}
                }}
            );

            // =========================================
            // OPEN DASHBOARD
            // =========================================
            function goDashboard() {{

                let job =
                    document.getElementById(
                        "jobInput"
                    ).value.trim();

                if(!job) {{

                    alert(
                        "Please select a job first"
                    );

                    return;
                }}

                window.location.href =
                    "/api/v1/market/dashboard?job="
                    + encodeURIComponent(job);
            }}

            // =========================================
            // RUN BATCH
            // =========================================
            async function runBatch() {{

                let statusBox =
                    document.getElementById(
                        "statusBox"
                    );

                try {{

                    statusBox.innerHTML =
                        "<span class='loading'>⚡ Running batch...</span>";

                    let response = await fetch(
                        "/api/v1/market/run?batch_size=5&async_run=true",
                        {{
                            method: "POST"
                        }}
                    );

                    let data =
                        await response.json();

                    if (data.status === "started") {{
                        statusBox.innerHTML =
                            "✅ Batch started in background. Reload the page for status later.";
                    }} else {{
                        statusBox.innerHTML = `
                            ✅ Batch Completed <br><br>

                            Rows Added:
                            <b>${{data.rows}}</b>

                            <br><br>

                            Next Index:
                            <b>${{data.next_index}}</b>

                            <br><br>

                            Jobs Processed:
                            <br>
                            ${{data.jobs_processed ? data.jobs_processed.join("<br>") : "N/A"}}
                        `;
                    }}

                    console.log(data);

                }}

                catch(error) {{

                    console.log(error);

                    statusBox.innerHTML =
                        "❌ Error running batch";
                }}
            }}

        </script>

    </body>

    </html>
    """