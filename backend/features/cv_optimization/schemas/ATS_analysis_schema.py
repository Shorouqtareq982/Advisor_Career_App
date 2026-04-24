from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class PassNotes(BaseModel):
    """
    Represents the pass/fail result and human-readable notes for a resume section.
    """
    Pass: bool = Field(
        ...,
        description=(
            "Whether the section passes the assistant's minimum checks. "
            "True = section passes basic ATS readability & content checks; "
            "False = section failed (missing/incorrect formatting or critical content)."
        ),
    )
    Notes: str = Field(
        "",
        max_length=250,
        description=(
            "Detailed notes about why the section passed or failed. "
            "Include formatting issues, missing fields, missing metrics, or other actionable observations. "
            "Maximum 30 words."
        ),
    )

class CheckResult(BaseModel):
    """
    Represents the result of a single check.
    """
    Pass: bool = Field(..., description="True if this check passes; False otherwise.")
    Message: str = Field(
        "",
        max_length=250,
        description=(
            "Human-readable message explaining the check outcome. "
            "Example: 'You provided your phone number.' or "
            "'The job title \"Development Intern\" from the job description was not found in your resume.' "
            "Maximum 20 words."
        )
    )

class NamedCheck(BaseModel):
    Check_Name: str = Field(
        ...,
        description="Short name of the check being performed."
    )
    Result: CheckResult

class ATSReadabilityAnalysis(BaseModel):
    """
    Detailed analysis of ATS readability factors with specific checks and messages.
    
    TOTAL CHECKS: 19
    
    SCORING FORMULA:
    Score = (Number_of_Passed_Checks / Total_Number_of_Checks) * 100
    Round UP to nearest integer. Maximum score: 100.
    
    CHECK CATEGORIES:
    
    1. STRUCTURE & FORMATTING (4 checks):
       - Number of pages ≤ 2 → PASS / FAIL
       - ≤ 3 font families used → PASS / FAIL
       - Average font size between 9 and 13 points → PASS / FAIL
       - Word count ≤ 1000 → PASS / FAIL
    
    2. PAGE SETUP (4 checks):
       - Standard page size (e.g. A4, Letter) → PASS / FAIL
       - Margins between 0.5 and 1 inch → PASS / FAIL
       - No information in header → PASS / FAIL
       - No information in footer → PASS / FAIL
    
    3. ATS PARSING COMPATIBILITY (5 checks):
       - Tables absent or non-disruptive → PASS / FAIL
       - Columns absent → PASS / FAIL
       - Images absent or relevant → PASS / FAIL
       - Graphics/drawings/icons absent → PASS / FAIL
       - Textboxes absent → PASS / FAIL
    
    4. VALID DATE FORMATS (1 check):
       - Date format: MM/YY or MM/YYYY or Month YYYY (e.g. 03/18, 03/2019, Mar 2019) → PASS / FAIL
    
    5. FILE QUALITY (5 checks):
       - File size ≤ 5000 KB → PASS / FAIL
       - File type is PDF or DOCX → PASS / FAIL
       - File name is CV-relevant (contains "CV" or "Resume" or candidate name) → PASS / FAIL
       - File name length ≤ 100 characters → PASS / FAIL
       - File name does not contain special characters → PASS / FAIL
    
    RULE: If a CVLayoutAnalysis field is null/None, treat it as PASS.
    """
    Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "0–100 score for ATS readability. Formula: (Number_of_Passed_Checks / Total_Number_of_Checks) * 100, rounded UP to nearest integer. "
            "Maximum score: 100. Evaluates file type, font usage, layout simplicity, parsing-breaking elements (tables, images), "
            "standard section headings, date formats, and file metadata."
        ))
    Number_of_Passed_Checks: int = Field(
        ...,
        ge=0,
        le=19,
        description=(
            "Total count of ATS readability checks that passed (0-19). Each check returns binary PASS or FAIL. "
            "Provides granularity beyond the overall score."
    ))
    Total_Number_of_Checks: int = Field(
        ...,
        ge=19,
        le=19,
        description=(
            "Total count of ATS readability checks performed. Should always be 19. "
            "Used to calculate pass rate: (Number_of_Passed_Checks / Total_Number_of_Checks) * 100."
    ))
    Failed_Checks: List[NamedCheck] = Field(
        default_factory=list,
        description=(
            "List of all failed ATS readability checks. Each failed check includes Check_Name and Result (Pass=False + Message). "
            "Examples: tables present, images found, >2 pages, critical info in headers/footers, invalid date formats, "
            "file size > 5MB, special characters in filename."
        ))

