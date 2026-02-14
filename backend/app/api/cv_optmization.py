from fastapi import APIRouter, UploadFile
from fastapi import Depends

from features.cv_optimization.services.cv_analyser import CVAnalyser, get_cv_analyser

router = APIRouter(prefix="/cv_optmization", tags=["Test CV Optimization"])

@router.post("/analyze")
async def analyze_cv(cv_file: UploadFile, jd_text: str, cv_analyser: CVAnalyser = Depends(get_cv_analyser)):
    analysis_results = await cv_analyser.analyze_cv(cv_file, jd_text)
    return analysis_results
