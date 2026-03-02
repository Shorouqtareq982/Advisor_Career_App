import logging
from typing import Optional
from fastapi import UploadFile, HTTPException, status
from features.cv_optimization.schemas import JobData, CVData
from shared.helpers.file_validation import FileValidator
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from shared.providers.supabase import db
from shared.helpers.document_parser import DocumentParser
from shared.providers.storage import CloudinaryProvider
from ..models import CVOptimizationRequest, JobPosting, CVOptimizationReport
from ..schemas import ATSAnalysisResponse
from ..prompts import CV_ANALYST

logger = logging.getLogger(__name__)

"""
TODO:
[x] change cloudinay upload to the new version
[x] Fix UserId to be dynamic and extracted from JWT token instead of hardcoded value.
[x] Implement authentication and authorization to ensure that only authorized users can access the CV analysis functionality.
[x] Fix the file url not working
[x] Fix extracted urls from CV not being parsed correctly in the analysis.
[x] Add more detailed error messages and logging for debugging and monitoring purposes.
[x] Break down the analyze_cv method into smaller helper methods for better readability and maintainability.
[x] Implement try-except blocks around critical operations to catch and log exceptions.
[ ] Test the CV analysis process with various CV formats and job descriptions to ensure robustness and accuracy.
[ ] Consider adding a retry mechanism for transient errors, especially for file uploads and LLM interactions.
[ ] Implement rate limiting or queuing for CV analysis requests to manage load and ensure fair usage.
[ ] Update all used methods to be asynchronous to improve performance and scalability.
"""

class CVAnalyser:
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
        self.parser = DocumentParser(self.llm)
        self.storage_provider = CloudinaryProvider()

    async def analyze_cv(self, user_id: str, cv_file: UploadFile, jd_text: Optional[str] = None) -> dict:
        """Main orchestration method for CV analysis."""
        try:
            logger.info(f"Starting CV analysis for user: {user_id}")
            
            # Step 1: Validate and upload CV
            file_url = await self._validate_and_upload_cv(user_id, cv_file)
            
            # Step 2: Parse CV and JD
            parsed_cv_text, parsed_cv, parsed_jd = await self._parse_cv_and_jd(cv_file, jd_text)
            
            # Step 3: Save to database
            cv_id, jd_id, request_id = await self._save_parsed_data(
                user_id, file_url, parsed_cv_text, parsed_cv, jd_text, parsed_jd
            )
            
            # Step 4: Perform analysis
            analysis_results = self._perform_analysis(parsed_cv, parsed_jd)
            
            # Step 5: Save report
            await self._save_optimization_report(request_id, cv_id, jd_id, analysis_results)
            
            logger.info(f"CV analysis completed successfully for user: {user_id}, request_id: {request_id}")
            return analysis_results
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"CV analysis failed for user {user_id}: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"CV analysis failed: {str(e)}"
            )

    async def _validate_and_upload_cv(self, user_id: str, cv_file: UploadFile) -> str:
        """Validate CV file and upload to storage."""
        try:
            logger.debug(f"Validating CV file: {cv_file.filename}")
            
            # Validate CV file
            is_valid, signal = FileValidator.validate_cv_file(cv_file)
            if not is_valid:
                logger.error(f"CV file validation failed: {signal}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid file provided for CV analysis. {signal}"
                )
            
            # Clean filename
            cleaned_filename = FileValidator.clean_filename(cv_file.filename, remove_extension=True)
            logger.debug(f"Cleaned filename: {cleaned_filename}")
            
            # Upload file to storage
            logger.debug(f"Uploading CV file to storage for user: {user_id}")
            uploaded_file = self.storage_provider.upload_file(cv_file.file, f"cv_{cleaned_filename}", folder=user_id)
            file_url = uploaded_file.get("url")
            
            if not file_url:
                logger.error("Storage upload returned no URL")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to upload CV file to storage."
                )
            
            logger.info(f"CV file uploaded successfully: {file_url}")
            return file_url
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"CV file validation/upload failed: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"CV file validation/upload failed: {str(e)}"
            )

    async def _parse_cv_and_jd(self, cv_file: UploadFile, jd_text: Optional[str]) -> tuple:
        """Parse CV and job description files."""
        try:
            logger.debug(f"Starting to parse CV file: {cv_file.filename}")
            parsed_cv_text, parsed_cv = await self.parser.parse_cv(cv_file)
            logger.info(f"CV parsed successfully")
            
            parsed_jd = None
            if jd_text:
                logger.debug(f"Parsing job description")
                parsed_jd = self.parser.parse_job_description(jd_text)
                logger.info(f"Job description parsed successfully")
            else:
                logger.debug(f"No job description provided")
            
            return parsed_cv_text, parsed_cv, parsed_jd
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"CV/JD parsing failed: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"CV/JD parsing failed: {str(e)}"
            )

    async def _save_parsed_data(
        self, user_id: str, file_url: str, parsed_cv_text: str, 
        parsed_cv: CVData, jd_text: Optional[str], parsed_jd: Optional[dict]
    ) -> tuple:
        """Save CV, JD, and optimization request to database."""
        try:
            logger.debug(f"Converting parsed CV to JSON for user: {user_id}")
            # Convert parsed CV to dict if needed
            parsed_cv_json = (
                parsed_cv.model_dump(mode="json", exclude_none=True)
                if isinstance(parsed_cv, CVData)
                else parsed_cv
            )

            # Save CV and JD metadata
            logger.debug(f"Uploading CV to database for user: {user_id}")
            created_cv = db.upload_cv(user_id, file_url, parsed_cv_text, parsed_cv_json)
            logger.info(f"CV saved to database with cv_id: {created_cv['cv_id']}")
            
            jd_id = None
            if jd_text and parsed_jd:
                logger.debug(f"Saving job posting to database")
                created_jd = db.save_job_posting(
                    JobPosting(raw_text=jd_text, source_type="text", parsed_data=parsed_jd).model_dump(
                        mode="json", exclude_none=True
                    )
                )
                jd_id = created_jd["job_id"]
                logger.info(f"Job posting saved to database with job_id: {jd_id}")
            
            # Create optimization request
            logger.debug(f"Creating optimization request for user: {user_id}")
            optimization_request = db.request_cv_optimization(
                user_id, created_cv["cv_id"], jd_id
            )
            logger.info(f"Optimization request created with request_id: {optimization_request['request_id']}")
            
            return created_cv["cv_id"], jd_id, optimization_request["request_id"]
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database operation failed while saving parsed data: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Database operation failed: {str(e)}"
            )

    def _perform_analysis(self, parsed_cv: dict, parsed_jd: Optional[dict]) -> dict:
        """Perform ATS analysis using LLM."""
        try:
            logger.debug(f"Preparing analysis prompt")
            job_description = parsed_jd if parsed_jd else "No job description provided"
            
            logger.debug(f"Sending request to LLM for CV analysis")
            results = self.llm.get_response(
                prompt=CV_ANALYST.format(cv_text=parsed_cv, job_description=job_description),
                need_json_output=True,
                schema=ATSAnalysisResponse
            )

            if not results:
                logger.error("LLM returned empty response for CV analysis")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="LLM returned empty response for CV analysis."
                )
            
            logger.info(f"LLM analysis completed successfully")
            return results.dict() if isinstance(results, ATSAnalysisResponse) else results
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"LLM analysis failed: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"LLM analysis failed: {str(e)}"
            )

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

        db.update_optimization_request_status(request_id, "completed")


def get_cv_analyser():
    return CVAnalyser()