class ContentQualityAnalysis(BaseModel):
    """
    Detailed analysis of content quality factors with specific checks and messages.
    
    TOTAL CHECKS: 13
    
    SCORING FORMULA:
    Score = (Number_of_Passed_Checks / Total_Number_of_Checks) * 100
    Round UP to nearest integer. Maximum score: 100.
    
    CHECK CATEGORIES:
    
    1. ESSENTIAL SECTIONS EXIST (4 checks):
       - Summary section present → PASS / FAIL
       - Skills section present → PASS / FAIL
       - Education section present → PASS / FAIL
       - Work Experience section present → PASS / FAIL
    
    2. CONTACT INFO PRESENT (4 checks):
       - Email provided → PASS / FAIL
       - Phone number provided → PASS / FAIL
       - Address/Location provided → PASS / FAIL
       - Name and professional title exist → PASS / FAIL
    
    3. CONTENT QUALITY (5 checks):
       - Headings in logical order and clearly defined → PASS / FAIL
       - Spelling and grammar correct (no typos) → PASS / FAIL
       - Action verbs used, no personal pronouns (I, me, my) → PASS / FAIL
       - Clear and specific wording (no vague/generic phrases) → PASS / FAIL
       - Quantifiable impact: At least 5 measurable results across experiences/projects → PASS / FAIL
    
    QUANTIFIABLE METRICS CATEGORIES (for check #13):
    Count measurable results across these categories:
    1. Money/Finance: sales volume, revenue %, cost savings, budgets managed
    2. People: customers served/retained, direct reports, teams led, people hired
    3. Tasks/Operations: efficiency improvements, process improvements, time saved, volume of tasks
    4. Other: awards, publications, recognitions
    
    Minimum 5 measurable results required to PASS check #13.
    """
    Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "0–100 score for content quality. Formula: (Number_of_Passed_Checks / Total_Number_of_Checks) * 100, rounded UP to nearest integer. "
            "Maximum score: 100. Evaluates clarity, active voice, quantifiable achievements, grammar, section presence, and contact info completeness."
        ))
    Number_of_Passed_Checks: int = Field(
        ...,
        ge=0,
        le=13,
        description=(
            "Total count of content quality checks that passed (0-13). Each check returns binary PASS or FAIL. "
            "Provides granularity beyond the overall score."
    ))
    Total_Number_of_Checks: int = Field(
        ...,
        ge=13,
        le=13,
        description=(
            "Total count of content quality checks performed. Should always be 13. "
            "Used to calculate pass rate: (Number_of_Passed_Checks / Total_Number_of_Checks) * 100."
    ))
    Failed_Checks: List[NamedCheck] = Field(
        default_factory=list,
        description=(
            "List of all failed content quality checks. Each failed check includes Check_Name and Result (Pass=False + Message). "
            "Examples: missing sections (Summary, Skills, Education, Experience), missing contact info (email, phone), "
            "passive voice usage, vague language, <5 quantifiable achievements, typos, illogical section ordering."
        ))

