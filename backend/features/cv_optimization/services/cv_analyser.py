import asyncio
import logging
from typing import Optional

from fastapi import HTTPException, UploadFile, status

from features.cv_optimization.repositories.cv_optmization_repo import CVOptRepository
from features.cv_optimization.schemas import CVData, JobData
from shared.helpers.document_parser import DocumentParser
from shared.helpers.file_validation import FileValidator
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from shared.providers.storage import CloudinaryProvider

from ..models import CVOptimizationRequest, CVOptimizationReport, JobPosting
from ..prompts import CV_ANALYST
from ..schemas import ATSAnalysisResponse

logger = logging.getLogger(__name__)

class CVAnalyser:
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
        self.parser = DocumentParser(self.llm)
        self.storage_provider = CloudinaryProvider()
        self.repo = CVOptRepository()

    # ========================
    # PUBLIC METHODS
    # ========================

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
            analysis_results = await self._perform_analysis(parsed_cv, parsed_jd)
            
            # Step 5: Save report
            final_report = await self._save_optimization_report(request_id, cv_id, jd_id, analysis_results)
            
            logger.info(f"CV analysis completed successfully for user: {user_id}, request_id: {request_id}")
            return final_report
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"CV analysis failed for user {user_id}: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"CV analysis failed: {str(e)}"
            )

    async def analyze_saved_cv(self, user_id: str, cv_id: str, jd_text: Optional[str] = None) -> dict:
        """Analyze a previously saved CV by its ID."""
        try:
            logger.info(f"Starting analysis for saved CV: {cv_id} for user: {user_id}")
            
            # Fetch CV record
            cv_record = await self.repo.get_cv_by_id(cv_id)
            if not cv_record:
                logger.error(f"CV record not found for cv_id: {cv_id}")
                raise HTTPException(status_code=404, detail="CV record not found.")
            
            # Parse JD if provided
            jd_id = None
            parsed_jd = None
            if jd_text:
                logger.debug("Parsing job description for saved CV analysis")
                parsed_jd = await self.parser.parse_job_description(jd_text)
                logger.info("Job description parsed successfully for saved CV analysis")
                jd_id = await self._save_jd_record(jd_text, parsed_jd)
            else:
                logger.debug("No job description provided, attempting to find last report without JD for this CV")
                reports = await self.repo.get_optmization_report_by_cv_id(cv_id, no_jd=True)
                last_report = reports[0] if reports else None
                if last_report:
                    return last_report
            
            # Create optimization request
            request_id = await self.repo.create_optimization_request(user_id, cv_id, jd_id)

            # Perform analysis
            analysis_results = await self._perform_analysis(cv_record["parsed_content"], parsed_jd)
            
            final_report = await self._save_optimization_report(request_id, cv_id, jd_id, analysis_results)

            logger.info(f"Analysis completed successfully for saved CV: {cv_id} for user: {user_id}")
            return final_report
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Analysis failed for saved CV {cv_id} for user {user_id}: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Analysis failed: {str(e)}"
            )

    # ========================
    # VALIDATION & UPLOAD
    # ========================

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
            uploaded_file = await asyncio.to_thread(
                self.storage_provider.upload_file,
                cv_file.file,
                f"cv_{cleaned_filename}",
                folder=user_id
            )
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

    # ========================
    # PARSING
    # ========================

    async def _parse_cv_and_jd(self, cv_file: UploadFile, jd_text: Optional[str]) -> tuple:
        """Parse CV and job description files."""
        try:
            logger.debug(f"Starting to parse CV file: {cv_file.filename}")
            parsed_cv_text, parsed_cv = await self.parser.parse_cv(cv_file)
            logger.info("CV parsed successfully")
            
            parsed_jd = None
            if jd_text:
                logger.debug("Parsing job description")
                parsed_jd = await self.parser.parse_job_description(jd_text)
                logger.info("Job description parsed successfully")
            else:
                logger.debug("No job description provided")
            
            return parsed_cv_text, parsed_cv, parsed_jd
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"CV/JD parsing failed: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"CV/JD parsing failed: {str(e)}"
            )

    # ========================
    # DATABASE OPERATIONS
    # ========================

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

            # Save CV to database
            logger.debug(f"Uploading CV to database for user: {user_id}")
            created_cv_id = await self.repo.create_cv_record(user_id, file_url, parsed_cv_text, parsed_cv_json)
            logger.info(f"CV saved to database with cv_id: {created_cv_id}")
            
            # Save JD if provided
            jd_id = None
            if jd_text and parsed_jd:
                jd_id = await self._save_jd_record(jd_text, parsed_jd)
            
            # Create optimization request
            logger.debug(f"Creating optimization request for user: {user_id}")
            request_id = await self.repo.create_optimization_request(user_id, created_cv_id, jd_id)
            logger.info(f"Optimization request created with request_id: {request_id}")
            
            return created_cv_id, jd_id, request_id
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database operation failed while saving parsed data: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Database operation failed: {str(e)}"
            )

    async def _save_jd_record(self, jd_text: str, parsed_jd: dict) -> str:
        """Save job description record to database."""
        try:
            logger.debug("Saving job posting to database")
            jd = JobPosting(
                raw_text=jd_text,
                parsed_data=parsed_jd,
                source_type="text"
            ).model_dump(mode="json", exclude_none=True)
        
            jd_id = await self.repo.create_jd_record(jd)
            logger.info(f"Job posting saved to database with job_id: {jd_id}")
            return jd_id
        except Exception as e:
            logger.error(f"Failed to save job description: {str(e)}", exc_info=True)
            raise

    async def _save_optimization_report(
        self, request_id: str, cv_id: str, jd_id: str, analysis_results: dict
    ) -> dict:
        """Save optimization report to database."""
        report = CVOptimizationReport(
            request_id=request_id,
            cv_id=cv_id,
            job_posting_id=jd_id,
            analysis=analysis_results
        )

        final_report = await self.repo.create_optimization_report(
            report.model_dump(mode="json", exclude_none=True)
        )

        await self.repo.update_optimization_request_status(request_id, "completed")

        return final_report

    # ========================
    # ANALYSIS
    # ========================

    async def _perform_analysis(self, parsed_cv: dict, parsed_jd: Optional[dict]) -> dict:
        """Perform ATS analysis using LLM."""
        try:
            logger.debug("Preparing analysis prompt")
            job_description = parsed_jd if parsed_jd else "No job description provided"
            
            logger.debug("Sending request to LLM for CV analysis")
            results = await self.llm.get_response(
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
            
            logger.info("LLM analysis completed successfully")
            return results.dict() if isinstance(results, ATSAnalysisResponse) else results
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"LLM analysis failed: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"LLM analysis failed: {str(e)}"
            )


def get_cv_analyser():
    return CVAnalyser()
