from fastapi import Depends, UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile
from features.cv_optimization.schemas.job_data_schema import JobData
from features.cv_optimization.schemas.cv_data_schema import CVData
from shared.helpers.file_validation import FileValidator
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from shared.providers.storage.cloudinarytest import CloudinaryStorageProvider
from shared.providers.supabase import db
from .document_parser import DocumentParser
from ..models import CVOptimizationRequest, JobPosting, CVOptimizationReport
from ..schemas import ATSAnalysisResponse
from ..prompts import CV_ANALYST

"""
TODO:
[ ] Fix UserId to be dynamic and extracted from JWT token instead of hardcoded value.
[ ] Fix the file url not working
[ ] Fix extracted urls from CV not being parsed correctly in the analysis.
[ ] Implement authentication and authorization to ensure that only authorized users can access the CV analysis functionality.
[ ] Test the CV analysis process with various CV formats and job descriptions to ensure robustness and accuracy.
[ ] Add more detailed error messages and logging for debugging and monitoring purposes.
[ ] Implement try-except blocks around critical operations to catch and log exceptions.
[ ] Consider adding a retry mechanism for transient errors, especially for file uploads and LLM interactions.

"""

class CVAnalyser:
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
        self.parser = DocumentParser(self.llm)
        self.storage_provider = CloudinaryStorageProvider()

    async def analyze_cv(self, cv_file: UploadFile, jd_text: str):

        # #TODO: get user id from jwt 
        user_id = "3e2e72f7-e53b-4eed-9487-b9d8f23da63d"
        # Validate CV File
        isvalid, signal = FileValidator.validate_cv_file(cv_file)
        if not isvalid:
            print(f"Invalid file provided for CV analysis.{signal}")
            return {f"error": {signal}}
        
        #clean filename
        cleaned_filename = FileValidator.clean_filename(cv_file.filename)
        
        #upload file to storage and get URL
        uploaded_file = await self.storage_provider.upload_file(cv_file, cleaned_filename,user_id,fileType="cv")
        fileURl = uploaded_file.get("secure_url")
        if not fileURl:
            print("Failed to upload CV file to storage.")
            return {"error": "File upload failed"}
        
        #save file metadata and jd to database and get CV and JD ID
        created_cv = db.upload_cv(user_id,fileURl)
        created_jd = db.save_job_posting(JobPosting(raw_text=jd_text,source_type="text").model_dump(mode="json",exclude_none=True))
        optmization_request = db.request_cv_optimization(user_id, created_cv["cv_id"], created_jd["job_id"])

        # Parse the CV file to extract relevant information
        parsed_cv_text,parsed_cv = self.parser.parse_cv(cv_file)
        parsed_jd = self.parser.parse_job_description(jd_text)

        parsed_cv_json = parsed_cv.model_dump(mode="json",exclude_none=True) if isinstance(parsed_cv, CVData) else parsed_cv

        #save parsed CV and JD data to database linked to the request ID
        db.update_cv(created_cv["cv_id"], {"text_content": parsed_cv_text, "parsed_content": parsed_cv_json})
        db.update_job_posting(created_jd["job_id"], {"parsed_data": parsed_jd})
        # Perform analysis on the parsed data
        analysis_results = self._perform_analysis(parsed_cv, parsed_jd)

        #save analysis results to database linked to the request ID and generate report ID
        report = CVOptimizationReport(
            request_id=optmization_request["request_id"],
            cv_id=created_cv["cv_id"],
            job_posting_id=created_jd["job_id"],
            analysis=analysis_results
        )
        db.save_cv_optimization_report(report.model_dump(mode="json",exclude_none=True))
        return analysis_results

    def _perform_analysis(self, parsed_cv: dict, parsed_jd: dict) -> dict:
        results = self.llm.get_response(
            prompt=CV_ANALYST.format(cv_text=parsed_cv, job_description=parsed_jd),
            need_json_output=True,
            schema=ATSAnalysisResponse
        )

        if not results:
            print("LLM returned empty response for CV analysis.")
            return {}
        
        return results.dict() if isinstance(results, ATSAnalysisResponse) else results

def get_cv_analyser():
    return CVAnalyser()