class SectionAnalysis(BaseModel):
    """
    Per-section evaluation of the resume with Pass/Fail + detailed notes.
    
    EVALUATION APPROACH:
    - Do NOT calculate a score for Section_Analysis
    - Each section returns: Pass (bool) + Notes (str)
    - Pass = all required elements present and properly formatted
    - Fail = missing required elements or formatting issues
    - Notes must be specific and actionable
    
    SECTION CRITERIA:
    
    CONTACT INFO:
    - Required: Name, Email, Phone
    - Pass if all exist; Fail otherwise
    - Notes: Specify which fields are missing (e.g., "Missing phone number")
    
    WORK EXPERIENCE:
    - Section must exist
    - Must contain bullet points or descriptions for each role
    - Must include measurable achievements (quantified results)
    - Each entry should have: company, title, dates, location
    - Notes: List missing bullets, missing achievements, formatting problems
    
    EDUCATION:
    - Section must exist
    - Must include: degree/qualification, institution name, dates
    - Optional but valuable: honors, relevant coursework, GPA
    - Notes: Specify missing information (e.g., "Missing graduation date")
    
    SKILLS:
    - Section must exist
    - Must have at least 5 relevant skills
    - Should separate categories (e.g., tools, languages, frameworks)
    - Must be ATS-friendly (avoid images/icons for skills)
    - Notes: Specify if skills are too generic or missing categories
    
    ADDITIONAL SECTIONS (Projects/Certifications/Volunteer/Publications):
    - Evaluate relevance to job description
    - Check if content adds value to candidacy
    - Verify proper formatting
    - Notes: Identify missing relevant sections or suggest improvements
    """
    Contact_Info: PassNotes = Field(
        ...,
        description=(
            "Evaluation for Contact Info section. Required: Name, Email, Phone. "
            "Pass if all present and readable. Fail if any missing. "
            "Notes should specify exactly which fields are missing or improperly formatted."
        )
    )
    Work_Experience: PassNotes = Field(
        ...,
        description=(
            "Evaluation for Work Experience section. Required: section exists, bullet points/descriptions present, "
            "measurable achievements included. Each entry should have company, title, dates, location. "
            "Pass if criteria met. Fail if missing bullets, achievements, or required fields. "
            "Notes must list specific missing elements (e.g., 'Missing measurable results in 2 of 3 roles', "
            "'Job at Company X lacks dates')."
        ),
    )
    Education: PassNotes = Field(
        ...,
        description=(
            "Evaluation for Education section. Required: section exists, degree/qualification, institution name, dates. "
            "Optional: honors, coursework, GPA. Pass if required fields present. Fail if any required field missing. "
            "Notes should specify missing information (e.g., 'Missing graduation date for Bachelor degree')."
        )
    )
    Skills: PassNotes = Field(
        ...,
        description=(
            "Evaluation for Skills section. Required: section exists, at least 5 relevant skills listed, "
            "ATS-friendly format (no images/icons). Preferred: skills categorized (tools, languages, soft skills). "
            "Pass if requirements met. Fail if <5 skills, or skills are too generic/irrelevant. "
            "Notes should identify issues (e.g., 'Only 3 skills listed, need at least 5', "
            "'Skills too generic: communication, teamwork')."
        ),
    )
    Additional_Sections: PassNotes = Field(
        ...,
        description=(
            "Evaluation for additional resume sections: Certifications, Projects, Publications, Volunteer, Awards, etc. "
            "Pass if relevant sections present and add value to candidacy. Fail if missing relevant sections or content is irrelevant. "
            "Notes should identify missing valuable sections (e.g., 'Consider adding Certifications section for AWS/Azure certs mentioned in JD', "
            "'Projects section exists but lacks measurable impact')."
        ),
    )

class SkillsAnalysis(BaseModel):
    """
    Skills matching analysis between CV and job description.
    
    CRITICAL FORMAT REQUIREMENT:
    - Each skill must be a CONCISE TERM (1-4 words max)
    - NO sentences, NO descriptions, NO "experience with X" phrases
    - Extract the CORE SKILL NAME only
    
    MATCHING RULES:
    - Extract skills from both JD and CV
    - Normalize case for comparison (Python = python = PYTHON)
    - Remove duplicates before counting
    - Count only explicit matches (do not infer skills not written)
    - Match using these rules (in order of priority):
      1. Exact match after case normalization (Python = python)
      2. Common abbreviations: JavaScript=JS, TypeScript=TS
      3. Framework variations: React.js=React=ReactJS, Node.js=Node=NodeJS
      4. Version-agnostic: Python3=Python, Java8=Java
    - When uncertain if terms match, treat as SEPARATE (be conservative to ensure consistency)
    
    SKILL CATEGORIES TO CONSIDER:
    - Technical skills: programming languages, frameworks, libraries
    - Tools & platforms: IDEs, version control, cloud platforms
    - Methodologies: Agile, Scrum, TDD, CI/CD
    - Soft skills: leadership, communication, problem-solving
    - Domain expertise: industry-specific knowledge
    """
    Matched_Skills: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Skills that appear in both JD and CV (exact or close matches). "
            "CRITICAL: Each item must be a SINGLE SKILL NAME (1-4 words max). "
            "Normalize case, ignore duplicates. Maximum 20 items. "
            "CORRECT examples: ['Python', 'React', 'AWS', 'Machine Learning', 'Agile']. "
            "INCORRECT examples: ['Experience with Python', 'Strong React skills', 'Knowledge of AWS services']."
        ),
    )
    Missing_Skills: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Important skills required by JD that are missing from CV. "
            "CRITICAL: Each item must be a SINGLE SKILL NAME (1-4 words max). "
            "Prioritize most critical/frequently mentioned skills. Maximum 20 items. "
            "CORRECT examples: ['Kubernetes', 'Docker', 'SQL', 'Project Management']. "
            "INCORRECT examples: ['Needs Kubernetes experience', 'Should know Docker', 'Missing SQL database skills']."
        ),
    )

