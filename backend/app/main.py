"""
GROWZA Career Advisor - FastAPI Application Entry Point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.api.router import api_router
from core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    # Startup
    print("Starting up GROWZA Career Advisor API...")
    yield
    # Shutdown
    print("Shutting down GROWZA Career Advisor API...")


def create_application() -> FastAPI:
    """Application factory pattern."""
    application = FastAPI(
        title=settings.PROJECT_NAME,
        description="AI-Powered Career Advisor Platform",
        version=settings.VERSION,
        openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
        docs_url=f"{settings.API_V1_PREFIX}/docs",
        redoc_url=f"{settings.API_V1_PREFIX}/redoc",
        lifespan=lifespan,
    )

    # CORS middleware
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Include API router
    application.include_router(api_router, prefix=settings.API_V1_PREFIX)

    return application


app = create_application()


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "version": settings.VERSION}
