"""
Career Builder Router ✅
"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from typing import Optional
from uuid import UUID
from pydantic import BaseModel
import logging

from features.career_builder.services.career_analysis_service import CareerAnalysisService
from features.career_builder.ml_models.realism_checker import RealismChecker
from features.career_builder.repositories.career_repository import CareerRepository
from shared.helpers.document_parser import DocumentParser
from shared.providers.supabase.database import db as supabase_db  # ✅ استيراد كائن db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/career", tags=["career-builder"])


class ConfirmRequest(BaseModel):
    cv_id: UUID
    track_id: int
    requested_weeks: int
    user_level: Optional[str] = None


# =====================================================
# ENDPOINT 1: /analyze
# =====================================================
@router.post("/analyze")
async def analyze_cv(
    cv_file:  UploadFile = File(...),
    track_id: int        = Form(...),
):
    """
    تحميل وتحليل السيرة الذاتية ومقارنتها بمسار وظيفي محدد.
    """
    try:
        # ✅ إنشاء repository مع تمرير db مباشرة (بدون keyword)
        repo   = CareerRepository(supabase_db)
        parser = DocumentParser()

        # استخراج النص والبيانات المنظمة من ملف PDF
        cv_text, parsed_cv = await parser.parse_cv(file=cv_file)

        if not cv_text:
            raise HTTPException(
                status_code=400,
                detail="فشل استخراج النص من الـ CV"
            )

        # حفظ الـ CV في قاعدة البيانات
        cv_id = await repo.save_cv(
            file_url=cv_file.filename,      # اسم الملف أو الرابط
            text_content=cv_text,
            parsed_content=parsed_cv or {}
        )

        if not cv_id:
            raise HTTPException(status_code=500, detail="فشل حفظ الـ CV")

        # تحليل المهارات والمقارنة مع المسار
        service  = CareerAnalysisService(repository=repo)
        analysis = await service.analyze_cv_for_track(
            cv_id=cv_id,
            track_id=track_id,
            requested_weeks=0,               # غير مستخدم في التحليل حالياً
        )

        # تخزين نتيجة التحليل في الكاش
        await repo.save_analysis_cache(
            cv_id=cv_id,
            track_id=track_id,
            analysis_data={
                "missing_skills":   analysis.missing_skills,
                "matched_skills":   analysis.matched_skills,
                "match_percentage": analysis.match_percentage,
                "matching_method":  analysis.matching_method,
                "detected_level":   analysis.detected_level,
                "level_confidence": analysis.level_confidence,
                "level_reasoning":  analysis.level_reasoning,
                "track_name":       analysis.track_name,
                "cv_skills":        analysis.cv_skills,
                "analysis_quality": analysis.analysis_quality,
            }
        )

        # تجهيز الرد
        return {
            "status":   "success",
            "cv_id":    str(cv_id),
            "track_id": track_id,

            "track_name":        analysis.track_name,
            "detected_level":    analysis.detected_level,
            "level_confidence":  round(analysis.level_confidence, 2),
            "level_reasoning":   analysis.level_reasoning,

            "missing_skills": [
                {
                    "skill_name":     s['skill_name'],
                    "category":       s.get('category', 'General'),
                    "importance":     s.get('importance', 3),
                    "duration_weeks": s.get('duration_weeks', 4),
                }
                for s in analysis.missing_skills
            ],

            "matched_skills": [
                {
                    "skill_name": s['skill_name'],
                    "category":   s.get('category', 'General'),
                }
                for s in analysis.matched_skills
            ],

            "summary": {
                "total_required":   len(analysis.missing_skills) + len(analysis.matched_skills),
                "already_have":     len(analysis.matched_skills),
                "need_to_learn":    len(analysis.missing_skills),
                "match_percentage": analysis.match_percentage,
                "matching_method":  analysis.matching_method,
            }
        }

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# =====================================================
# ENDPOINT 2: /confirm
# =====================================================
@router.post("/confirm")
async def confirm_duration(request: ConfirmRequest):
    """
    تأكيد المدة المختارة بعد عرض التحليل، مع التحقق من واقعيتها.
    """
    try:
        # ✅ نفس الشيء هنا: تمرير db مباشرة
        repo   = CareerRepository(supabase_db)
        cached = await repo.get_analysis_cache(
            cv_id=request.cv_id,
            track_id=request.track_id
        )
        if not cached:
            raise HTTPException(
                status_code=400,
                detail="لازم تعمل /analyze الأول قبل /confirm"
            )

        # تحديد المستوى (من المستخدم إن وجد، وإلا المستوى المُكتشف)
        level = (
            request.user_level
            if request.user_level in ('beginner', 'intermediate', 'advanced')
            else cached['detected_level']
        )

        checker = RealismChecker()
        realism = checker.check_realism(
            requested_weeks=request.requested_weeks,
            missing_skills=cached['missing_skills'],
            level=level
        )

        return {
            "status":     "success",
            "cv_id":      str(request.cv_id),
            "track_id":   request.track_id,
            "track_name": cached['track_name'],

            "detected_level":   cached['detected_level'],
            "level_used":       level,
            "level_confidence": round(cached['level_confidence'], 2),

            "realism": {
                "requested_weeks":   realism.requested_weeks,
                "safe_min_weeks":    realism.safe_min_weeks,
                "recommended_weeks": realism.recommended_weeks,
                "is_below_safe":     realism.is_below_safe,
                "adjustment":        realism.adjustment,
                "warning":           realism.warning,
            },

            "missing_skills": cached['missing_skills'],
            "matched_skills": cached['matched_skills'],

            "metadata": {
                "match_percentage": cached['match_percentage'],
                "matching_method":  cached['matching_method'],
                "analysis_quality": cached['analysis_quality'],
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Confirm failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))