class ExperienceAlignment(BaseModel):
    """
    Experience and responsibility matching between CV and job description.
    
    MATCHING RULES:
    - Compare CV experience descriptions with JD responsibilities
    - Look for: similar responsibilities, relevant achievements, related projects
    - Count only explicit matches (do not infer experience not described)
    - Use keyword-based matching:
      1. Extract key action verbs + objects from JD (e.g., "designed APIs", "led team")
      2. Search for same/similar verbs + objects in CV
      3. Count as match only if BOTH verb and object are present
    - Avoid subjective "semantic similarity" - use concrete keyword presence
    - Only count as matched if the responsibility is explicitly described in a CV bullet/description
    
    WHAT TO MATCH:
    - Core responsibilities that overlap with JD requirements
    - Achievements demonstrating required capabilities
    - Project work aligned with JD expectations
    - Management/leadership experience if required
    - Industry-specific experience
    """
    Matched_Experience: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Specific responsibilities, achievements, or experience areas from CV that align with JD requirements. "
            "Be specific: reference actual CV bullets or descriptions. Maximum 20 items. "
            "Examples: ['Led team of 5 engineers (matches JD requirement for team leadership)', "
            "'Designed RESTful APIs (matches JD API development requirement)']"
        ),
    )
    Missing_Experience: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Experience/responsibility areas required by JD that are not present or weakly represented in CV. "
            "Prioritize critical requirements. Maximum 20 items. "
            "Examples: ['No experience with microservices architecture mentioned', "
            "'JD requires database optimization experience - not found in CV']"
        ),
    )

class KeywordAnalysis(BaseModel):
    """
    Keyword extraction and matching for ATS optimization.
    
    CRITICAL FORMAT REQUIREMENT:
    - Each keyword must be a CONCISE TERM (1-4 words max)
    - NO sentences, NO descriptions, NO contextual phrases
    - Extract the CORE KEYWORD/TERM only
    
    KEYWORD EXTRACTION FROM JD:
    - Technical terms: programming languages, frameworks, tools, platforms
    - Domain-specific terminology: industry jargon, specialized concepts
    - Methodologies: Agile, DevOps, Six Sigma, etc.
    - Certifications: AWS Certified, PMP, CPA, etc.
    - Action verbs: develop, implement, optimize, manage, etc.
    - Qualifications: degree names, experience levels
    
    MATCHING RULES:
    - Normalize case for comparison (AWS = aws)
    - Match using strict criteria:
      1. Exact match after case normalization
      2. Acronyms: AWS=Amazon Web Services, API=Application Programming Interface
      3. Common technical variations: REST=RESTful, CI/CD=Continuous Integration
    - Remove duplicates before counting
    - Count only keywords explicitly present in CV
    - Do not infer keywords not written
    - When in doubt whether terms match, count as SEPARATE (prioritize consistency over flexibility)
    
    KEYWORD IMPORTANCE:
    - Prioritize role-specific keywords (highest impact on ATS)
    - Include frequently mentioned terms in JD
    - Technical skills > soft skills for most roles
    - Industry certifications highly valuable
    """
    Keywords_in_Job_Description: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Important keywords extracted from JD: role-specific terms, industry vocabulary, tools, technologies, "
            "methodologies, certifications. "
            "CRITICAL: Each item must be a SINGLE KEYWORD/TERM (1-4 words max). "
            "Prioritize most critical/frequent terms. Maximum 20 items. "
            "CORRECT examples: ['Python', 'TensorFlow', 'CI/CD', 'AWS Lambda', 'RESTful API', 'Microservices']. "
            "INCORRECT examples: ['Experience with Python required', 'Must know TensorFlow framework', 'CI/CD pipeline experience']."
        ),
    )
    Matched_Keywords: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Subset of JD keywords that are present in CV (helps with ATS matching). "
            "CRITICAL: Each item must be a SINGLE KEYWORD/TERM (1-4 words max). "
            "Normalize case, count each keyword once. Maximum 20 items. "
            "CORRECT examples: ['Python', 'AWS Lambda', 'CI/CD']. "
            "INCORRECT examples: ['Has Python experience', 'Uses AWS Lambda', 'Implemented CI/CD']."
        ),
    )
    Missing_Keywords: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Keywords from JD that do not appear in CV and should be considered for addition. "
            "CRITICAL: Each item must be a SINGLE KEYWORD/TERM (1-4 words max). "
            "Prioritize high-value, ATS-critical keywords. Maximum 20 items. "
            "CORRECT examples: ['TensorFlow', 'Microservices', 'RESTful API']. "
            "INCORRECT examples: ['Should add TensorFlow', 'Missing microservices experience', 'No RESTful API development mentioned']."
        ),
    )

