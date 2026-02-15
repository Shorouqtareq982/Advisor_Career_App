from fastapi import Depends
from shared.helpers.file_validation import FileValidator
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from .parser import DocumentParser
from models import optmization_request
from schemas import ATSAnalysisResponse
from prompts import CV_ANALYST

class CVAnalyser:
    def __init__(self, llm: LLMProvider = Depends(create_llm_provider)):
        self.llm = llm
        self.parser = DocumentParser(llm)

    #TODO: Error handling and logging
    def analyze_cv(self, cv_file, jd_text):
        isvalid = FileValidator.validate_cv_file(cv_file)
        if not isvalid:
            print("Invalid file provided for CV analysis.")
            return {"error": "Invalid file."}
        
        #TODO: upload file to storage and get URL
        #TODO: save file metadata and jd to database and get CV and JD ID
        #TODO: save request metadata and get request ID
        # Parse the CV file to extract relevant information
        parsed_cv_text,parsed_cv = self.parser.parse_cv(cv_file)
        parsed_jd = self.parser.parse_job_description(jd_text)

        #TODO: save parsed CV and JD data to database linked to the request ID
        # Perform analysis on the parsed data
        analysis_results = self._perform_analysis(parsed_cv, parsed_jd)

        #TODO: save analysis results to database linked to the request ID and generate report ID

        return analysis_results

    def _perform_analysis(self, parsed_cv: dict, parsed_jd: dict) -> dict:
        results = self.llm.get_response(
            prompt=CV_ANALYST.format(cv_data=parsed_cv, jd_data=parsed_jd),
            need_json_output=True,
            schema=ATSAnalysisResponse
        )

        if not results:
            print("LLM returned empty response for CV analysis.")
            return {}
        
        return results.dict() if isinstance(results, ATSAnalysisResponse) else results
