"""
Main API Router - Aggregates all API endpoints
"""
from fastapi import APIRouter

from app.api.azure_service import router as azure_service_router
from app.api.cloudinary_service import router as cloudinary_router
from app.api.cv_optmization import router as cv_optmization_router
from app.api.portfolio import router as portfolio_router
from app.api.user import router as user_router
# Create main API router
api_router = APIRouter()

# Include all feature routers
api_router.include_router(azure_service_router)
api_router.include_router(cloudinary_router)
api_router.include_router(cv_optmization_router)
api_router.include_router(user_router)
api_router.include_router(portfolio_router)
