"""
Career Builder Router
Draft-first version:
- analyze
- confirm-skills
- confirm-time
- generate-plan (draft only)
- regenerate-plan (draft only)
- save-plan (final persistence only)
"""

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends
from uuid import UUID
import logging

from features.career_builder.schemas.career_schemas import (
    ConfirmSkillsRequest,
    ConfirmTimeRequest,
    PlanGenerateRequest,
    PlanRegenerateRequest,
    SavePlanRequest,
)
from features.career_builder.services.career_analysis_service import CareerAnalysisService
from features.career_builder.services.plan_generation_service import PlanGenerationService
from features.career_builder.services.plan_regeneration_service import PlanRegenerationService
from features.career_builder.services.plan_persistence_service import PlanPersistenceService
from features.career_builder.services.time_guidance_service import TimeGuidanceService
from features.career_builder.ml_models.advanced_realism_checker import AdvancedRealismChecker
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


def get_repository() -> CareerRepository:
    return CareerRepository(supabase_db)


def get_analysis_service() -> CareerAnalysisService:
    repo = get_repository()
    return CareerAnalysisService(repository=repo)


def get_plan_persistence_service() -> PlanPersistenceService:
    repo = get_repository()
    return PlanPersistenceService(repository=repo)


def get_time_guidance_service() -> TimeGuidanceService:
    repo = get_repository()
    return TimeGuidanceService(repository=repo)


def get_advanced_realism_checker() -> AdvancedRealismChecker:
    return AdvancedRealismChecker()


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


@router.get("/regeneration-intents")
async def get_regeneration_intents():
    try:
        from features.career_builder.services.plan_feedback_mapper import PlanFeedbackMapper
        intents = PlanFeedbackMapper.get_all_intents_for_ui()
        return {
            "status": "success",
            "available_intents": intents
        }
    except Exception as e:
        logger.error(f"Get regeneration intents failed: {e}", exc_info=True)
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


