from google import genai
from dotenv import load_dotenv
import os
import re
import time
import json
from itertools import cycle
from typing import List, Dict, Any
from .summary_builder import build_job_summary

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


class LLMExplainer:
    
    def explain_jobs(self, cv_summary: str, jobs: List[dict]) -> List[str]:
        """
        Send 5 job summaries in ONE request and return 5 explanations.
        """
        # Build the prompt with all 5 jobs
        jobs_text = ""
        for i, job in enumerate(jobs, 1):
            job_summary = build_job_summary(job.get("description_full", ""))
            matches_preferences = job.get("matches_preferences", False)
            is_fallback = job.get("is_fallback", False)
            
            # Choose template based on job type
            if matches_preferences:
                template = "This job matches your preferences. We found strong alignment between your CV and this role, especially in: [mention specific skills, experience, or domains]."
            else:
                template = "This job is an alternative option. However, we still found strong alignment between your CV and this role, especially in: [mention specific skills, experience, or domains]."
            
            jobs_text += f"Job {i}:\n"
            jobs_text += f"Title: {job.get('title', '')}\n"
            jobs_text += f"Summary: {job_summary}\n"
            jobs_text += f"Template: {template}\n\n"
        
        prompt = f"""
You are a career advisor. You have a candidate's CV summary and 5 job summaries below.

Candidate CV Summary:
{cv_summary}

{5 * '='} JOBS {5 * '='}
{jobs_text}

For each job, write a short explanation (2-3 sentences) in English following its template.
Replace the bracketed part with specific details from the comparison.

Return ONLY valid JSON in this exact format, no other text, no markdown:
{{
    "explanations": [
        "Explanation for Job 1",
        "Explanation for Job 2",
        "Explanation for Job 3",
        "Explanation for Job 4",
        "Explanation for Job 5"
    ]
}}
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
                print("RAW EXPLANATION RESPONSE:", raw_text[:500])
                
                # Clean response
                clean_text = re.sub(r"```json|```", "", raw_text).strip()
                result = json.loads(clean_text)
                
                explanations = result.get("explanations", [])
                
                return explanations
                
            except Exception as e:
                print(f"LLM explanation attempt {attempt+1} failed with key ending ...{current_key[-10:]}: {str(e)}")
                time.sleep(2)
        
        # Fallback: return empty explanations
        return [""] * len(jobs)


def explain_top_jobs(cv_summary: str, top_jobs: List[dict]) -> List[dict]:
    """
    Generate explanations for top 5 jobs and attach them.
    """
    explainer = LLMExplainer()
    
    # Get explanations for all jobs in one request
    explanations = explainer.explain_jobs(cv_summary, top_jobs)
    
    # Attach each explanation to its job
    for i, job in enumerate(top_jobs):
        if i < len(explanations) and explanations[i]:
            job["explanation"] = explanations[i]
        else:
            # Fallback explanation
            if job.get("matches_preferences", False):
                job["explanation"] = "This job matches your preferences. We found strong alignment between your CV and this role, especially in key skills and experience."
            else:
                job["explanation"] = "This job is an alternative option. However, we still found strong alignment between your CV and this role."
    
    return top_jobs