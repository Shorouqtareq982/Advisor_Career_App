"""
Backend 1 - Final Router
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Dict, Any
from uuid import UUID
import logging
from features.career_builder.repositories.career_repository import CareerRepository
from features.career_builder.services.career_analysis_service import CareerAnalysisService

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/career/backend1",
    tags=["career-backend1"]
)


# =====================================================
# DEPENDENCY - بدون وسيط
# =====================================================

async def get_analysis_service() -> CareerAnalysisService:
    """Get Backend 1 analysis service"""
    repository = CareerRepository()  # ← بدون وسيط
    return CareerAnalysisService(repository)


# =====================================================
# MAIN ENDPOINT - COMPLETE ANALYSIS
# =====================================================

@router.post(
    "/analyze",
    status_code=status.HTTP_200_OK,
    summary="🎯 Backend 1 - Complete CV Analysis"
)
async def analyze_cv_backend1(
    cv_id: UUID,
    track_id: int,
    service: CareerAnalysisService = Depends(get_analysis_service)
) -> Dict[str, Any]:
    """Backend 1 - Complete Analysis"""
    try:
        logger.info(f"🎯 Backend 1 Analysis: cv_id={cv_id}, track_id={track_id}")
        
        # Run complete analysis
        result = await service.analyze_cv_for_track(
            cv_id=cv_id,
            track_id=track_id
        )
        
        # Convert to output contract
        output_contract = service.to_output_contract(result)
        
        logger.info(
            f"✅ Analysis complete: "
            f"level={result.detected_level}, "
            f"gaps={result.missing_skills_count}, "
            f"quality={result.analysis_quality:.2f}"
        )
        
        return output_contract
        
    except ValueError as e:
        logger.error(f"Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Backend 1 analysis failed: {str(e)}"
        )


# =====================================================
# HEALTH CHECK
# =====================================================

@router.get("/health")
async def backend1_health():
    """Backend 1 health check"""
    return {
        "status": "healthy",
        "backend": "Backend 1 - Analysis Engine",
        "version": "2.1.0",
        "capabilities": [
            "CV Parsing (multi-format)",
            "LLM Skill Extraction",
            "Hybrid Level Detection",
            "Smart Gap Scoring",
            "Time Realism Logic",
            "Standardized Output Contract"
        ]
    }