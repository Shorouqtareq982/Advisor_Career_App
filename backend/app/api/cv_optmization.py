from fastapi import APIRouter, HTTPException, UploadFile, Form
from fastapi import Depends, Request
from fastapi.security import HTTPBearer
from features.cv_optimization.services import get_optimization_report_service, OptmizationReportService, CVAnalyser, get_cv_analyser
router = APIRouter(prefix="/cv_optimization", tags=["CV Optimization"],dependencies=[Depends(HTTPBearer())])

@router.post("/analyze")
async def analyze_cv(
    request: Request,
    cv_file: UploadFile,
    jd_text: str = Form(None),
    cv_analyser: CVAnalyser = Depends(get_cv_analyser),
):
    user = request.state.user
    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")
    userId = user["sub"]
    analysis_results = await cv_analyser.analyze_cv(userId, cv_file, jd_text)
    return analysis_results

@router.post("/analyze/{cv_id}")
async def analyze_saved_cv(
    request: Request,
    cv_id: str,
    jd_text: str = Form(None),
    cv_analyser: CVAnalyser = Depends(get_cv_analyser),
):
    user = request.state.user
    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")
    userId = user["sub"]
    analysis_results = await cv_analyser.analyze_saved_cv(userId, cv_id, jd_text)
    return analysis_results

@router.get("/report/{report_id}")
async def get_report(report_id: str, report_service: OptmizationReportService = Depends(get_optimization_report_service)):
    report = await report_service.get_report_by_id(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return report

@router.get("/reports")
async def get_user_reports(request: Request, report_service: OptmizationReportService = Depends(get_optimization_report_service)):
    user = request.state.user
    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")
    userId = user["sub"]
    reports = await report_service.get_reports_by_user(userId)
    return reports

@router.delete("/report/{report_id}")
async def delete_report(report_id: str, report_service: OptmizationReportService = Depends(get_optimization_report_service)):
    try:
        await report_service.delete_report(report_id)
        return {"detail": "Report deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
