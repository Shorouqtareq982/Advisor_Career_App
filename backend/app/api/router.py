"""
Main API Router - Aggregates all API endpoints
"""
from fastapi import APIRouter

from app.api.upload import router as upload_router
from app.api.callGemeni import router as gemeni_router

# Create main API router
api_router = APIRouter()

# Include all feature routers
api_router.include_router(upload_router)
api_router.include_router(gemeni_router)

