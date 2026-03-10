import asyncio
import hashlib
import io
import logging
from typing import Optional

from fastapi import HTTPException, UploadFile, status
import pymupdf
from docx import Document

from features.cv_optimization.repositories.cv_optmization_repo import CVOptRepository
from features.cv_optimization.schemas import CVData, JobData
from shared.helpers.document_parser import DocumentParser
from shared.helpers.text_extractor import TextExtractor
from shared.helpers.file_validation import FileValidator
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from shared.providers.storage import CloudinaryProvider

from ..models import CVOptimizationRequest, CVOptimizationReport, JobPosting
from ..prompts import CV_ANALYST
from ..schemas import ATSAnalysisResponse
from .cv_layout_analyzer import CVLayoutAnalyzer

logger = logging.getLogger(__name__)

"""
TODO:
[x] save layout analysis results to database and include in report
[x] return job title or cv title in response for better UI display
[x] implement caching for previously analyzed CVs (e.g. if same file hash is uploaded again, return previous results)
[ ] optmize LLM prompt by including layout analysis results and file metadata (e.g. file size, number of pages, fonts used) to help LLM better understand the CV structure and provide more tailored optimization suggestions
[ ] implement retry logic for LLM calls in case of transient errors
"""

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
            
            # Validate and upload CV
            file_url = await self._validate_and_upload_cv(user_id, cv_file)
            
            # Read file and compute hashes
            file_bytes, parse_buf, file_size_kb = await self._read_file_bytes(cv_file)
            cv_hash, jd_hash = self._compute_hashes(file_bytes, jd_text, user_id)
            
            # Check cache for existing CV and JD records
            cv_record, jd_record = await self._check_cache(cv_hash, jd_hash)
            
            # Route to appropriate handler based on cache status
            if cv_record and jd_record:
                return await self._handle_both_cached(user_id, cv_record, jd_record)
            elif cv_record:
                return await self._handle_cv_cached_only(user_id, cv_record, jd_text, jd_hash)
            elif jd_record:
                return await self._handle_jd_cached_only(
                    user_id, file_url, jd_record, parse_buf, file_size_kb, 
                    cv_file.content_type, cv_hash
                )
            else:
                return await self._handle_no_cache(
                    user_id, file_url, parse_buf, file_size_kb, 
                    cv_file.content_type, jd_text, cv_hash, jd_hash
                )
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"CV analysis failed for user {user_id}: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"CV analysis failed: {str(e)}"
            )

    async def analyze_saved_cv(self, user_id: str, cv_id: str, jd_text: Optional[str] = None) -> dict:
        """Analyze a previously saved CV by its ID with caching support."""
        try:
            logger.info(f"Starting analysis for saved CV: {cv_id} for user: {user_id}")
            
            # Fetch CV record
            cv_record = await self.repo.get_cv_by_id(cv_id)
            if not cv_record:
                logger.error(f"CV record not found for cv_id: {cv_id}")
                raise HTTPException(status_code=404, detail="CV record not found.")
            
            # Handle different JD scenarios
            if jd_text:
                # Compute JD hash and check cache
                jd_hash = self.compute_content_hash(jd_text, user_id)
                jd_record = await self.repo.get_jd_by_hash(jd_hash)
                
                if jd_record:
                    # JD exists in cache, check for existing report
                    return await self._handle_saved_cv_with_cached_jd(user_id, cv_id, cv_record, jd_record)
                else:
                    # JD is new, parse and save it
                    return await self._handle_saved_cv_with_new_jd(user_id, cv_id, cv_record, jd_text, jd_hash)
            else:
                # No JD provided, return last report without JD or create new one
                return await self._handle_saved_cv_without_jd(user_id, cv_id, cv_record)
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Analysis failed for saved CV {cv_id} for user {user_id}: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Analysis failed: {str(e)}"
            )

    # ========================
    # CACHING HANDLERS
    # ========================

    async def _handle_saved_cv_with_cached_jd(self, user_id: str, cv_id: str, cv_record: dict, jd_record: dict) -> dict:
        """Handle saved CV analysis when JD exists in cache."""
        logger.info(f"Found cached JD (id: {jd_record['job_id']}) for saved CV analysis")
        return await self._get_or_create_report(
            user_id=user_id,
            cv_id=cv_id,
            jd_id=jd_record['job_id'],
            cv_data=cv_record['parsed_content'],
            jd_data=jd_record['parsed_data'],
            cv_layout=cv_record.get('cv_layout_analysis'),
            log_context="saved CV with cached JD"
        )

    async def _handle_saved_cv_with_new_jd(self, user_id: str, cv_id: str, cv_record: dict, jd_text: str, jd_hash: str) -> dict:
        """Handle saved CV analysis when JD is new."""
        logger.info("Parsing new JD for saved CV analysis")
        parsed_jd, jd_id = await self._process_new_jd(jd_text, jd_hash)
        
        return await self._get_or_create_report(
            user_id=user_id,
            cv_id=cv_id,
            jd_id=jd_id,
            cv_data=cv_record['parsed_content'],
            jd_data=parsed_jd,
            cv_layout=cv_record.get('cv_layout_analysis'),
            log_context="saved CV with new JD"
        )

    async def _handle_saved_cv_without_jd(self, user_id: str, cv_id: str, cv_record: dict) -> dict:
        """Handle saved CV analysis when no JD is provided."""
        logger.info("No JD provided, checking for existing report without JD")
        return await self._get_or_create_report(
            user_id=user_id,
            cv_id=cv_id,
            jd_id=None,
            cv_data=cv_record['parsed_content'],
            jd_data=None,
            cv_layout=cv_record.get('cv_layout_analysis'),
            log_context="saved CV without JD",
            no_jd=True
        )

    async def _handle_both_cached(self, user_id: str, cv_record: dict, jd_record: dict) -> dict:
        """Handle scenario where both CV and JD exist in cache."""
        logger.info(f"Found cached CV (id: {cv_record['cv_id']}) and JD (id: {jd_record['job_id']})")
        return await self._get_or_create_report(
            user_id=user_id,
            cv_id=cv_record['cv_id'],
            jd_id=jd_record['job_id'],
            cv_data=cv_record['parsed_content'],
            jd_data=jd_record['parsed_data'],
            cv_layout=cv_record.get('cv_layout_analysis'),
            log_context="cached CV and JD"
        )

    async def _handle_cv_cached_only(self, user_id: str, cv_record: dict, jd_text: Optional[str], jd_hash: Optional[str]) -> dict:
        """Handle scenario where only CV exists in cache."""
        logger.info(f"Found cached CV (id: {cv_record['cv_id']}), parsing new JD")
        parsed_jd, jd_id = await self._process_new_jd(jd_text, jd_hash)
        
        return await self._get_or_create_report(
            user_id=user_id,
            cv_id=cv_record['cv_id'],
            jd_id=jd_id,
            cv_data=cv_record['parsed_content'],
            jd_data=parsed_jd,
            cv_layout=cv_record.get('cv_layout_analysis'),
            log_context="cached CV and new JD"
        )

    async def _handle_jd_cached_only(
        self, user_id: str, file_url: str, jd_record: dict, 
        parse_buf: io.BytesIO, file_size_kb: float, content_type: str, cv_hash: str
    ) -> dict:
        """Handle scenario where only JD exists in cache."""
        logger.info(f"Found cached JD (id: {jd_record['job_id']}), parsing new CV")
        cv_id, cv_data, cv_layout = await self._process_new_cv(
            user_id, file_url, parse_buf, file_size_kb, content_type, cv_hash
        )
        
        return await self._get_or_create_report(
            user_id=user_id,
            cv_id=cv_id,
            jd_id=jd_record['job_id'],
            cv_data=cv_data,
            jd_data=jd_record['parsed_data'],
            cv_layout=cv_layout,
            log_context="new CV and cached JD"
        )

    async def _handle_no_cache(
        self, user_id: str, file_url: str, parse_buf: io.BytesIO, 
        file_size_kb: float, content_type: str, jd_text: Optional[str], 
        cv_hash: str, jd_hash: Optional[str]
    ) -> dict:
        """Handle scenario where nothing exists in cache."""
        logger.info("No cached data found, processing CV and JD from scratch")
        
        # Parse CV and JD
        parsed_cv_text, parsed_cv, parsed_jd, cv_layout_analysis = await self._parse_cv_and_jd(
            parse_buf, file_size_kb, content_type, jd_text
        )
        
        # Save to database
        cv_id, jd_id, request_id = await self._save_parsed_data(
            user_id, file_url, parsed_cv_text, parsed_cv, jd_text, 
            parsed_jd, cv_layout_analysis, cv_hash, jd_hash
        )
        
        # Perform analysis and save report
        analysis_results = await self._perform_analysis(parsed_cv, parsed_jd, cv_layout_analysis)
        final_report = await self._save_optimization_report(request_id, cv_id, jd_id, analysis_results)
        
        logger.info(f"CV analysis completed successfully for user: {user_id}, request_id: {request_id}")
        return final_report

    # ========================
    # COMMON WORKFLOW HELPERS
    # ========================

    async def _get_or_create_report(
        self, user_id: str, cv_id: str, jd_id: Optional[str],
        cv_data: dict, jd_data: Optional[dict], cv_layout: Optional[dict],
        log_context: str, no_jd: bool = False
    ) -> dict:
        """Check for existing report or create new one with analysis."""
        # Check for existing report
        existing_report = await self._check_existing_report(cv_id, jd_id, no_jd)
        if existing_report:
            return existing_report
        
        # No existing report, perform analysis
        logger.info(f"No existing report found, performing analysis with {log_context}")
        request_id = await self.repo.create_optimization_request(user_id, cv_id, jd_id)
        analysis_results = await self._perform_analysis(cv_data, jd_data, cv_layout)
        final_report = await self._save_optimization_report(request_id, cv_id, jd_id, analysis_results)
        
        logger.info(f"Analysis completed for {log_context}, request_id: {request_id}")
        return final_report

    async def _check_existing_report(self, cv_id: str, jd_id: Optional[str], no_jd: bool = False) -> Optional[dict]:
        """Check if a report already exists for the given CV and JD combination."""
        if no_jd:
            existing_reports = await self.repo.get_optmization_report_by_cv_id(cv_id, no_jd=True)
        else:
            existing_reports = await self.repo.get_optmization_report_by_cv_id(cv_id, jd_id=jd_id)
        
        if existing_reports:
            logger.info("Found existing report, returning cached result")
            return existing_reports[0]
        return None

    # ========================
    # FILE & CACHE OPERATIONS
    # ========================

    async def _read_file_bytes(self, cv_file: UploadFile) -> tuple[bytes, io.BytesIO, float]:
        """Read file bytes and create buffer for parsing."""
        cv_file.file.seek(0)
        file_bytes = cv_file.file.read()
        file_size_kb = len(file_bytes) / 1024
        
        parse_buf = io.BytesIO(file_bytes)
        parse_buf.name = cv_file.filename
        
        return file_bytes, parse_buf, file_size_kb

    def _compute_hashes(self, file_bytes: bytes, jd_text: Optional[str], user_id: str) -> tuple[str, Optional[str]]:
        """Compute content hashes for CV and JD."""
        cv_hash = self.compute_content_hash(file_bytes, user_id)
        jd_hash = self.compute_content_hash(jd_text, user_id) if jd_text else None
        return cv_hash, jd_hash

    async def _check_cache(self, cv_hash: str, jd_hash: Optional[str]) -> tuple[Optional[dict], Optional[dict]]:
        """Check cache for existing CV and JD records."""
        cv_record = await self.repo.get_cv_by_hash(cv_hash)
        jd_record = await self.repo.get_jd_by_hash(jd_hash) if jd_hash else None
        return cv_record, jd_record

    async def _process_new_cv(
        self, user_id: str, file_url: str, parse_buf: io.BytesIO, 
        file_size_kb: float, content_type: str, cv_hash: str
    ) -> tuple[str, dict, Optional[dict]]:
        """Process and save a new CV."""
        parsed_cv_text, parsed_cv, _, cv_layout_analysis = await self._parse_cv_and_jd(
            parse_buf, file_size_kb, content_type, None
        )
        
        cv_id, _, _ = await self._save_parsed_data(
            user_id, file_url, parsed_cv_text, parsed_cv, None, None, 
            cv_layout_analysis, cv_hash, None
        )
        
        return cv_id, parsed_cv, cv_layout_analysis

    async def _process_new_jd(self, jd_text: Optional[str], jd_hash: Optional[str]) -> tuple[Optional[dict], Optional[str]]:
        """Process and save a new JD."""
        if not jd_text:
            return None, None
            
        parsed_jd = await self.parser.parse_job_description(jd_text)
        jd_id = await self._save_jd_record(jd_text, parsed_jd, jd_hash)
        return parsed_jd, jd_id

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

    async def _parse_cv_and_jd(self, cv_file: io.BytesIO, file_size_kb: float, file_type: str, jd_text: Optional[str]) -> tuple:
        """Parse CV and job description files."""
        try:
            # Parse CV
            parsed_cv_text, parsed_cv, cv_layout_analysis = await self._parse_cv_file(
                cv_file, file_size_kb, file_type
            )
            
            # Parse JD if provided
            parsed_jd = await self._parse_jd_text(jd_text) if jd_text else None
            
            return parsed_cv_text, parsed_cv, parsed_jd, cv_layout_analysis
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"CV/JD parsing failed: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"CV/JD parsing failed: {str(e)}"
            )

    async def _parse_cv_file(self, cv_file: io.BytesIO, file_size_kb: float, file_type: str) -> tuple:
        """Parse CV file and extract layout analysis."""
        logger.debug(f"Starting to parse CV file: {cv_file.name}")
        
        # Analyze layout
        cv_layout_analysis, parsed_cv_text = CVLayoutAnalyzer.analyze_file_layout(
            cv_file, cv_file.name, file_size_kb, file_type
        )
        
        # Extract text if layout analysis didn't provide it
        if not parsed_cv_text:
            parsed_cv_text = await TextExtractor.extract_text(cv_file)
        
        # Parse CV content
        parsed_cv = await self.parser.parse_cv_text(parsed_cv_text)
        logger.info("CV parsed successfully")
        
        return parsed_cv_text, parsed_cv, cv_layout_analysis

    async def _parse_jd_text(self, jd_text: str) -> dict:
        """Parse job description text."""
        logger.debug("Parsing job description")
        parsed_jd = await self.parser.parse_job_description(jd_text)
        logger.info("Job description parsed successfully")
        return parsed_jd

    # ========================
    # DATABASE OPERATIONS
    # ========================

    async def _save_parsed_data(
        self, user_id: str, file_url: str, parsed_cv_text: str, 
        parsed_cv: CVData, jd_text: Optional[str], parsed_jd: Optional[dict], cv_layout_analysis: Optional[dict],
        cv_hash: Optional[str] = None, jd_hash: Optional[str] = None
    ) -> tuple:
        """Save CV, JD, and optimization request to database."""
        try:
            # Convert and save CV
            cv_id = await self._save_cv_record(
                user_id, file_url, parsed_cv_text, parsed_cv, cv_layout_analysis, cv_hash
            )
            
            # Save JD if provided
            jd_id = None
            if jd_text and parsed_jd:
                jd_id = await self._save_jd_record(jd_text, parsed_jd, jd_hash)
            
            # Create optimization request
            request_id = await self._create_optimization_request(user_id, cv_id, jd_id)
            
            return cv_id, jd_id, request_id
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database operation failed while saving parsed data: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Database operation failed: {str(e)}"
            )

    async def _save_cv_record(
        self, user_id: str, file_url: str, parsed_cv_text: str, 
        parsed_cv: CVData, cv_layout_analysis: Optional[dict], cv_hash: Optional[str]
    ) -> str:
        """Convert and save CV record to database."""
        logger.debug(f"Saving CV to database for user: {user_id}")
        
        # Convert parsed CV to JSON
        parsed_cv_json = self._convert_to_json(parsed_cv)
        parsed_layout_json = self._convert_to_json(cv_layout_analysis)
        
        # Save to database
        cv_id = await self.repo.create_cv_record(
            user_id, file_url, parsed_cv_text, parsed_cv_json, parsed_layout_json, cv_hash
        )
        logger.info(f"CV saved to database with cv_id: {cv_id}")
        return cv_id

    async def _save_jd_record(self, jd_text: str, parsed_jd: dict, jd_hash: Optional[str] = None) -> str:
        """Save job description record to database."""
        try:
            logger.debug("Saving job posting to database")
            
            # Create JD model
            jd = JobPosting(
                raw_text=jd_text,
                parsed_data=parsed_jd,
                source_type="text"
            ).model_dump(mode="json", exclude_none=True)
            
            # Add content hash if provided
            if jd_hash:
                jd["content_hash"] = jd_hash
        
            jd_id = await self.repo.create_jd_record(jd)
            logger.info(f"Job posting saved to database with job_id: {jd_id}")
            return jd_id
        except Exception as e:
            logger.error(f"Failed to save job description: {str(e)}", exc_info=True)
            raise

    async def _create_optimization_request(self, user_id: str, cv_id: str, jd_id: Optional[str]) -> str:
        """Create optimization request in database."""
        logger.debug(f"Creating optimization request for user: {user_id}")
        request_id = await self.repo.create_optimization_request(user_id, cv_id, jd_id)
        logger.info(f"Optimization request created with request_id: {request_id}")
        return request_id

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

    async def _perform_analysis(self, parsed_cv: dict, parsed_jd: Optional[dict], cv_layout_analysis: Optional[dict]) -> dict:
        """Perform ATS analysis using LLM."""
        try:
            logger.debug("Preparing analysis prompt")
            job_description = parsed_jd if parsed_jd else "No job description provided"
            cv_layout_analysis = cv_layout_analysis if cv_layout_analysis else {"message": "No layout analysis available"}
            
            logger.debug("Sending request to LLM for CV analysis")
            results = await self.llm.get_response(
                prompt=CV_ANALYST.format(cv_text=parsed_cv, job_description=job_description, cv_layout_analysis=cv_layout_analysis),
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


    # ========================
    # HELPER METHODS
    # ========================

    @staticmethod
    def compute_content_hash(content: str | bytes, user_id: str) -> str:
        """Compute a SHA256 hash for the given text or bytes."""
        if isinstance(content, str):
            content = "".join(content.split())
            content = content.encode("utf-8")
        # Append user_id to the content before hashing
        content += user_id.encode("utf-8")
        return hashlib.sha256(content).hexdigest()

    def _convert_to_json(self, data: any) -> Optional[dict]:
        """Convert pydantic model or data to JSON dict."""
        if data is None:
            return None
        if hasattr(data, 'model_dump'):
            return data.model_dump(mode="json", exclude_none=True)
        return data

def get_cv_analyser():
    return CVAnalyser()
