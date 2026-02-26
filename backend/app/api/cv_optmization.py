from fastapi import APIRouter, HTTPException, UploadFile
from fastapi import Depends, Request
from fastapi.security import HTTPBearer
from features.cv_optimization.services.cv_analyser import CVAnalyser, get_cv_analyser
router = APIRouter(prefix="/cv_optimization", tags=["CV Optimization"],dependencies=[Depends(HTTPBearer())])

@router.post("/analyze")
async def analyze_cv(
    request: Request,
    cv_file: UploadFile,
    jd_text: str,
    cv_analyser: CVAnalyser = Depends(get_cv_analyser),
):
    user = request.state.user
    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")
    userId = user["sub"]
    analysis_results = await cv_analyser.analyze_cv(userId, cv_file, jd_text)
    return analysis_results