class JobAlignment(BaseModel):
    """
    Evaluation of how well the resume matches the job description across skills, experience, and keywords.
    
    MATCHING FORMULA:
    Match_Score = Title/Education/Experience_Level_Alignment + Skills_Score + Keyword_Score + Experience_Score
    
    SCORING WEIGHTS (Total: 100 points):
    1. Title Match: 5 points (compare CV title with JD title)
    2. Education Level Match: 5 points (compare degree level with JD requirements)
    3. Experience Level Match: 5 points (compare years/level with JD expectations)
    4. Skills Alignment: 30 points (formula below)
    5. Keyword Alignment: 30 points (formula below)
    6. Experience Alignment: 25 points (formula below)
    
    DETAILED CALCULATIONS:
    
    1. Title/Education/Experience Level Alignment (0-15 points):
       - Title Match → True = 5 points, False = 0 points
       - Education Level Match → True = 5 points, False = 0 points
       - Experience Level Match → True = 5 points, False = 0 points
    
    2. Skills Alignment (0-30 points):
       - Extract required skills from JD
       - Extract skills from CV
       - Count matched skills (normalize case, ignore duplicates)
       - Formula: Skills_Score = (Matched_Skills / Total_Required_Skills) * 30
       - Round UP to nearest integer
       - Max: 30 points
    
    3. Keyword Alignment (0-30 points):
       - Extract important keywords from JD (tools, technologies, domain terms, methodologies)
       - Count matched keywords in CV (normalize case, ignore duplicates)
       - Formula: Keyword_Score = (Matched_Keywords / Total_Keywords) * 30
       - Round UP to nearest integer
       - Max: 30 points
    
    4. Experience Alignment (0-25 points):
       - Compare CV experience descriptions with JD responsibilities
       - Count matched responsibilities/achievements
       - Formula: Experience_Score = (Matched_Responsibilities / Total_Responsibilities) * 25
       - Round UP to nearest integer
       - Max: 25 points
    
    MATCHING RULES:
    - Count only explicit matches from CV (do not infer)
    - Normalize case when matching (Python = python)
    - Ignore duplicate matches (count each match once)
    - Use only skills/keywords/experience clearly stated in CV and JD
    - Do not assume skills/experience not written in CV
    
    MAX SCORE LIMIT:
    Final Match_Score = min(calculated_score, 100)
    """
    Match_Score: int = Field(
        ...,
        ge=0,
        le=100,
        description=(
            "0–100 holistic score reflecting resume-JD match. "
            "Formula: Match_Score = Title_Match(5) + Education_Level_Match(5) + Experience_Level_Match(5) + "
            "Skills_Score(30) + Keyword_Score(30) + Experience_Score(25). "
            "Maximum: 100 points. Round UP all intermediate calculations."
        ),
    )
    Title_Match: bool = Field(
        ...,
        description=(
            "Whether the job title in CV matches or closely aligns with JD job title. "
            "True = 5 points, False = 0 points. Strong ATS/recruiter relevance signal. "
            "Consider: exact match, close variations (e.g., 'Software Engineer' vs 'Software Developer'), "
        ))
    Experience_Level_Match: bool = Field(
        ...,
        description=(
            "Whether experience level (entry-junior/mid/senior) in CV matches JD requirements. "
            "True = 5 points, False = 0 points. Infer from: years of experience, job titles, responsibilities described. "
            "Entry-level/Junior-level: 0-2 years, Mid-level: 3-5 years, Senior: 6+ years (adjust by industry)."
        ))
    Education_Level_Match: bool = Field(
        ...,
        description=(
            "Whether education level in CV meets or exceeds JD requirements. "
            "True = 5 points, False = 0 points. Compare: High School < Associate < Bachelor < Master < PhD. "
            "Pass if CV education >= JD requirement."
        ))    
    Skills_Analysis: SkillsAnalysis = Field(
        ..., 
        description=(
            "Detailed skills match and gaps. Skills_Score = (Matched_Skills / Total_Required_Skills) * 30, max 30 points. "
            "Count explicit skill matches, normalize case, ignore duplicates."
        )
    )
    Experience_Alignment: ExperienceAlignment = Field(
        ..., 
        description=(
            "Experience matches and missing areas. Experience_Score = (Matched_Responsibilities / Total_Responsibilities) * 25, max 25 points. "
            "Compare CV experience descriptions with JD responsibilities. Count explicit matches only."
        )
    )
    Keyword_Analysis: KeywordAnalysis = Field(
        ..., 
        description=(
            "Keywords extracted from JD and match/miss results. Keyword_Score = (Matched_Keywords / Total_Keywords) * 30, max 30 points. "
            "Extract tools, technologies, domain terms, methodologies. Count explicit matches, normalize case."
        )
    )

