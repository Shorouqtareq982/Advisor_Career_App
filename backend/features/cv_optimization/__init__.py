"""CV Optimization feature module."""


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
[x] Update all used methods to be asynchronous to improve performance and scalability.
[x] Create Layout analysis for cv
[ ] Test the CV analysis process with various CV formats and job descriptions to ensure robustness and accuracy.
[ ] Consider adding a retry mechanism for transient errors, especially for file uploads and LLM interactions.
[ ] Implement rate limiting or queuing for CV analysis requests to manage load and ensure fair usage.

TODO 2:
[ ] recheck job aligment score
[ ] method to detect cv sections
[x] recheck on buzzwords and action verbs to make sure they are relevant and up-to-date with current industry standards
[x] preseve new line in cv text extraction
[x] move section analysis to be implemented in python instead of depend on llm
[x] for masking add pattern based masking in addition to library based masking
[x] enhance ats_issues / content_issues to be user friendly feedback
[x] improve cv parsing prompt to reduce llm hallucination caused by masking 
[x] for unmasking make sure the llm keep the same format of the masked tokens and doesn't change them in a way that makes it impossible to unmask them later
[ ] add more test cases for the masking and unmasking process to ensure its reliability and robustness
"""