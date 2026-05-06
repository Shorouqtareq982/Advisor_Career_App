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
    """Lifespan events with Supabase connection test."""
    print(" Starting up GROWZA Career Advisor API...")
    if supabase_client.test_connection():
        print(" Supabase connected successfully")
    else:
        print(" Supabase connection failed – check .env")

    configure_cloudinary()  # Ensure Cloudinary is configured at startup
    yield
    print(" Shutting down...")


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

    app.add_middleware(SupabaseAuthMiddleware)

    # ----------------------------
    # 3. Basic endpoints (prevent 404)
    # ----------------------------
    @app.get("/", tags=["Root"])
    async def root():
        return {
            "message": " GROWZA Career Advisor API",
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
        """Test endpoint – fetch profiles from Supabase."""
        profiles = db.read("profiles", limit=limit)
        return {
            "success": True,
            "count": len(profiles),
            "profiles": profiles
        }

    # Include API routers
    from app.api.router import api_router
    app.include_router(api_router, prefix=settings.API_V1_PREFIX)
    
    # Include feature routers
    from features.career_builder.routers.career_router import router as level_router
    from features.career_builder.routers.llm_health_router import router as llm_health_router
    from features.mock_interview.routers.mock_interview_router import router as mock_interview_router
    #from features.career_builder.routers.level_endpoints import router as level_router1
    #from features.career_builder.routers.testing_endpoints import router as testing_endpoints


    app.include_router(level_router, prefix=settings.API_V1_PREFIX)
    app.include_router(llm_health_router, prefix=settings.API_V1_PREFIX)
    app.include_router(mock_interview_router, prefix=settings.API_V1_PREFIX)
    #app.include_router(level_router1, prefix=settings.API_V1_PREFIX)
    #app.include_router(testing_endpoints, prefix=settings.API_V1_PREFIX)
    return app

    #from app.api.cv_optmization import router as cv_optmization_router
    #app.include_router(cv_optmization_router, prefix=settings.API_V1_PREFIX)
    #return app


app = create_application()

if __name__ == "__main__":
    def open_browser():
        webbrowser.open("http://localhost:8000/api/v1/docs")
    Timer(1.5, open_browser).start()
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