class IndustryKeywordOptimization(BaseModel):
    """
    Industry and role-specific keyword recommendations for ATS optimization.
    
    PURPOSE:
    - Identify important keywords not in CV, even if missing from JD
    - Improve ATS discoverability and recruiter searchability
    - Enhance relevance for target role and industry
    
    KEYWORD SOURCES:
    - Industry-standard terms for the role
    - Common tools/technologies in the field
    - Certifications valuable for the position
    - Methodologies widely used in the industry
    - Emerging trends relevant to the role
    
    PLACEMENT STRATEGY:
    - Skills section: technical skills, tools, methodologies
    - Work Experience: action verbs, technologies used, achievements
    - Summary/Objective: role-specific keywords, value proposition
    - Certifications: credential names, issuing organizations
    - Projects: technologies, methodologies, outcomes
    
    PLACEMENT RULES:
    - Place keywords naturally (avoid keyword stuffing)
    - Use context-appropriate placement
    - Maintain readability and flow
    - Integrate keywords into existing content when possible
    """
    Recommended_Keywords: List[str] = Field(
        default_factory=list,
        max_length=20,
        description=(
            "Industry/role-specific keywords recommended but missing from CV. "
            "CRITICAL: Each item must be a SINGLE KEYWORD/TERM (1-4 words max). "
            "Include terms important for ATS and recruiter search, even if not in JD. "
            "Prioritize high-value, industry-standard terms. Maximum 20 items. "
            "CORRECT examples: ['Scrum', 'Data Visualization', 'API Integration', 'Cloud Architecture', 'GDPR Compliance']. "
            "INCORRECT examples: ['Should learn Scrum methodology', 'Experience with data visualization tools', 'Knowledge of API integration']."
        ),
    )
    Suggestions: List[str] = Field(
        default_factory=list,
        max_length=10,
        description=(
            "Actionable suggestions for WHERE to place missing keywords naturally. "
            "Map each keyword to a specific section/location. Be specific and implementable. Maximum 10 items. "
            "Examples: "
            "['Add \"Docker\" and \"Kubernetes\" to Skills section under DevOps Tools', "
            "'Include \"Agile/Scrum methodology\" in Work Experience bullet for Project Manager role', "
            "'Add \"Database optimization\" to Summary highlighting performance improvement expertise', "
            "'Create Certifications section to add \"AWS Solutions Architect\" credential']"
        ),
    )

