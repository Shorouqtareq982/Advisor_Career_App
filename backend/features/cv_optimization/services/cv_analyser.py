from fastapi import Depends, UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile
from features.cv_optimization.schemas import JobData, CVData
from shared.helpers.file_validation import FileValidator
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from shared.providers.storage.cloudinary_provider import CloudinaryStorageProvider
from shared.providers.supabase import db
from shared.helpers.document_parser import DocumentParser
from ..models import CVOptimizationRequest, JobPosting, CVOptimizationReport
from ..schemas import ATSAnalysisResponse
from ..prompts import CV_ANALYST

"""
TODO:
[ ] change cloudinay upload to the new version
[x] Fix UserId to be dynamic and extracted from JWT token instead of hardcoded value.
[x] Implement authentication and authorization to ensure that only authorized users can access the CV analysis functionality.
[x] Fix the file url not working
[x] Fix extracted urls from CV not being parsed correctly in the analysis.
[ ] Test the CV analysis process with various CV formats and job descriptions to ensure robustness and accuracy.
[ ] Add more detailed error messages and logging for debugging and monitoring purposes.
[ ] Implement try-except blocks around critical operations to catch and log exceptions.
[ ] Consider adding a retry mechanism for transient errors, especially for file uploads and LLM interactions.
[x] Break down the analyze_cv method into smaller helper methods for better readability and maintainability.
"""

class CVAnalyser:
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
        self.parser = DocumentParser(self.llm)
        self.storage_provider = CloudinaryStorageProvider()

    async def analyze_cv(self, user_id: str, cv_file: UploadFile, jd_text: str) -> dict:
        """Main orchestration method for CV analysis."""
        try:
            # Step 1: Validate and upload CV
            file_url = await self._validate_and_upload_cv(user_id, cv_file)
            
            # Step 2: Parse CV and JD
            parsed_cv_text, parsed_cv, parsed_jd = await self._parse_cv_and_jd(cv_file, jd_text)
            
            # Step 3: Save to database
            cv_id, jd_id, request_id = await self._save_parsed_data(
                user_id, file_url, parsed_cv_text, parsed_cv, parsed_jd
            )
            
            # Step 4: Perform analysis
            analysis_results = self._perform_analysis(parsed_cv, parsed_jd)
            
            # Step 5: Save report
            await self._save_optimization_report(request_id, cv_id, jd_id, analysis_results)
            
            return analysis_results
        except Exception as e:
            print(f"CV analysis failed: {str(e)}")
            return {"error": str(e)}

    async def _validate_and_upload_cv(self, user_id: str, cv_file: UploadFile) -> str:
        """Validate CV file and upload to storage."""
        # Validate CV file
        is_valid, signal = FileValidator.validate_cv_file(cv_file)
        if not is_valid:
            raise ValueError(f"Invalid file provided for CV analysis. {signal}")
        
        # Clean filename
        cleaned_filename = FileValidator.clean_filename(cv_file.filename, remove_extension=True)
        
        # Upload file to storage
        uploaded_file = await self.storage_provider.upload_file(
            cv_file, cleaned_filename, user_id, fileType="cv"
        )
        file_url = uploaded_file.get("secure_url")
        
        if not file_url:
            raise RuntimeError("Failed to upload CV file to storage.")
        
        return file_url

    async def _parse_cv_and_jd(self, cv_file: UploadFile, jd_text: str) -> tuple:
        """Parse CV and job description files."""
        parsed_cv_text, parsed_cv = self.parser.parse_cv(cv_file)
        parsed_jd = self.parser.parse_job_description(jd_text)
        
        return parsed_cv_text, parsed_cv, parsed_jd

    async def _save_parsed_data(
        self, user_id: str, file_url: str, parsed_cv_text: str, 
        parsed_cv: CVData, parsed_jd: dict
    ) -> tuple:
        """Save CV, JD, and optimization request to database."""
        # Save CV and JD metadata
        created_cv = db.upload_cv(user_id, file_url)
        created_jd = db.save_job_posting(
            JobPosting(raw_text=parsed_jd, source_type="text").model_dump(
                mode="json", exclude_none=True
            )
        )
        
        # Create optimization request
        optimization_request = db.request_cv_optimization(
            user_id, created_cv["cv_id"], created_jd["job_id"]
        )
        
        # Convert parsed CV to dict if needed
        parsed_cv_json = (
            parsed_cv.model_dump(mode="json", exclude_none=True)
            if isinstance(parsed_cv, CVData)
            else parsed_cv
        )
        
        # Update CV and JD with parsed content
        db.update_cv(
            created_cv["cv_id"],
            {"text_content": parsed_cv_text, "parsed_content": parsed_cv_json}
        )
        db.update_job_posting(created_jd["job_id"], {"parsed_data": parsed_jd})
        
        return created_cv["cv_id"], created_jd["job_id"], optimization_request["request_id"]

    def _perform_analysis(self, parsed_cv: dict, parsed_jd: dict) -> dict:
        """Perform ATS analysis using LLM."""
        results = self.llm.get_response(
            prompt=CV_ANALYST.format(cv_text=parsed_cv, job_description=parsed_jd),
            need_json_output=True,
            schema=ATSAnalysisResponse
        )

        if not results:
            raise RuntimeError("LLM returned empty response for CV analysis.")
        
        return results.dict() if isinstance(results, ATSAnalysisResponse) else results

    async def _save_optimization_report(
        self, request_id: str, cv_id: str, jd_id: str, analysis_results: dict
    ) -> None:
        """Save optimization report to database."""
        report = CVOptimizationReport(
            request_id=request_id,
            cv_id=cv_id,
            job_posting_id=jd_id,
            analysis=analysis_results
        )
        db.save_cv_optimization_report(
            report.model_dump(mode="json", exclude_none=True)
        )


def get_cv_analyser():
    return CVAnalyser()
