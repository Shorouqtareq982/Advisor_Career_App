"""
Testing Endpoints ✅
"""
from fastapi import APIRouter
from typing import List, Dict, Any
from uuid import UUID
from pydantic import BaseModel
import logging

from features.career_builder.repositories.career_repository import CareerRepository
from features.career_builder.ml_models.skill_extractor import SkillExtractor
from features.career_builder.ml_models.level_detector import LevelDetector
from features.career_builder.ml_models.skill_matcher import HybridCareerAnalyzer
from features.career_builder.ml_models.realism_checker import RealismChecker
from features.career_builder.ml_models.gap_analyzer import SkillGapAnalyzer

from shared.providers.llm_models.llm_provider import create_llm_provider

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/career/test", tags=["testing"])


# =====================================================
# SCHEMAS
# =====================================================
class TestSkillExtractionRequest(BaseModel):
    cv_text: str

class TestSkillMatchingRequest(BaseModel):
    cv_skills: List[str]
    track_id: int

class TestLevelDetectionRequest(BaseModel):
    cv_text: str
    skills: List[str]
    experience_years: int = 0

class TestGapAnalysisRequest(BaseModel):
    current_level: str
    required_level: str

class TestRealismRequest(BaseModel):
    level: str
    requested_weeks: int
    missing_skills: List[str] = []  # ["python", "docker", ...] — سنحولها داخلياً


