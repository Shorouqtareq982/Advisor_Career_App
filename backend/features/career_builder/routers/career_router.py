"""
Career Builder Router
"""

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends
import logging

from features.career_builder.schemas.career_schemas import (
    ConfirmRequest,
    PlanGenerateRequest,
    PlanRegenerateRequest,
    SavePlanRequest,
)
from features.career_builder.services.career_analysis_service import CareerAnalysisService
from features.career_builder.services.plan_generation_service import PlanGenerationService
from features.career_builder.services.plan_regeneration_service import PlanRegenerationService
from features.career_builder.services.plan_persistence_service import PlanPersistenceService
from features.career_builder.repositories.career_repository import CareerRepository
from shared.helpers.document_parser import DocumentParser
from shared.providers.supabase.database import db as supabase_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/career", tags=["career-builder"])


LEVEL_VALUES = {
    "none": 0,
    "beginner": 1,
    "intermediate": 2,
    "advanced": 3,
}


def _calculate_gap_score_simple(current_level: str, required_level: str) -> float:
    current = LEVEL_VALUES.get((current_level or "none").lower(), 0)
    required = LEVEL_VALUES.get((required_level or "beginner").lower(), 1)

    if current >= required:
        return 0.0

    gap = required - current
    max_gap = required
    return gap / max_gap if max_gap > 0 else 1.0


def _derive_status(current_level: str, required_level: str) -> str:
    current_value = LEVEL_VALUES.get((current_level or "none").lower(), 0)
    required_value = LEVEL_VALUES.get((required_level or "beginner").lower(), 1)

    if current_value == 0:
        return "missing"
    elif current_value < required_value:
        return "partial"
    return "has"


def _recalculate_gap_fields(gap: dict) -> dict:
    current_level = (gap.get("current_level") or "none").lower()
    required_level = (gap.get("required_level") or "beginner").lower()

    gap["status"] = _derive_status(current_level, required_level)
    gap["gap_score"] = round(_calculate_gap_score_simple(current_level, required_level), 3)
    return gap


def _recalculate_reviewable_skill(skill: dict) -> dict:
    detected_level = (skill.get("detected_level") or "none").lower()
    required_level = (skill.get("required_level") or "beginner").lower()

    new_status = _derive_status(detected_level, required_level)
    skill["status"] = new_status
    skill["selected_by_default"] = new_status in ("missing", "partial")
    return skill


def _suggest_target_level(current_level: str, required_level: str, weeks: int) -> tuple[str, str]:
    current = LEVEL_VALUES.get(current_level, 0)
    required = LEVEL_VALUES.get(required_level, 1)

    if current == 0:
        if weeks >= 10:
            return "intermediate", "Enough time is available to go beyond the basics."
        return "beginner", "This skill is missing, so starting with fundamentals is the best path."

    if current < required:
        return required_level, "This target is needed to meet the track requirement."

    if weeks >= 8:
        if current == 1:
            return "intermediate", "There is enough time to strengthen this skill to intermediate."
        if current == 2:
            return "advanced", "There is enough time to push this skill toward advanced."

    return current_level, "Your current level is already sufficient for now."


def _calculate_realism(
    selected_learning_targets: list,
    requested_weeks: int,
    level_used: str,
    available_hours_per_week: int
) -> dict:
    """
    Realism now considers both:
    - requested duration
    - available hours per week

    More weekly hours => more capacity => smaller effective safe minimum.
    """
    total_weeks = sum(item.get("required_weeks", 4) for item in selected_learning_targets)

    level_multiplier = {
        "beginner": 1.3,
        "intermediate": 1.0,
        "advanced": 0.75,
    }

    hours_factor = {
        "light": 1.25,      # 1-5 h/week
        "moderate": 1.0,    # 6-10 h/week
        "intensive": 0.8,   # 11+ h/week
    }

    if available_hours_per_week <= 5:
        intensity = "light"
    elif available_hours_per_week <= 10:
        intensity = "moderate"
    else:
        intensity = "intensive"

    multiplier = level_multiplier.get((level_used or "beginner").lower(), 1.0)
    hour_multiplier = hours_factor[intensity]

    safe_min_weeks = max(1, round(total_weeks * multiplier * hour_multiplier)) if total_weeks > 0 else 1
    recommended_weeks = safe_min_weeks
    max_weeks = round(total_weeks * 2.5) if total_weeks > 0 else requested_weeks

    if requested_weeks < safe_min_weeks:
        return {
            "requested_weeks": requested_weeks,
            "available_hours_per_week": available_hours_per_week,
            "study_intensity": intensity,
            "safe_min_weeks": safe_min_weeks,
            "recommended_weeks": recommended_weeks,
            "is_below_safe": True,
            "adjustment": "too_short",
            "warning": (
                f"The chosen duration ({requested_weeks} weeks) with "
                f"{available_hours_per_week} hours/week is below the safe minimum "
                f"({safe_min_weeks} weeks for {level_used} level). "
                f"It might be difficult to cover all required skills."
            )
        }

    if requested_weeks > max_weeks:
        return {
            "requested_weeks": requested_weeks,
            "available_hours_per_week": available_hours_per_week,
            "study_intensity": intensity,
            "safe_min_weeks": safe_min_weeks,
            "recommended_weeks": recommended_weeks,
            "is_below_safe": False,
            "adjustment": "too_long",
            "warning": (
                f"The chosen duration ({requested_weeks} weeks) exceeds the reasonable maximum "
                f"({max_weeks} weeks)."
            )
        }

    return {
        "requested_weeks": requested_weeks,
        "available_hours_per_week": available_hours_per_week,
        "study_intensity": intensity,
        "safe_min_weeks": safe_min_weeks,
        "recommended_weeks": recommended_weeks,
        "is_below_safe": False,
        "adjustment": "ok",
        "warning": ""
    }