@router.post("/confirm-skills")
async def confirm_skills(
    request: ConfirmSkillsRequest,
    repo: CareerRepository = Depends(get_repository),
):
    try:
        cached = await repo.get_analysis_cache(cv_id=request.cv_id, track_id=request.track_id)

        if not cached:
            raise HTTPException(
                status_code=400,
                detail="You must call /analyze first before /confirm-skills."
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

        updated_detected_skill_levels = {
            gap.get("skill_name"): (gap.get("current_level") or "none").lower()
            for gap in skill_gaps
            if gap.get("skill_name")
        }

        selected_skill_ids = request.selected_skill_ids or [
            gap.get("skill_id")
            for gap in skill_gaps
            if gap.get("status") in ("missing", "partial")
        ]

        updated_cache = {
            **cached,
            "selected_skill_ids": selected_skill_ids,
            "skill_overrides": [
                {
                    "skill_id": override.skill_id,
                    "level": override.level.value
                }
                for override in request.skill_overrides
            ],
            "reviewable_skills": reviewable_skills,
            "skill_gaps": skill_gaps,
            "detected_skill_levels": updated_detected_skill_levels,
            "skills_confirmed": True,
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
            "selected_skill_ids": selected_skill_ids,
            "reviewable_skills": reviewable_skills,
            "skill_gaps": skill_gaps,
            "detected_skill_levels": updated_detected_skill_levels,
            "fit_analysis": cached.get("fit_analysis", {}),
            "metadata": {
                "match_percentage": cached.get("match_percentage", 0),
                "matching_method": cached.get("matching_method", "unknown"),
                "analysis_quality": cached.get("analysis_quality", 0),
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Confirm skills failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/confirm-time-preview")
async def confirm_time_preview(
    cv_id: UUID = Form(...),
    track_id: int = Form(...),
    service: TimeGuidanceService = Depends(get_time_guidance_service),
    repo: CareerRepository = Depends(get_repository),
):
    try:
        cached = await repo.get_analysis_cache(cv_id=cv_id, track_id=track_id)

        if not cached:
            raise HTTPException(
                status_code=400,
                detail="You must call /analyze first before /confirm-time-preview."
            )

        skill_gaps = cached.get("skill_gaps", []) or []
        selected_skill_ids = cached.get("selected_skill_ids", []) or [
            gap.get("skill_id")
            for gap in skill_gaps
            if gap.get("status") in ("missing", "partial")
        ]
        detected_skill_levels = cached.get("detected_skill_levels", {}) or {}

        if not selected_skill_ids:
            raise HTTPException(
                status_code=400,
                detail="No skills selected. Please confirm skills first."
            )

        default_hours = 6

        guidance = await service.get_time_guidance(
            cv_id=cv_id,
            track_id=track_id,
            selected_skill_ids=selected_skill_ids,
            detected_skill_levels=detected_skill_levels,
            available_hours_per_week=default_hours
        )

        guidance_message = (
            f"Based on {default_hours} hours/week study commitment:\n"
            f"• Minimum: {guidance.minimum_weeks} weeks (focus on essentials)\n"
            f"• Suitable: {guidance.suitable_weeks} weeks (recommended)\n"
            f"• Comprehensive: {guidance.maximum_weeks} weeks (master everything)"
        )

        return {
            "status": "success",
            "cv_id": str(cv_id),
            "track_id": track_id,
            "track_name": cached.get("track_name"),
            "detected_level": cached.get("detected_level"),
            "selected_skill_ids": selected_skill_ids,
            "guidance_hours_per_week": default_hours,
            "time_guidance": {
                "minimum_weeks": guidance.minimum_weeks,
                "suitable_weeks": guidance.suitable_weeks,
                "maximum_weeks": guidance.maximum_weeks,
                "study_intensity": guidance.study_intensity,
                "minimum_weeks_breakdown": guidance.minimum_weeks_breakdown,
                "suitable_weeks_breakdown": guidance.suitable_weeks_breakdown,
                "maximum_weeks_breakdown": guidance.maximum_weeks_breakdown,
            },
            "guidance_message": guidance_message,
            "note": "This is a preview based on default 6 hours/week. Adjust your hours/weeks in the next step for accurate validation."
        }

    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"Time preview value error: {e}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Time preview failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/confirm-time")
async def confirm_time(
    request: ConfirmTimeRequest,
    repo: CareerRepository = Depends(get_repository),
    service: TimeGuidanceService = Depends(get_time_guidance_service),
):
    try:
        cached = await repo.get_analysis_cache(cv_id=request.cv_id, track_id=request.track_id)

        if not cached:
            raise HTTPException(
                status_code=400,
                detail="You must call /analyze first before /confirm-time."
            )

        detected_level = cached.get("detected_level", "beginner")
        reviewable_skills = cached.get("reviewable_skills", []) or []
        skill_gaps = cached.get("skill_gaps", []) or []
        selected_skill_ids = cached.get("selected_skill_ids", []) or [
            gap.get("skill_id")
            for gap in skill_gaps
            if gap.get("status") in ("missing", "partial")
        ]

        if not selected_skill_ids:
            raise HTTPException(
                status_code=400,
                detail="No skills selected. Please confirm skills first."
            )

        detected_skill_levels = {
            gap.get("skill_name"): (gap.get("current_level") or "none").lower()
            for gap in skill_gaps
            if gap.get("skill_name")
        }

        guidance = await service.get_time_guidance(
            cv_id=request.cv_id,
            track_id=request.track_id,
            selected_skill_ids=selected_skill_ids,
            detected_skill_levels=detected_skill_levels,
            available_hours_per_week=request.available_hours_per_week
        )

        minimum_weeks = guidance.minimum_weeks
        suitable_weeks = guidance.suitable_weeks
        maximum_weeks = guidance.maximum_weeks
        requested_weeks = request.requested_weeks

        warnings = []
        suggestions = []
        is_realistic = True
        adjustment = "ok"
        zone = "suitable"

        if requested_weeks < minimum_weeks:
            is_realistic = False
            adjustment = "unrealistic_too_short"
            zone = "below_minimum"
            warnings.append(
                f"Your requested {requested_weeks} weeks is below the minimum required {minimum_weeks} weeks."
            )
            suggestions.append(
                f"Increase to at least {minimum_weeks} weeks, or accept a lighter target scope."
            )
        elif requested_weeks < suitable_weeks:
            adjustment = "very_tight"
            zone = "minimum"
            warnings.append(
                f"Your {requested_weeks} weeks is above minimum but below the suitable range ({suitable_weeks} weeks)."
            )
            suggestions.append(
                "This falls in the minimum band. Focus should stay on the selected skills first."
            )
        elif requested_weeks <= maximum_weeks:
            adjustment = "ok"
            zone = "suitable"
            suggestions.append(
                "This falls in the suitable band and should support a balanced plan."
            )
        else:
            adjustment = "excessive"
            zone = "above_maximum"
            suggestions.append(
                f"Your {requested_weeks} weeks is above the maximum guidance ({maximum_weeks} weeks). You can safely expand depth or raise some targets."
            )

        if request.available_hours_per_week <= 3:
            warnings.append(
                f"Only {request.available_hours_per_week} hours/week is light. Make sure these hours are focused."
            )

        suggested_targets = []
        confirmed_learning_targets = []

        selected_skill_ids_set = set(selected_skill_ids)

        for gap in skill_gaps:
            skill_id = gap.get("skill_id")
            if skill_id is None:
                continue

            current_level = (gap.get("current_level") or "none").lower()
            required_level = (gap.get("required_level") or "beginner").lower()
            importance_weight = int(gap.get("importance_weight", 3) or 3)
            required_weeks = int(gap.get("required_weeks", 4) or 4)
            is_core = bool(gap.get("is_core", True))
            status = gap.get("status")

            target_level = current_level
            reason = "No target change."
            learning_mode = "level_up"

            if zone in ("below_minimum", "minimum"):
                if skill_id not in selected_skill_ids_set:
                    continue

                if current_level == "none":
                    target_level = "beginner"
                    reason = "Minimum scope: selected missing skill starts from fundamentals."
                    learning_mode = "learn_from_scratch"
                elif current_level == "beginner":
                    target_level = "intermediate"
                    reason = "Minimum scope: selected beginner skill should reach intermediate."
                else:
                    target_level = current_level
                    reason = "Current level is already enough for the minimum scope."

            elif zone == "suitable":
                include = (skill_id in selected_skill_ids_set) or (
                    status in ("has", "partial") and is_core
                )
                if not include:
                    continue

                if current_level == "none":
                    target_level = "beginner" if requested_weeks < suitable_weeks else "intermediate"
                    learning_mode = "learn_from_scratch"
                elif current_level == "beginner":
                    target_level = "intermediate"
                elif current_level == "intermediate":
                    target_level = "advanced" if requested_weeks > suitable_weeks + 4 else "intermediate"
                else:
                    target_level = "advanced"

                if skill_id in selected_skill_ids_set:
                    reason = "Suitable scope: selected skills progress realistically."
                else:
                    reason = "Suitable scope: current core skills are reinforced."

            else:
                include = (skill_id in selected_skill_ids_set) or (LEVEL_VALUES.get(current_level, 0) >= 1)
                if not include:
                    continue

                if current_level == "none":
                    target_level = "intermediate"
                    learning_mode = "learn_from_scratch"
                elif current_level == "beginner":
                    target_level = "advanced" if request.available_hours_per_week >= 10 else "intermediate"
                elif current_level == "intermediate":
                    target_level = "advanced"
                else:
                    target_level = "advanced"

                if skill_id in selected_skill_ids_set:
                    reason = "Extended scope: selected skills can go deeper."
                else:
                    reason = "Extended scope: current skills can also be upgraded."

            suggested_targets.append({
                "skill_id": skill_id,
                "skill_name": gap.get("skill_name"),
                "current_level": current_level,
                "suggested_target_level": target_level,
                "target_reason": reason,
                "learning_mode": learning_mode,
                "status": status,
                "is_core": is_core,
                "selected_by_user": skill_id in selected_skill_ids_set,
            })

            current_value = LEVEL_VALUES.get(current_level, 0)
            target_value = LEVEL_VALUES.get(target_level, 1)

            if target_value <= current_value:
                continue

            confirmed_learning_targets.append({
                "skill_id": skill_id,
                "skill_name": gap.get("skill_name"),
                "current_level": current_level,
                "target_level": target_level,
                "required_level": required_level,
                "required_weeks": required_weeks,
                "importance_weight": importance_weight,
                "learning_mode": learning_mode,
                "status": status,
                "is_core": is_core,
                "selected_by_user": skill_id in selected_skill_ids_set,
            })

        if not confirmed_learning_targets:
            raise HTTPException(
                status_code=400,
                detail="No valid learning targets found after time confirmation."
            )

        realism = {
            "is_realistic": is_realistic,
            "adjustment": adjustment,
            "zone": zone,
            "requested_weeks": requested_weeks,
            "available_hours_per_week": request.available_hours_per_week,
            "study_intensity": guidance.study_intensity,
            "calculated_minimum_weeks": minimum_weeks,
            "calculated_suitable_weeks": suitable_weeks,
            "calculated_maximum_weeks": maximum_weeks,
            "warnings": warnings,
            "suggestions": suggestions,
        }

        confirmed_level_values = [
            LEVEL_VALUES.get((target.get("current_level") or "none").lower(), 0)
            for target in confirmed_learning_targets
        ]

        confirmed_overall_level = "beginner"
        if confirmed_level_values:
            avg_level_value = sum(confirmed_level_values) / len(confirmed_level_values)
            if avg_level_value >= 2.5:
                confirmed_overall_level = "advanced"
            elif avg_level_value >= 1.5:
                confirmed_overall_level = "intermediate"
            elif avg_level_value > 0:
                confirmed_overall_level = "beginner"
            else:
                confirmed_overall_level = "none"

        updated_cache = {
            **cached,
            "available_hours_per_week": request.available_hours_per_week,
            "confirmed_requested_weeks": requested_weeks,
            "suggested_targets": suggested_targets,
            "confirmed_learning_targets": confirmed_learning_targets,
            "detected_skill_levels": detected_skill_levels,
            "level_used": confirmed_overall_level,
            "realism": realism,
            "time_confirmed": True,
            "confirmed": True,
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
            "detected_level": detected_level,
            "available_hours_per_week": request.available_hours_per_week,
            "requested_weeks": requested_weeks,
            "selected_skill_ids": selected_skill_ids,
            "suggested_targets": suggested_targets,
            "confirmed_learning_targets": confirmed_learning_targets,
            "realism": realism,
            "time_guidance": {
                "minimum_weeks": minimum_weeks,
                "suitable_weeks": suitable_weeks,
                "maximum_weeks": maximum_weeks,
                "study_intensity": guidance.study_intensity,
                "minimum_weeks_breakdown": guidance.minimum_weeks_breakdown,
                "suitable_weeks_breakdown": guidance.suitable_weeks_breakdown,
                "maximum_weeks_breakdown": guidance.maximum_weeks_breakdown,
            },
            "reviewable_skills": reviewable_skills,
            "skill_gaps": skill_gaps,
            "fit_analysis": cached.get("fit_analysis", {}),
            "metadata": {
                "match_percentage": cached.get("match_percentage", 0),
                "matching_method": cached.get("matching_method", "unknown"),
                "analysis_quality": cached.get("analysis_quality", 0),
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Confirm time failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate-plan")
async def generate_plan(
    request: PlanGenerateRequest,
    repo: CareerRepository = Depends(get_repository),
):
    try:
        cached = await repo.get_analysis_cache(cv_id=request.cv_id, track_id=request.track_id)

        if not cached:
            raise HTTPException(
                status_code=400,
                detail="No analysis found. Call /analyze then /confirm-time first."
            )

        confirmed_learning_targets = cached.get("confirmed_learning_targets", []) or []
        if not confirmed_learning_targets:
            raise HTTPException(
                status_code=400,
                detail="No confirmed learning targets found. Call /confirm-time first."
            )

        confirmed_user_level = cached.get("level_used")

        analysis_service = CareerAnalysisService(repository=repo)
        service = PlanGenerationService(repository=repo, analysis_service=analysis_service)

        result = await service.generate_plan(
            cv_id=request.cv_id,
            track_id=request.track_id,
            duration_weeks=request.duration_weeks,
            available_hours_per_week=request.available_hours_per_week,
            user_level=confirmed_user_level,
            requested_weeks=request.duration_weeks
        )

        updated_cache = {
            **cached,
            "draft_plan": result,
            "draft_plan_updated_at": str(__import__("datetime").datetime.now()),
            "draft_generation_mode": result.get("planning_mode"),
        }

        await repo.save_analysis_cache(
            cv_id=request.cv_id,
            track_id=request.track_id,
            analysis_data=updated_cache
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
    repo: CareerRepository = Depends(get_repository),
):
    try:
        service = PlanRegenerationService()

        result = await service.regenerate_plan(
            previous_plan=request.previous_plan,
            feedback_intents=request.feedback_intents,
            regeneration_mode=request.regeneration_mode
        )

        if request.cv_id and request.track_id:
            cached = await repo.get_analysis_cache(cv_id=request.cv_id, track_id=request.track_id)
            if cached:
                updated_cache = {
                    **cached,
                    "draft_plan": result,
                    "draft_plan_updated_at": str(__import__("datetime").datetime.now()),
                    "draft_generation_mode": result.get("planning_mode", "regenerated_plan"),
                }
                await repo.save_analysis_cache(
                    cv_id=request.cv_id,
                    track_id=request.track_id,
                    analysis_data=updated_cache
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
    repo: CareerRepository = Depends(get_repository),
):
    try:
        cached = await repo.get_analysis_cache(
            cv_id=request.cv_id,
            track_id=request.track_id
        )

        if not cached:
            raise HTTPException(
                status_code=400,
                detail="No cached analysis found. Call /analyze first."
            )

        draft_plan = cached.get("draft_plan")
        if not draft_plan:
            raise HTTPException(
                status_code=400,
                detail="No draft plan found. Call /generate-plan first."
            )

        available_hours_per_week = (
            draft_plan.get("available_hours_per_week")
            or cached.get("available_hours_per_week")
        )

        duration_weeks = draft_plan.get("duration_weeks")

        if not duration_weeks:
            raise HTTPException(
                status_code=400,
                detail="Draft plan duration is missing."
            )

        weekly_breakdown = draft_plan.get("weekly_breakdown", []) or []
        if not weekly_breakdown:
            raise HTTPException(
                status_code=400,
                detail="Draft plan weekly_breakdown is missing."
            )

        result = await service.save_plan(
            user_id=request.user_id,
            cv_id=request.cv_id,
            track_id=request.track_id,
            duration_weeks=duration_weeks,
            plan_data={
                "available_hours_per_week": available_hours_per_week,
                "weekly_breakdown": weekly_breakdown,
                "planning_mode": draft_plan.get("planning_mode"),
                "study_intensity": draft_plan.get("study_intensity"),
                "plan_summary": draft_plan.get("plan_summary"),
                "improvement_summary": draft_plan.get("improvement_summary"),
                "generation_metadata": draft_plan.get("generation_metadata", {}),
                "used_learning_targets": draft_plan.get("used_learning_targets", []),
                "deferred_learning_targets": draft_plan.get("deferred_learning_targets", []),
            },
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
    
     
@router.post("/benchmark-generate-plan")
async def benchmark_generate_plan(
    request: PlanGenerateRequest,
    repo: CareerRepository = Depends(get_repository),
    analysis_service: CareerAnalysisService = Depends(get_analysis_service),
):
    from features.career_builder.services.plan_generation_benchmark import PlanGenerationBenchmark

    service = PlanGenerationService(
        repository=repo,
        analysis_service=analysis_service,
    )

    benchmark = PlanGenerationBenchmark(service)

    return await benchmark.run_benchmark(
        cv_id=request.cv_id,
        track_id=request.track_id,
        duration_weeks=request.duration_weeks,
        available_hours_per_week=request.available_hours_per_week,
        user_level=request.user_level,
    )