class ATSAnalysisResponse(BaseModel):
    """
    Top-level model for comprehensive ATS & job-alignment analysis output.
    
    ============================================================================
    IMPORTANT RULES FOR ANALYSIS
    ============================================================================
    
    GENERAL:
    - Follow evaluation steps and scoring rules exactly
    - Use only provided inputs (CV, JD, CVLayoutAnalysis)
    - Do not assume missing information
    - All outputs must be actionable and specific
    
    SCORING:
    - Sections 1 & 2 use binary checks: PASS or FAIL only
    - Score formula: Score = (Passed_Checks / Total_Checks) * 100
    - Round all calculated scores UP to nearest integer
    - Apply score caps so values never exceed maximum limits
    - If CVLayoutAnalysis field is null/None, treat as PASS
    
    MAX SCORE LIMITS:
    - ATS_Readability_Score ≤ 100
    - Content_Quality_Score ≤ 100
    - Skills_Score ≤ 30
    - Keyword_Score ≤ 30
    - Experience_Score ≤ 25
    - Title/Education/Experience Alignment ≤ 15
    - Match_Score ≤ 100
    
    FINAL SCORE RULE:
    final_score = min(ceil(calculated_score), max_allowed_score)
    
    BINARY CHECKS:
    - Each check must return either PASS or FAIL
    - No partial credit or intermediate states
    - Null/None layout fields = PASS
    
    MATCHING RULES:
    - Count only explicit matches from CV
    - Do not infer skills, keywords, or experience not written in CV
    - Normalize case when matching (Python = python)
    - Remove duplicates before counting (count each match once)
    - Consider semantic similarity for experience matching
    
    OUTPUT REQUIREMENTS:
    - Follow required JSON structure exactly
    - All calculations must be mathematically correct
    - All tips and suggestions must be specific and actionable
    - Avoid generic advice (e.g., "improve your resume")
    - Provide concrete examples in Improvement_Tips
    
    ============================================================================
    """
    ATS_Readability_Analysis: ATSReadabilityAnalysis = Field(
        ..., 
        description=(
            "Detailed analysis of ATS readability with 19 binary checks covering structure, formatting, "
            "page setup, parsing compatibility, date formats, and file quality. Score = (Passed/19)*100, max 100."
        )
    )
    Content_Quality_Analysis: ContentQualityAnalysis = Field(
        ..., 
        description=(
            "Detailed analysis of content quality with 13 binary checks covering essential sections, contact info, "
            "writing quality, action verbs, and quantifiable achievements. Score = (Passed/13)*100, max 100."
        )
    )
    Section_Analysis: SectionAnalysis = Field(
        ..., 
        description=(
            "Per-section Pass/Fail evaluation with detailed notes. Evaluates: Contact_Info (Name/Email/Phone required), "
            "Work_Experience (bullets, achievements, required fields), Education (degree, institution, dates), "
            "Skills (≥5 relevant, ATS-friendly), Additional_Sections (relevance, value-add)."
        )
    )
    Job_Alignment: Optional[JobAlignment] = Field(
        None, 
        description=(
            "CV vs JD matching analysis. Match_Score (0-100) = Title(5) + Education(5) + Experience_Level(5) + "
            "Skills(30) + Keywords(30) + Experience(25). Includes detailed breakdowns for each component."
        )
    )
    Industry_Keyword_Optimization: IndustryKeywordOptimization = Field(
        ...,
        description=(
            "Industry/role-specific keyword recommendations not in CV (even if missing from JD). "
            "Includes specific placement suggestions for natural integration."
        )
    )
    ATS_Issues: List[str] = Field(
        default_factory=list,
        max_length=10,
        description=(
            "Specific technical/formatting issues that could break ATS parsing. Be granular and actionable. Maximum 10 items. "
            "Examples: 'Table detected in Work Experience section - move to plain text format', "
            "'Critical contact info (phone number) located in header - ATS may not parse it', "
            "'Images/icons used for skills - replace with text', "
            "'Special characters in filename (CV@2024#final.pdf) - use alphanumeric only', "
            "'Date format inconsistent (some MM/YYYY, some spelled out) - standardize to MM/YYYY'"
        ),
    )
    Improvement_Tips: List[str] = Field(
        default_factory=list,
        max_length=10,
        description=(
            "Highly specific, actionable improvement tips with examples. Maximum 10 items. "
            "Examples: "
            "'Rewrite Work Experience bullet: \"Responsible for managing projects\" → \"Managed 8+ cross-functional projects, delivering $200K in cost savings\"', "
            "'Add quantifiable metric to achievement: \"Improved system performance\" → \"Optimized database queries, reducing load time by 45%\"', "
            "'Add missing keyword \"Python\" to Skills section - mentioned 3 times in JD requirements', "
            "'Move Summary section to top (currently after Experience) for better ATS parsing', "
            "'Expand Education section: add graduation date (2020) and relevant coursework (Machine Learning, Data Structures)'"
        ),
    )