def get_repository() -> CareerRepository:
    return CareerRepository(supabase_db)


def get_analysis_service() -> CareerAnalysisService:
    repo = get_repository()
    return CareerAnalysisService(repository=repo)


def get_plan_generation_service() -> PlanGenerationService:
    repo = get_repository()
    analysis_service = CareerAnalysisService(repository=repo)
    return PlanGenerationService(repository=repo, analysis_service=analysis_service)


def get_plan_regeneration_service() -> PlanRegenerationService:
    return PlanRegenerationService()


def get_plan_persistence_service() -> PlanPersistenceService:
    repo = get_repository()
    return PlanPersistenceService(repository=repo)


@router.get("/tracks")
async def get_tracks(repo: CareerRepository = Depends(get_repository)):
    try:
        tracks = await repo.get_all_tracks() or []
        formatted_tracks = [
            {
                "track_id": track["track_id"],
                "track_name": track["track_name"],
                "description": track.get("description")
            }
            for track in tracks
        ]
        return {
            "status": "success",
            "tracks": formatted_tracks,
            "total": len(formatted_tracks)
        }
    except Exception as e:
        logger.error(f"Get tracks failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze")
async def analyze_cv(
    cv_file: UploadFile = File(...),
    track_id: int = Form(...),
    service: CareerAnalysisService = Depends(get_analysis_service),
):
    try:
        repo = service.repo
        parser = DocumentParser()

        cv_text, parsed_cv = await parser.parse_cv(file=cv_file)

        if not cv_text:
            raise HTTPException(status_code=400, detail="Failed to extract text from CV.")

        cv_id = await repo.save_cv(
            file_url=cv_file.filename,
            text_content=cv_text,
            parsed_content=parsed_cv or {}
        )

        if not cv_id:
            raise HTTPException(status_code=500, detail="Failed to save CV.")

        analysis = await service.analyze_cv_for_track(
            cv_id=cv_id,
            track_id=track_id,
            requested_weeks=0,
            user_level=None
        )

        await repo.save_analysis_cache(
            cv_id=cv_id,
            track_id=track_id,
            analysis_data={
                "cv_id": str(cv_id),
                "track_id": track_id,
                "track_name": analysis.track_name,
                "detected_level": analysis.detected_level,
                "required_level": analysis.required_level,
                "level_confidence": analysis.level_confidence,
                "level_reasoning": analysis.level_reasoning,
                "cv_skills": analysis.cv_skills,
                "matched_skills": analysis.matched_skills,
                "missing_skills": analysis.missing_skills,
                "match_percentage": analysis.match_percentage,
                "matching_method": analysis.matching_method,
                "skill_gaps": analysis.skill_gaps,
                "fit_analysis": analysis.fit_analysis,
                "reviewable_skills": analysis.reviewable_skills,
                "detected_skill_levels": analysis.detected_skill_levels,
                "analysis_quality": analysis.analysis_quality,
            }
        )

        recommended_skills = []
        owned_skills = []

        for gap in analysis.skill_gaps:
            status = gap.get("status")
            if status in ("missing", "partial"):
                recommended_skills.append({
                    "skill_id": gap.get("skill_id"),
                    "skill_name": gap.get("skill_name"),
                    "status": status,
                    "required_level": gap.get("required_level"),
                    "required_weeks": gap.get("required_weeks", 4),
                    "importance": gap.get("importance_weight", 3),
                    "selected_by_default": True
                })

        for skill in analysis.reviewable_skills:
            if skill.get("status") == "has":
                owned_skills.append({
                    "skill_id": skill.get("skill_id"),
                    "skill_name": skill.get("skill_name"),
                    "detected_level": skill.get("detected_level"),
                    "confidence": skill.get("confidence"),
                    "needs_user_input": skill.get("needs_user_input"),
                    "required_level": skill.get("required_level")
                })

        return {
            "status": "success",
            "cv_id": str(cv_id),
            "track_id": track_id,
            "track_name": analysis.track_name,
            "detected_level": analysis.detected_level,
            "required_level": analysis.required_level,
            "level_confidence": round(analysis.level_confidence, 3),
            "level_reasoning": analysis.level_reasoning,
            "recommended_skills": recommended_skills,
            "owned_skills": owned_skills,
            "summary": {
                "already_have": len(owned_skills),
                "need_to_learn": len(recommended_skills),
                "match_percentage": analysis.match_percentage
            },
            "raw": {
                "fit_analysis": analysis.fit_analysis,
                "reviewable_skills": analysis.reviewable_skills,
                "skill_gaps": analysis.skill_gaps,
                "detected_skill_levels": analysis.detected_skill_levels,
                "matched_skills": analysis.matched_skills,
                "missing_skills": analysis.missing_skills,
                "metadata": {
                    "matching_method": analysis.matching_method,
                    "analysis_quality": analysis.analysis_quality,
                }
            }
        }

    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"Analyze value error: {e}", exc_info=True)
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/confirm")
async def confirm_duration(
    request: ConfirmRequest,
    repo: CareerRepository = Depends(get_repository),
):
    try:
        cached = await repo.get_analysis_cache(cv_id=request.cv_id, track_id=request.track_id)

        if not cached:
            raise HTTPException(
                status_code=400,
                detail="You must call /analyze first before /confirm."
            )

        level_used = (
            request.user_level.value
            if request.user_level is not None
            else cached.get("detected_level", "beginner")
        )

        reviewable_skills = cached.get("reviewable_skills", []) or []
        skill_gaps = cached.get("skill_gaps", []) or []

        override_map = {
            override.skill_id: override.level.value
            for override in request.skill_overrides
        }

        for skill in reviewable_skills:
            skill_id = skill.get("skill_id")
            if skill_id in override_map:
                skill["detected_level"] = override_map[skill_id]
                skill["needs_user_input"] = False
                _recalculate_reviewable_skill(skill)

        for gap in skill_gaps:
            skill_id = gap.get("skill_id")
            if skill_id in override_map:
                gap["current_level"] = override_map[skill_id]
                _recalculate_gap_fields(gap)

        selected_skill_ids = request.selected_skill_ids or [
            s["skill_id"]
            for s in reviewable_skills
            if s.get("selected_by_default") and s.get("skill_id") is not None
        ]

        explicit_targeted_ids = {item.skill_id for item in request.skill_targets}

        suggested_targets = []
        for gap in skill_gaps:
            skill_id = gap.get("skill_id")
            skill_name = gap.get("skill_name")
            current_level = (gap.get("current_level") or "none").lower()
            required_level = (gap.get("required_level") or "beginner").lower()

            should_suggest = (
                skill_id in selected_skill_ids
                or skill_id in explicit_targeted_ids
            )

            if not should_suggest:
                continue

            suggested_level, reason = _suggest_target_level(
                current_level=current_level,
                required_level=required_level,
                weeks=request.requested_weeks
            )

            learning_mode = "learn_from_scratch" if current_level == "none" else "level_up"

            suggested_targets.append({
                "skill_id": skill_id,
                "skill_name": skill_name,
                "current_level": current_level,
                "suggested_target_level": suggested_level,
                "target_reason": reason,
                "learning_mode": learning_mode
            })

        target_map = {
            item.skill_id: item.target_level.value
            for item in request.skill_targets
        }

        if not target_map:
            for item in suggested_targets:
                target_map[item["skill_id"]] = item["suggested_target_level"]

        targeted_skill_ids = set(target_map.keys())

        unresolved = [
            skill for skill in reviewable_skills
            if (
                skill.get("skill_id") in targeted_skill_ids
                and skill.get("status") == "has"
                and skill.get("needs_user_input")
                and not skill.get("detected_level")
            )
        ]

        if unresolved:
            unresolved_names = [s.get("skill_name") for s in unresolved]
            raise HTTPException(
                status_code=400,
                detail=f"These skills still need user input: {', '.join(unresolved_names)}"
            )

        confirmed_learning_targets = []

        for gap in skill_gaps:
            skill_id = gap.get("skill_id")
            if skill_id is None:
                continue

            current_level = (gap.get("current_level") or "none").lower()
            required_level = (gap.get("required_level") or "beginner").lower()
            target_level = target_map.get(skill_id)

            if not target_level:
                continue

            current_value = LEVEL_VALUES.get(current_level, 0)
            target_value = LEVEL_VALUES.get(target_level, 1)

            if current_value >= target_value:
                continue

            learning_mode = "learn_from_scratch" if current_value == 0 else "level_up"

            confirmed_learning_targets.append({
                "skill_id": skill_id,
                "skill_name": gap.get("skill_name"),
                "current_level": current_level,
                "target_level": target_level,
                "required_level": required_level,
                "required_weeks": gap.get("required_weeks", 4),
                "importance_weight": gap.get("importance_weight", 3),
                "learning_mode": learning_mode
            })

        if not confirmed_learning_targets:
            raise HTTPException(
                status_code=400,
                detail="No valid learning targets found. Choose missing skills or raise target level for existing skills."
            )

        realism = _calculate_realism(
            selected_learning_targets=confirmed_learning_targets,
            requested_weeks=request.requested_weeks,
            level_used=level_used,
            available_hours_per_week=request.available_hours_per_week
        )

        updated_cache = {
            **cached,
            "level_used": level_used,
            "selected_skill_ids": selected_skill_ids,
            "available_hours_per_week": request.available_hours_per_week,
            "skill_overrides": [
                {
                    "skill_id": override.skill_id,
                    "level": override.level.value
                }
                for override in request.skill_overrides
            ],
            "suggested_targets": suggested_targets,
            "skill_targets": [
                {
                    "skill_id": skill_id,
                    "target_level": target_level
                }
                for skill_id, target_level in target_map.items()
            ],
            "confirmed_learning_targets": confirmed_learning_targets,
            "reviewable_skills": reviewable_skills,
            "skill_gaps": skill_gaps,
            "confirmed": True,
            "confirmed_requested_weeks": request.requested_weeks,
            "realism": realism,
        }

        await repo.save_analysis_cache(
            cv_id=request.cv_id,
            track_id=request.track_id,
            analysis_data=updated_cache
        )

        return {
            "status": "success",
            "cv_id": str(request.cv_id),
            "track_id": request.track_id,
            "track_name": cached.get("track_name"),
            "detected_level": cached.get("detected_level"),
            "level_used": level_used,
            "available_hours_per_week": request.available_hours_per_week,
            "level_confidence": round(cached.get("level_confidence", 0), 3),
            "fit_analysis": cached.get("fit_analysis", {}),
            "selected_skill_ids": selected_skill_ids,
            "suggested_targets": suggested_targets,
            "skill_targets": updated_cache["skill_targets"],
            "confirmed_learning_targets": confirmed_learning_targets,
            "reviewable_skills": reviewable_skills,
            "skill_gaps": skill_gaps,
            "realism": realism,
            "matched_skills": cached.get("matched_skills", []),
            "missing_skills": cached.get("missing_skills", []),
            "metadata": {
                "match_percentage": cached.get("match_percentage", 0),
                "matching_method": cached.get("matching_method", "unknown"),
                "analysis_quality": cached.get("analysis_quality", 0),
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Confirm failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate-plan")
async def generate_plan(
    request: PlanGenerateRequest,
    service: PlanGenerationService = Depends(get_plan_generation_service),
):
    try:
        result = await service.generate_plan(
            cv_id=request.cv_id,
            track_id=request.track_id,
            duration_weeks=request.duration_weeks,
            available_hours_per_week=request.available_hours_per_week,
            user_level=request.user_level,
            requested_weeks=request.duration_weeks,
            selected_skill_ids=request.selected_skill_ids,
            skill_targets=request.skill_targets
        )

        return {
            "status": "success",
            **result
        }

    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"Generate plan value error: {e}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Plan generation failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/regenerate-plan")
async def regenerate_plan(
    request: PlanRegenerateRequest,
    service: PlanRegenerationService = Depends(get_plan_regeneration_service),
):
    try:
        result = await service.regenerate_plan(
            previous_plan=request.previous_plan,
            feedback=request.feedback,
            regeneration_mode=request.regeneration_mode
        )

        return {
            "status": "success",
            **result
        }

    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"Regenerate plan value error: {e}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Plan regeneration failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/save-plan")
async def save_plan(
    request: SavePlanRequest,
    service: PlanPersistenceService = Depends(get_plan_persistence_service),
):
    try:
        result = await service.save_plan(
            user_id=request.user_id,
            cv_id=request.cv_id,
            track_id=request.track_id,
            detected_level=request.detected_level.value,
            confirmed_level=request.confirmed_level.value,
            duration_weeks=request.duration_weeks,
            plan_data={
                "available_hours_per_week": request.available_hours_per_week,
                "weekly_breakdown": [
                    {
                        "week_number": item.week_number,
                        "focus_skills": [item.skill_name],
                        "topic": item.topic,
                        "description": item.description,
                        "resources": item.resources,
                    }
                    for item in request.weekly_content
                ]
            },
            skill_gaps=[gap.model_dump() for gap in request.skill_gaps]
        )

        return {
            "status": "success",
            **result
        }

    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"Save plan value error: {e}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Save plan failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))