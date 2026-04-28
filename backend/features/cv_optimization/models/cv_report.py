from typing import Optional, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field

from pydantic import BaseModel
from typing import Optional, Dict, List, Any
from uuid import UUID
from datetime import datetime

class NamedCheck(BaseModel):
    Check_Name: str
    Result: str

class ATSReadability(BaseModel):
    Score: int
    Number_of_Passed_Checks: int
    Total_Number_of_Checks: int
    ATS_Issues: List[NamedCheck]

class ContentQuality(BaseModel):
    Score: int
    Number_of_Passed_Checks: int
    Total_Number_of_Checks: int
    Content_Issues: List[NamedCheck]

class PassNotes(BaseModel):
    Pass: bool
    Notes: str

class SectionAnalysis(BaseModel):
    Contact_Info: PassNotes
    Work_Experience: PassNotes
    Education: PassNotes
    Skills: PassNotes
    Additional_Sections: PassNotes

class IndustryKeywordOptimization(BaseModel):
    Suggestions: List[str]
    Recommended_Keywords: List[str]

class LLMInsights(BaseModel):
    Job_Alignment: Optional[Dict[str, Any]]
    Keyword_Optimization: Optional[IndustryKeywordOptimization]
    Improvement_Tips: Optional[List[str]]

class FinalReportAnalysis(BaseModel):
    ATS_Readability_Analysis: ATSReadability
    Content_Quality_Analysis: ContentQuality
    Section_Analysis: SectionAnalysis
    LLM_Insights: Optional[LLMInsights]
    Additional_Metadata: Optional[Dict[str, Any]]

class CVOptimizationReportDetailed(BaseModel):
    report_id: Optional[UUID]
    request_id: Optional[UUID]
    cv_id: Optional[UUID]
    job_posting_id: Optional[UUID]
    generated_at: Optional[datetime]
    cv: Optional[Dict[str, Any]]          # e.g. {"title": "My CV", "original_filename": "resume.pdf"}
    job_posting: Optional[Dict[str, Any]] # e.g. {"job_title": "Data Scientist"}
    analysis: FinalReportAnalysis

class CVOptimizationReport(BaseModel):
    report_id: Optional[UUID] = None
    request_id: Optional[UUID] = None
    cv_id: Optional[UUID] = None
    job_posting_id: Optional[UUID] = None
    analysis: Optional[dict] = None
    generated_at: Optional[datetime] = None