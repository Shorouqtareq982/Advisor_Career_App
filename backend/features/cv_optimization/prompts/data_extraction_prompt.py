JOB_DATA_EXTRACTOR = """
<task>
Identify the key details from a job description and company overview to create a structured JSON output. Focus on extracting the most crucial and concise information that would be most relevant for tailoring a resume to this specific job.
</task>

<job_description>
{job_description}
</job_description>

Note: The "keywords", "job_duties_and_responsibilities", and "required_qualifications" sections are particularly important for resume tailoring. Ensure these are as comprehensive and accurate as possible.

"""

CV_DATA_EXTRACTOR = """<objective>
Parse a text-formatted resume efficiently and extract the applicant's data into a structured JSON format.
Ensure all fields are JSON-serializable.
Automatically normalize URLs and emails to valid, complete formats.
</objective>

<input>
The following text is the applicant's resume in plain text format:

{cv_text}
</input>

<instructions>
Follow these steps carefully to extract and structure the resume information:

1. Analyze Structure:
   - Identify key sections such as personal information, contact details, education, work experience, projects, skills, certifications, and media links.
   - Note any variations in formatting, section names, or order.

2. Extract Information:
   - For each section, extract relevant details like names, titles, organizations, descriptions, and dates.
   - For media links (LinkedIn, GitHub, Medium, Devpost):
       - Ensure each URL is fully qualified.
       - If a URL is missing the "http://" or "https://", prepend "https://".
       - If a URL is incomplete or malformed, attempt to reconstruct a valid link based on common patterns.
   - For email addresses:
       - Ensure they follow standard email format (user@domain.com).
       - If missing domain, mark as null.

3. Handle Variations:
   - Support different resume styles, formats, and section arrangements.
   - Capture all available information even if some sections are missing or in an unusual order.

4. Optimize Output:
   - Represent missing information with null, empty arrays, or empty objects as appropriate.
   - Standardize date formats (e.g., YYYY-MM-DD or Month YYYY) when possible.
   - Deduplicate repeated entries if any.

5. Validate:
   - Check that all extracted fields are consistent and complete.
   - Ensure required fields exist if the information is present in the resume.
   - Verify that URLs and emails are valid formats.

6. Output Format:
   - Return **only a single JSON object** containing the structured resume data.
   - All URLs and emails must be valid and fully qualified.
   - Do not include any extra text, explanations, or comments outside the JSON.
</instructions>
"""
