import re
from fastapi import APIRouter, HTTPException, UploadFile
from fastapi import Depends, Request

from shared.helpers.file_validation import FileValidator
from features.cv_optimization.services.text_extractor import TextExtractor
from features.cv_optimization.services.cv_analyser import CVAnalyser, get_cv_analyser
from shared.providers.storage.cloudinary_provider import CloudinaryStorageProvider
router = APIRouter(prefix="/cv_optimization", tags=["Test CV Optimization"])

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


@router.post("/test/")
async def test_text_extractor(file: UploadFile):
    text_extractor = TextExtractor()
    extracted_content = await text_extractor.extract_text_with_links_no_duplicate(file)

    print("Extracted text:", extracted_content)
    return {"extracted_content": extracted_content}

@router.post("/upload/")
async def upload_cv(file: UploadFile):
    userId = "test_user_id"  # In a real application, get this from the authenticated user context
    cleaned_filename = FileValidator.clean_filename(file.filename)
    response = await CloudinaryStorageProvider().upload_file(file,cleaned_filename, userId,"cv")
    return {"upload_response": response}