"""
Backend 1 - Final Router
Implements exact output contract as specified
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, Any
from uuid import UUID
import logging

from shared.providers.supabase.database import get_db
from features.career_builder.services.career_analysis_service import (
    CareerAnalysisService,
)
#from features.career_builder.services import CareerAnalysisService
from features.career_builder.repositories import CareerRepository
logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/career/backend1",
    tags=["career-backend1"]
)


# =====================================================
# DEPENDENCY
# =====================================================

async def get_analysis_service(
    db: AsyncSession = Depends(get_db)
) -> CareerAnalysisService:
    """Get Backend 1 analysis service"""
    repository = CareerRepository(db)
    return CareerAnalysisService(repository)


# =====================================================
# MAIN ENDPOINT - COMPLETE ANALYSIS
# =====================================================

@router.post(
    "/analyze",
    status_code=status.HTTP_200_OK,
    summary="🎯 Backend 1 - Complete CV Analysis",
    description="""
    **Complete Analysis Pipeline (Backend 1)**
    
    Phases:
    1. ✅ CV Parsing & Skill Extraction (LLM-powered)
    2. ✅ Level Detection (Hybrid: LLM + Rules)
    3. ✅ Skill Gap Scoring (Smart gap calculation)
    4. ✅ Time Realism Logic (Duration validation)
    5. ✅ Standardized Output Contract (for Backend 2)
    
    **Output Contract:**
    ```json
    {
      "detected_level": "intermediate",
      "realism_flag": false,
      "suggested_min_weeks": 16,
      "skills": [
        {
          "skill_id": 3,
          "skill_name": "Docker",
          "status": "missing",
          "gap_score": 0.8
        }
      ]
    }
    ```
    
    **⚠️ IMPORTANT:**
    This output format is FIXED - Backend 2 depends on it.
    Do not modify without coordinating with Backend 2 developer.
    """
)
async def analyze_cv_backend1(
    cv_id: UUID,
    track_id: int,
    service: CareerAnalysisService = Depends(get_analysis_service)
) -> Dict[str, Any]:
    """
    Backend 1 - Complete Analysis
    
    **Input:**
    - cv_id: UUID of CV in database
    - track_id: Selected career track
    
    **Output:**
    - Standardized contract for Backend 2
    
    **Workflow:**
    ```
    CV → Extract Skills → Detect Level → Calculate Gaps 
    → Check Realism → Return Contract
    ```
    """
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
# DETAILED ANALYSIS ENDPOINT (For debugging/inspection)
# =====================================================

@router.post(
    "/analyze/detailed",
    status_code=status.HTTP_200_OK,
    summary="Get detailed analysis (with all metadata)",
    description="Returns full analysis result including confidence scores and reasoning"
)
async def analyze_cv_detailed(
    cv_id: UUID,
    track_id: int,
    service: CareerAnalysisService = Depends(get_analysis_service)
):
    """
    Detailed analysis endpoint
    
    Returns ALL analysis data including:
    - Extracted skills
    - Confidence scores
    - Level reasoning
    - Match details
    - Quality metrics
    
    **Use this for:**
    - Debugging
    - Quality inspection
    - Frontend display of analysis details
    """
    try:
        result = await service.analyze_cv_for_track(cv_id, track_id)
        
        # Return full result (not just contract)
        return {
            "cv_id": str(result.cv_id),
            "track_id": result.track_id,
            "track_name": result.track_name,
            
            # Skill extraction
            "extracted_skills": result.extracted_skills,
            "normalized_skills": result.normalized_skills,
            "extraction_confidence": round(result.extraction_confidence, 3),
            
            # Level detection
            "detected_level": result.detected_level,
            "level_confidence": round(result.level_confidence, 3),
            "level_reasoning": result.level_reasoning,
            
            # Skill gaps
            "skill_gaps": result.skill_gaps,
            "missing_skills_count": result.missing_skills_count,
            
            # Realism
            "min_weeks_required": result.min_weeks_required,
            "suggested_min_weeks": result.suggested_min_weeks,
            "realism_flag": result.realism_flag,
            "realism_info": result.realism_info,
            
            # Quality
            "analysis_quality": round(result.analysis_quality, 3)
        }
        
    except Exception as e:
        logger.error(f"Detailed analysis failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
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
        ],
        "dependencies": [
            "DocumentParser (shared)",
            "LLM Provider (shared)",
            "PostgreSQL Database"
        ]
    }


# =====================================================
# OUTPUT CONTRACT DOCUMENTATION
# =====================================================

@router.get("/output-contract")
async def get_output_contract_schema():
    """
    Get the exact output contract schema
    
    **⚠️ CRITICAL:**
    This is the contract between Backend 1 and Backend 2.
    Any changes MUST be coordinated with both teams.
    """
    return {
        "contract_version": "1.0",
        "description": "Backend 1 → Backend 2 Data Contract",
        "schema": {
            "detected_level": {
                "type": "string",
                "enum": ["beginner", "intermediate", "advanced"],
                "required": True,
                "description": "User's detected skill level"
            },
            "level_confidence": {
                "type": "float",
                "range": [0.0, 1.0],
                "required": True,
                "description": "Confidence in level detection"
            },
            "realism_flag": {
                "type": "boolean",
                "required": True,
                "description": "False = realistic, True = duration too short"
            },
            "suggested_min_weeks": {
                "type": "integer",
                "required": True,
                "description": "Minimum realistic duration (weeks)"
            },
            "min_weeks_required": {
                "type": "integer",
                "required": True,
                "description": "Absolute minimum weeks for track/level"
            },
            "skills": {
                "type": "array",
                "required": True,
                "description": "Skill gaps with priorities",
                "item_schema": {
                    "skill_id": "integer (database ID)",
                    "skill_name": "string",
                    "category": "string",
                    "status": "enum: has|missing|partial",
                    "current_level": "enum: none|beginner|intermediate|advanced",
                    "required_level": "enum: beginner|intermediate|advanced",
                    "gap_score": "float [0-1]",
                    "importance_weight": "integer [1-5]",
                    "required_weeks": "integer"
                }
            },
            "metadata": {
                "type": "object",
                "required": False,
                "description": "Additional analysis metadata",
                "fields": {
                    "extracted_skills_count": "integer",
                    "extraction_confidence": "float",
                    "analysis_quality": "float",
                    "level_reasoning": "string"
                }
            }
        },
        "example": {
            "detected_level": "intermediate",
            "level_confidence": 0.852,
            "realism_flag": False,
            "suggested_min_weeks": 20,
            "min_weeks_required": 24,
            "skills": [
                {
                    "skill_id": 3,
                    "skill_name": "RESTful API Design",
                    "category": "API Development",
                    "status": "missing",
                    "current_level": "none",
                    "required_level": "intermediate",
                    "gap_score": 1.0,
                    "importance_weight": 4,
                    "required_weeks": 3
                }
            ],
            "metadata": {
                "extracted_skills_count": 8,
                "extraction_confidence": 0.891,
                "analysis_quality": 0.875,
                "level_reasoning": "5 years experience, 8 relevant skills matched"
            }
        }
    }