# =====================================================
# TEST 1: LLM
# =====================================================
@router.post("/llm")
async def test_llm_provider(
    prompt: str = "Extract skills from: I have 3 years Python experience"
):
    try:
        llm             = create_llm_provider()
        simple_response = await llm.get_response(prompt=prompt, need_json_output=False)
        json_response   = await llm.get_response('{"skills": ["Python"]}', need_json_output=True)
        return {
            "status":          "success",
            "llm_working":     True,
            "simple_response": str(simple_response)[:100],
            "json_response":   str(json_response)[:100]
        }
    except Exception as e:
        logger.error(f"LLM test failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e), "error_type": type(e).__name__}


# =====================================================
# TEST 2: Database
# =====================================================
@router.get("/database")
async def test_database():
    try:
        repo   = CareerRepository()
        tracks = await repo.get_all_tracks()
        skills = await repo.search_skills_by_name('')
        return {
            "status":       "success",
            "tracks_count": len(tracks),
            "skills_count": len(skills)
        }
    except Exception as e:
        logger.error(f"Database test failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e)}


# =====================================================
# TEST 3: Skill Extraction
# =====================================================
@router.post("/skill-extraction")
async def test_skill_extraction(request: TestSkillExtractionRequest):
    try:
        extractor = SkillExtractor()
        result    = await extractor.extract_skills_from_cv(
            cv_text=request.cv_text,
            parsed_cv_data={}
        )
        return {
            "status":       "success",
            "skills_found": len(result.get('normalized_skills', [])),
            "skills":       result.get('normalized_skills', [])
        }
    except Exception as e:
        logger.error(f"Skill extraction failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e)}


# =====================================================
# TEST 4: Skill Matching
# =====================================================
@router.post("/skill-matching")
async def test_skill_matching(request: TestSkillMatchingRequest):
    try:
        analyzer = HybridCareerAnalyzer()
        matches  = await analyzer.match_skills(
            cv_skills=request.cv_skills,
            track_id=request.track_id
        )
        return {
            "status":    "success",
            "cv_skills": request.cv_skills,
            "track_id":  request.track_id,
            "result":    matches
        }
    except Exception as e:
        logger.error(f"Skill matching failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e), "error_type": type(e).__name__}


# =====================================================
# TEST 5: Level Detection
# =====================================================
@router.post("/level-detection")
async def test_level_detection(request: TestLevelDetectionRequest):
    try:
        detector   = LevelDetector()
        raw_result = await detector.detect_skill_levels(
            cv_text=request.cv_text,
            parsed_cv_data={'years_of_experience': request.experience_years},
            required_skills=request.skills
        )
        skills       = raw_result.get('skill_levels', []) if isinstance(raw_result, dict) else []
        sample_skill = skills[0] if skills else {}
        return {
            "status":             "success",
            "overall_level":      raw_result.get('overall_level', 'N/A'),
            "overall_confidence": raw_result.get('overall_confidence', 'N/A'),
            "summary":            raw_result.get('summary', 'N/A'),
            "skill_count":        len(skills),
            "skills_sample":      skills[:3],
            "skill_structure":    list(sample_skill.keys()) if sample_skill else [],
            "raw_result_keys":    list(raw_result.keys()) if isinstance(raw_result, dict) else [],
            "input_summary": {
                "cv_length":        len(request.cv_text),
                "skills_tested":    len(request.skills),
                "experience_years": request.experience_years
            }
        }
    except Exception as e:
        logger.error(f"Level detection failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e), "error_type": type(e).__name__}


# =====================================================
# TEST 6: Gap Analysis
# =====================================================
@router.post("/gap-analysis")
async def test_gap_analysis(request: TestGapAnalysisRequest):
    try:
        analyzer = SkillGapAnalyzer()
        score    = analyzer.calculate_gap_score(request.current_level, request.required_level)
        return {"status": "success", "gap_score": score}
    except Exception as e:
        logger.error(f"Gap analysis failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e)}


# =====================================================
# TEST 7: Realism Check ✅
# =====================================================
@router.post("/realism-check")
async def test_realism_check(request: TestRealismRequest):
    try:
        # ✅ بيحول List[str] → List[Dict] تلقائياً
        normalized_skills = [
            {"skill_name": skill, "duration_weeks": 4}
            for skill in request.missing_skills
        ]
        checker = RealismChecker()
        result  = checker.check_realism(
            requested_weeks=request.requested_weeks,
            missing_skills=normalized_skills,
            level=request.level
        )
        return {
            "status":            "success",
            "requested_weeks":   result.requested_weeks,
            "safe_min_weeks":    result.safe_min_weeks,
            "recommended_weeks": result.recommended_weeks,
            "is_below_safe":     result.is_below_safe,
            "adjustment":        result.adjustment,
            "warning":           result.warning
        }
    except Exception as e:
        logger.error(f"Realism check failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e)}


# =====================================================

# =====================================================
# TEST 9: CV Retrieval
# =====================================================
@router.get("/cv/{cv_id}")
async def test_cv_retrieval(cv_id: UUID):
    try:
        repo = CareerRepository()
        cv   = await repo.get_cv_by_id(cv_id)
        return {"status": "success" if cv else "not_found", "cv_found": bool(cv)}
    except Exception as e:
        logger.error(f"CV retrieval failed: {e}", exc_info=True)
        return {"status": "failed", "error": str(e)}


# =====================================================
# TEST ALL ✅
# =====================================================
@router.get("/all")
async def test_all_components():
    results = {}

    # 1 - LLM
    try:
        llm = create_llm_provider()
        await llm.get_response("ping", need_json_output=False)
        results["llm"] = {"status": "passed"}
    except Exception as e:
        results["llm"] = {"status": "failed", "error": str(e)}

    # 2 - Database
    try:
        repo   = CareerRepository()
        tracks = await repo.get_all_tracks()
        results["database"] = {"status": "passed", "tracks": len(tracks)}
    except Exception as e:
        results["database"] = {"status": "failed", "error": str(e)}

    # 3 - Skill Extraction
    try:
        extractor = SkillExtractor()
        await extractor.extract_skills_from_cv(
            cv_text="3 years Python and Docker experience",
            parsed_cv_data={}
        )
        results["skill_extraction"] = {"status": "passed"}
    except Exception as e:
        results["skill_extraction"] = {"status": "failed", "error": str(e)}

    # 4 - Skill Matching
    try:
        analyzer = HybridCareerAnalyzer()
        await analyzer.match_skills(["Python", "Docker"], track_id=1)
        results["skill_matching"] = {"status": "passed"}
    except Exception as e:
        results["skill_matching"] = {"status": "failed", "error": str(e)}

    # 5 - Level Detection
    try:
        detector = LevelDetector()
        await detector.detect_skill_levels(
            cv_text="3 years Python experience",
            parsed_cv_data={},
            required_skills=["Python"]
        )
        results["level_detection"] = {"status": "passed"}
    except Exception as e:
        results["level_detection"] = {"status": "failed", "error": str(e)}

    # 6 - Gap Analysis
    try:
        analyzer = SkillGapAnalyzer()
        analyzer.calculate_gap_score("beginner", "intermediate")
        results["gap_analysis"] = {"status": "passed"}
    except Exception as e:
        results["gap_analysis"] = {"status": "failed", "error": str(e)}

    # 7 - Realism Check
    try:
        checker = RealismChecker()
        checker.check_realism(
            requested_weeks=10,
            missing_skills=[{"duration_weeks": 4}] * 5,
            level="beginner"
        )
        results["realism_check"] = {"status": "passed"}
    except Exception as e:
        results["realism_check"] = {"status": "failed", "error": str(e)}

    # 8 - Learning Path
    try:
        optimizer = LearningPathOptimizer()
        optimizer.optimize_learning_path([], [])
        results["learning_path"] = {"status": "passed"}
    except Exception as e:
        results["learning_path"] = {"status": "failed", "error": str(e)}

    # 9 - CV Retrieval
    try:
        repo = CareerRepository()
        await repo.get_cv_by_id("00000000-0000-0000-0000-000000000000")
        results["cv_retrieval"] = {"status": "passed", "note": "Returns None for unknown ID"}
    except Exception as e:
        results["cv_retrieval"] = {"status": "failed", "error": str(e)}

    passed = sum(1 for r in results.values() if r["status"] == "passed")
    total  = len(results)

    return {
        "status": "success",
        "summary": {
            "total_tests": total,
            "passed":      passed,
            "failed":      total - passed,
            "pass_rate":   f"{int(passed / total * 100)}%"
        },
        "results": results
    }