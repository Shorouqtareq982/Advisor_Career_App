"""
GROWZA Career Advisor - FastAPI Application Entry Point
"""
import sys
from pathlib import Path
from contextlib import asynccontextmanager
import uvicorn
import webbrowser
from threading import Timer
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ------------------------------------------------------------
# 1. Add backend folder to Python path (so imports work)
# ------------------------------------------------------------
backend_dir = Path(__file__).parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

# ------------------------------------------------------------
# 2. Import settings and Supabase
# ------------------------------------------------------------
from shared.helpers.supabase_auth_middleware import SupabaseAuthMiddleware
from core.config import settings
from shared.providers import supabase_client, db
from shared.providers.storage.cloudinary_provider import configure_cloudinary


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("\n" + "=" * 60)
    print("🚀 Starting GROWZA Career Advisor API...")
    print("=" * 60)
    sys.stdout.flush()

    if supabase_client.test_connection():
        print("✅ Supabase connected successfully")
    else:
        print("⚠️ Supabase connection failed – check .env")

    configure_cloudinary()
    print("✅ Cloudinary configured")
    sys.stdout.flush()

    yield

    print("\n🛑 Shutting down...\n")
    sys.stdout.flush()


def create_application() -> FastAPI:
    app = FastAPI(
        title=settings.PROJECT_NAME,
        description="AI-Powered Career Advisor Platform",
        version=settings.VERSION,
        openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
        docs_url=f"{settings.API_V1_PREFIX}/docs",
        redoc_url=f"{settings.API_V1_PREFIX}/redoc",
        lifespan=lifespan,
    )

    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Auth middleware
    app.add_middleware(SupabaseAuthMiddleware)

    # ------------------------------------------------------------
    # Basic endpoints
    # ------------------------------------------------------------
    @app.get("/", tags=["Root"])
    async def root():
        return {
            "message": "GROWZA Career Advisor API",
            "version": settings.VERSION,
            "docs": f"{settings.API_V1_PREFIX}/docs"
        }

    @app.get("/health", tags=["Health"])
    async def health_check():
        db_status = supabase_client.test_connection()
        return {
            "status": "healthy" if db_status else "degraded",
            "version": settings.VERSION,
            "database": "connected" if db_status else "disconnected"
        }

    @app.get("/profiles", tags=["Test"])
    async def get_profiles(limit: int = 10):
        profiles = db.read("profiles", limit=limit)
        return {
            "success": True,
            "count": len(profiles),
            "profiles": profiles
        }

    # ------------------------------------------------------------
    # Routers
    # ------------------------------------------------------------
    from app.api.router import api_router
    from features.career_builder.routers.career_router import router as level_router
    from features.career_builder.routers.llm_health_router import router as llm_health_router
    from features.mock_interview.routers.mock_interview_router import router as mock_interview_router
    from features.market_insights.routers.market_router import router as market_router

    app.include_router(api_router, prefix=settings.API_V1_PREFIX)
    app.include_router(level_router, prefix=settings.API_V1_PREFIX)
    app.include_router(llm_health_router, prefix=settings.API_V1_PREFIX)
    app.include_router(mock_interview_router, prefix=settings.API_V1_PREFIX)
    app.include_router(market_router, prefix=settings.API_V1_PREFIX)

    return app


app = create_application()


if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("📡 Available Routes:")
    print("=" * 60)
    print("🏠 Home (Market Insights): http://localhost:8000/api/v1/market/")
    print("📊 Dashboard: http://localhost:8000/api/v1/market/dashboard?job=<job_name>")
    print("📖 API Docs: http://localhost:8000/api/v1/docs")
    print("=" * 60 + "\n")
    sys.stdout.flush()

    def open_browser():
        webbrowser.open("http://localhost:8000/api/v1/market/")

    Timer(1.5, open_browser).start()

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)