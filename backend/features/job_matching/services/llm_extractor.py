from google import genai
from dotenv import load_dotenv
import json
import os
import re
import time
from itertools import cycle
from typing import Dict, Any

load_dotenv()

# Load multiple Gemini keys
GEMINI_API_KEYS = [
    os.getenv("GEMINI_API_KEY_1"),
    os.getenv("GEMINI_API_KEY_2"),
    os.getenv("GEMINI_API_KEY_3"),
]
GEMINI_API_KEYS = [k for k in GEMINI_API_KEYS if k]

# Create round-robin cycler
_gemini_cycler = cycle(GEMINI_API_KEYS)

def get_next_gemini_key() -> str:
    """Get next Gemini API key in round-robin fashion."""
    return next(_gemini_cycler)


class CVLLMParser:

    def extract_cv(self, cv_text: str, job_title: str) -> Dict[str, Any]:
        """
        Extract structured information from CV with job-aware weighting
        """
        cv_text = cv_text[:10000]  # Limit length

        prompt = f"""
You are a strict and expert ATS CV parser.

Your task is to extract structured information from a CV in a JOB-AWARE way.

-------------------------
CRITICAL RULES:
-------------------------
- Return ONLY valid JSON
- No explanation
- No extra text
- No markdown
- Use lowercase for everything
- Remove duplicates
- Be aggressive in extraction (do not miss useful info)
- If something is implied → infer it
- Do NOT leave fields empty if any signal exists
- Do NOT hallucinate

-------------------------
SKILLS RULES (TECHNICAL ONLY):
-------------------------
SKILLS RULES:
- Extract technical skills from CV
- For each skill, provide:
    - "name": the skill as written in CV (original form)
    - "synonym": the full form if it's an abbreviation (e.g., "ML" → "Machine Learning")
    - ALSO: if the skill is written in full form, provide its common abbreviation as a synonym
    - If the skill has no abbreviation/full form, leave synonym empty
- Examples:
    {{"name": "SQL", "synonym": "Structured Query Language"}}
    {{"name": "Python", "synonym": ""}}
    {{"name": "ML", "synonym": "Machine Learning"}}
    {{"name": "K8s", "synonym": "Kubernetes"}}
    {{"name": "AWS", "synonym": "Amazon Web Services"}}
    {{"name": "machine learning", "synonym": "ml"}}
    {{"name": "structured query language", "synonym": "sql"}}

-------------------------
TOOLS RULES:
-------------------------
- Extract only tools, frameworks, libraries, platforms
- Examples: tensorflow, pytorch, docker, aws, qiskit
- DO NOT include programming languages or basic web tech (html, css, javascript)

-------------------------
CERTIFICATIONS RULES:
-------------------------
- Extract professional certifications
- Examples: "aws certified solutions architect", "pmp", "scrum master", "tensorflow developer certificate"
- Include both full names and abbreviations
- Do NOT include degrees or academic qualifications (those go in education)

-------------------------
EXPERIENCE RULES:
-------------------------
- Extract years if explicitly mentioned
- Return total years of REAL WORK EXPERIENCE ONLY as an INTEGER (whole number)
- Round down: 3 years 6 months → 3, 4 years 11 months → 4
- Include internships in real companies, paid/unpaid industry jobs
- DO NOT include university projects, coursework, or personal projects
- If less than 1 year, return 0

-------------------------
JOB TITLES RULES:
-------------------------
- Extract relevant job roles from CV
- Remove irrelevant roles
- Order by relevance to the given job title

-------------------------
DOMAINS RULES:
-------------------------
- Extract fields of expertise
- Examples: data science, artificial intelligence, web development, machine learning

-------------------------
SENIORITY RULES:
-------------------------
- Determine seniority level based on experience years and job titles
- Use ONLY these exact values:
    "junior" → 0-2 years experience OR titles containing: intern, trainee, junior, entry level, fresh graduate
    "mid" → 2-5 years experience OR titles containing: mid level, intermediate, associate
    "senior" → 5+ years experience OR titles containing: senior, lead, principal, staff
- Return only: "junior", "mid", or "senior"

-------------------------
OUTPUT FORMAT (MUST MATCH EXACTLY):
-------------------------
{{
  "skills": [
    {{"name": "sql", "synonym": "structured query language"}}
  ],
  "tools": ["docker", "kubernetes"],
  "experience_years": 4,
  "job_titles": ["backend engineer", "software developer"],
  "education": "bachelor of computer science",
  "seniority": "mid",
  "domains": ["data science", "web development"],
  "languages": ["arabic", "english"],
  "certifications": ["aws certified", "scrum master"]
}}

-------------------------
FALLBACK RULES:
-------------------------
- [] for lists
- 0 for numbers
- "unknown" for strings
- "junior" for seniority if can't determine

-------------------------
JOB TITLE:
{job_title}

-------------------------
CV:
\"\"\"{cv_text}\"\"\"
"""
        
        # Retry logic with multiple keys
        for attempt in range(len(GEMINI_API_KEYS) * 2):
            current_key = get_next_gemini_key()
            client = genai.Client(api_key=current_key)
            
            try:
                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt
                )

                raw_text = response.text.strip()
                print(f"RAW RESPONSE (key ending ...{current_key[-10:]}):", raw_text[:300])

                clean_text = re.sub(r"```json|```", "", raw_text).strip()
                result = json.loads(clean_text)
                
                # Ensure experience_years is integer
                if "experience_years" in result:
                    result["experience_years"] = int(result["experience_years"])
                
                # Ensure certifications exists
                if "certifications" not in result:
                    result["certifications"] = []
                
                # Ensure soft_skills is removed if exists
                if "soft_skills" in result:
                    del result["soft_skills"]
                
                return result

            except Exception as e:
                print(f"Attempt {attempt+1} failed with key ending ...{current_key[-10:]}: {str(e)}")
                time.sleep(2)

        # Fallback return
        return {
            "skills": [],
            "tools": [],
            "experience_years": 0,
            "job_titles": [],
            "education": "unknown",
            "seniority": "unknown",
            "domains": [],
            "languages": [],
            "certifications": []
        }


# ==================== Wrapper function ====================

def extract_cv_info(cv_text: str, job_title: str) -> Dict[str, Any]:
    """
    Wrapper function to extract CV info
    """
    parser = CVLLMParser()
    return parser.extract_cv(cv_text, job_title)