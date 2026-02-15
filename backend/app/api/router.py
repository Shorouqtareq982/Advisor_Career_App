"""
Main API Router - Aggregates all API endpoints
"""
from fastapi import APIRouter

from app.api.azure_service import router as azure_service_router
from app.api.callGemeni import router as gemeni_router
from app.api.cloudinary_service import router as cloudinary_router

# Create main API router
api_router = APIRouter()

# Include all feature routers
api_router.include_router(azure_service_router)
api_router.include_router(gemeni_router)
api_router.include_router(cloudinary_router)

