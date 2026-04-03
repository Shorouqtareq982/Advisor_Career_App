"""
Advanced Level Detector - Analyzes skill levels from CV using LLM with fallback support
"""
import json
import logging
import re
import inspect
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, ValidationError

from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider

logger = logging.getLogger(__name__)

# =====================================================
# PYDANTIC SCHEMAS - Data models for type validation
# =====================================================
class SkillLevelAssessment(BaseModel):
    """Represents assessment of a single skill"""
    skill: str
    level: str  # one of: none, beginner, intermediate, advanced
    confidence: float  # 0.0 to 1.0
    reasoning: str
    evidence: Optional[str] = None


class CVSkillLevelAnalysis(BaseModel):
    """Complete analysis result from LLM"""
    skills: List[SkillLevelAssessment]
    overall_level: str
    overall_confidence: float
    summary: str

# =====================================================
# PROMPT
# =====================================================
SKILL_LEVEL_ANALYSIS_PROMPT = """
Analyze this CV to determine the skill level for each of the listed skills.
Return ONLY a valid JSON object with no additional text.

CV TEXT:
{cv_text}

SKILLS TO ANALYZE:
{skills_list}

Total experience years: {experience_years}
Job titles: {job_titles}

Levels: "none" (no experience), "beginner" (basic knowledge), "intermediate" (worked on projects), "advanced" (expert, could teach others).

For each skill, provide:
- skill: exact name as listed
- level: one of none/beginner/intermediate/advanced
- confidence: float between 0 and 1
- reasoning: short explanation
- evidence: specific phrase from CV that supports this level (or null)

Also provide overall_level (average level across skills), overall_confidence, and a summary.

Example output format:
{{
  "skills": [
    {{"skill": "Python", "level": "intermediate", "confidence": 0.85, "reasoning": "Used in multiple projects", "evidence": "Developed web apps with Django"}}
  ],
  "overall_level": "intermediate",
  "overall_confidence": 0.8,
  "summary": "Solid mid-level developer with Python expertise"
}}
"""

class LevelDetector:
    """
    Detects skill levels from CV text using LLM with multiple attempts and fallback strategies.
    
    This class:
    1. Extracts metadata from parsed CV (years of experience, job titles)
    2. Makes up to 3 attempts to analyze with different CV sections
    3. Attempts emergency fallback if all attempts fail
    4. Returns structured skill level assessments with confidence scores
    """

    def __init__(self, llm: LLMProvider = None):
        """
        Initialize the Level Detector.
        
        Args:
            llm: LLM provider instance. If None, creates default Gemini provider.
        """
        self.llm = llm or create_llm_provider()
        self.debug_logs = []
        
        # Validate LLM provider is initialized
        if not self.llm:
            logger.error("LLM Provider is not initialized - this will cause all analysis to fail")
            self.debug_logs.append("WARNING: LLM provider is None")
        else:
            logger.info(f"LLM Provider initialized: {type(self.llm).__name__}")

    async def detect_skill_levels(
        self,
        cv_text: str,
        parsed_cv_data: Dict[str, Any],
        required_skills: List[str]
    ) -> Dict[str, Any]:
        """
        Main method to detect skill levels from a CV.
        
        Applies retry logic with multiple attempts:
        - Attempt 1: First 800 chars of CV
        - Attempt 2: Middle section (chars 200-1000)
        - Attempt 3: Last 800 chars of CV
        
        Args:
            cv_text: Raw CV text content
            parsed_cv_data: Pre-parsed CV data (contains experience, education, etc.)
            required_skills: List of skill names to analyze
            
        Returns:
            Dictionary containing:
            - skill_levels: List of skill assessments with confidence
            - overall_level: Average skill level
            - overall_confidence_badge: Confidence indicator (High/Good/Medium/Low)
            - summary: LLM-generated summary
            - analysis_method: Either 'llm' or 'fallback'
            - debug_logs: Trace of analysis attempts
        """
        logger.info(f"Starting analysis of {len(required_skills)} skills...")
        self.debug_logs = [f"Required skills: {required_skills}"]

        # Extract CV metadata for context
        experience_years = self._extract_experience_years(parsed_cv_data)
        job_titles = self._extract_job_titles(parsed_cv_data)
        self.debug_logs.append(f"Experience years: {experience_years}, Job titles: {job_titles}")

        # Attempt LLM analysis up to 3 times with different CV sections
        analysis = None
        for attempt in range(3):
            logger.info(f"Attempt {attempt + 1}/3...")
            self.debug_logs.append(f"--- Attempt {attempt + 1} ---")
            
            # Quick check: ensure LLM provider is initialized
            if not self.llm:
                logger.error("LLM provider is not initialized!")
                self.debug_logs.append("ERROR: LLM provider is None")
                break
            
            analysis = await self._analyze_with_llm(
                cv_text=cv_text[:3000],
                skills_list=required_skills,
                experience_years=experience_years,
                job_titles=job_titles,
                attempt=attempt
            )
            
            if analysis:
                logger.info(f"Success on attempt {attempt + 1}")
                self.debug_logs.append(f"Success on attempt {attempt + 1}")
                break
            else:
                logger.warning(f"Failed attempt {attempt + 1}")
                self.debug_logs.append(f"Failed attempt {attempt + 1}")

        # If all attempts failed, use fallback detection
        if not analysis:
            logger.error("All LLM attempts failed, attempting hybrid skill extraction")
            self.debug_logs.append("All standard attempts failed")
            
            # Final attempt with absolute minimum prompt
            analysis = await self._emergency_simple_analysis(required_skills)
            
            if not analysis:
                logger.error("Emergency analysis failed, attempting hybrid extraction")
                self.debug_logs.append("Emergency analysis failed, attempting hybrid extraction")
                
                # Try hybrid extraction using regex and keywords
                analysis = await self._hybrid_skill_detection(cv_text, required_skills)

            
            if not analysis:
                logger.error("All analysis methods failed, using fallback detection")
                self.debug_logs.append("All methods failed, using fallback")
                result = self._fallback_detection(required_skills)
                result['debug_logs'] = self.debug_logs
                return result
            
            self.debug_logs.append("Success with hybrid skill detection")

        # Format and return successful result
        result = self._format_response(analysis, required_skills)
        result['debug_logs'] = self.debug_logs
        return result

    async def _analyze_with_llm(
        self,
        cv_text: str,
        skills_list: List[str],
        experience_years: Optional[int],
        job_titles: List[str],
        attempt: int
    ) -> Optional[CVSkillLevelAnalysis]:
        """
        Performs a single LLM analysis attempt with error handling.
        
        Uses different sections of CV for each attempt to work around
        safety filters or API response issues.
        
        Args:
            cv_text: Full CV text (will be truncated per attempt)
            skills_list: Skills to analyze
            experience_years: Years of experience (for context)
            job_titles: Job titles mentioned in CV
            attempt: Attempt number (0, 1, or 2) - determines which CV section to use
            
        Returns:
            Parsed CVSkillLevelAnalysis or None if failed
        """
        # Format skills and titles for prompt
        skills_formatted = "\n".join([f"- {skill}" for skill in skills_list])
        titles_formatted = ", ".join(job_titles[:3]) if job_titles else "N/A"

        # Select different CV section based on attempt number
        if attempt == 0:
            cv_sample = cv_text[:800]  # First section
        elif attempt == 1:
            cv_sample = cv_text[200:1000] if len(cv_text) > 1000 else cv_text  # Middle section
        else:
            cv_sample = cv_text[-800:] if len(cv_text) > 800 else cv_text  # Last section

        # Build prompt with CV context
        prompt = SKILL_LEVEL_ANALYSIS_PROMPT.format(
            cv_text=cv_sample,
            skills_list=skills_formatted,
            experience_years=experience_years or 0,
            job_titles=titles_formatted
        )

        logger.debug(f"Prompt length: {len(prompt)}")
        self.debug_logs.append(f"Prompt (first 200 chars): {prompt[:200]}...")

        try:
            # Call LLM with JSON output requirement
            response = await self.llm.get_response(
                prompt=prompt[:4000],
                need_json_output=True,
                temperature=0.1
            )
            
            # Handle if response is a coroutine (async not awaited)
            if inspect.iscoroutine(response):
                response = await response

            self.debug_logs.append(f"Raw response type: {type(response)}")

            # Check for empty response
            if response is None:
                logger.error(f"LLM returned None on attempt {attempt + 1}")
                self.debug_logs.append(f"LLM returned None - Provider may not be initialized or API error")
                return None
            
            # Check if response is truly empty
            response_str = str(response).strip()
            if not response_str or response_str.lower() in ['none', 'error', 'null']:
                logger.error(f"LLM returned empty/invalid on attempt {attempt + 1}: {response_str}")
                self.debug_logs.append(f"LLM returned empty/invalid: {response_str}")
                return None

        except Exception as e:
            logger.warning(f"LLM call failed on attempt {attempt + 1}: {type(e).__name__}: {e}")
            self.debug_logs.append(f"LLM call exception: {type(e).__name__}: {str(e)}")
            return None

        # Extract text from response (handles multiple response formats)
        raw_text = self._extract_raw_text(response)
        if not raw_text.strip():
            logger.error("Empty response from LLM")
            self.debug_logs.append("Empty response from LLM")
            return None

        logger.debug(f"Raw text preview: {raw_text[:200]}")
        self.debug_logs.append(f"Raw text preview: {raw_text[:200]}")

        # Parse JSON from response text
        json_data = self._aggressive_json_parse(raw_text)
        if not json_data:
            logger.error("No valid JSON found in response")
            self.debug_logs.append("No valid JSON found")
            return None

        # Validate and construct Pydantic model
        try:
            analysis = CVSkillLevelAnalysis(**json_data)
            self.debug_logs.append(f"Parsed {len(analysis.skills)} skills from JSON")
            return analysis
        except ValidationError as e:
            logger.error(f"Pydantic validation failed: {e}")
            self.debug_logs.append(f"Pydantic error: {e}")
            # Attempt to repair incomplete data
            return self._repair_analysis(json_data, skills_list)

    async def _hybrid_skill_detection(
        self,
        cv_text: str,
        skills_list: List[str]
    ) -> CVSkillLevelAnalysis:
        """
        Hybrid skill detection using regex patterns and keyword matching.
        
        Analyzes CV text for skill mentions and extracts proficiency levels
        based on context keywords without requiring LLM. This provides
        reasonable estimates when LLM fails.
        
        Args:
            skills_list: Skills to analyze
            cv_text: Raw CV text
            
        Returns:
            CVSkillLevelAnalysis with hybrid-detected skill levels
        """
        logger.info("Attempting hybrid skill detection via regex/keywords...")
        self.debug_logs.append("--- Hybrid Skill Detection Attempt ---")
        
        import re
        
        skill_analyses = {}
        cv_lower = cv_text.lower()
        
        # Keywords indicating different proficiency levels
        beginner_keywords = [
            r'\bfamiliar\s+with\b', r'\bbasic\s+knowledge\b', r'\blearning\b',
            r'\bstudent\b', r'\bintrodu(?:ced|ction)\b', r'\bnovice\b',
            r'\bfundamental', r'\bstarting\s+to\s+learn\b'
        ]
        
        intermediate_keywords = [
            r'\bexperience\s+with\b', r'\bworked\s+with\b', r'\bproficient\s+in\b',
            r'\bknowledgeable\b', r'\bpractical\s+experience\b', r'\bregular\b',
            r'\bcomfortable\s+with\b', r'\bsolid\s+(?:knowledge|experience)\b',
            r'\b\d+\s+years?\s+(?:of\s+)?experience\b'
        ]
        
        advanced_keywords = [
            r'\bexpert\b', r'\bspecialist\b', r'\bmastered\b', r'\bsenior\s+(?:like|level)\b',
            r'\bdeep\s+(?:knowledge|expertise)\b', r'\b(?:5|six|seven|eight|nine|10)\+?\s+years\b',
            r'\bleading\b', r'\barchitect(?:ed|ure)?\b', r'\blead\s+(?:developer|engineer)\b',
            r'\btutor(?:ed)?\b', r'\bmentored?\b'
        ]
        
        for skill in skills_list:
            confidence = 0.4  # Baseline confidence for hybrid detection
            level = "beginner"
            experience_years = 0
            job_titles = []
            
            # Search for skill mentions (case-insensitive)
            skill_pattern = r'\b' + re.escape(skill.lower()) + r'\b'
            matches = list(re.finditer(skill_pattern, cv_lower))
            
            if not matches:
                # Skill not mentioned in CV - assign beginner with low confidence
                logger.debug(f"Skill '{skill}' not found in CV text")
                skill_analyses[skill] = {
                    "level": "beginner",
                    "confidence": 0.2,
                    "experience_years": 0,
                    "justification": "Skill not mentioned in CV"
                }
                continue
            
            logger.debug(f"Found {len(matches)} mentions of skill '{skill}'")
            
            # Analyze context around each match
            for match in matches:
                start = max(0, match.start() - 150)
                end = min(len(cv_text), match.end() + 150)
                context = cv_lower[start:end]
                
                # Check for level indicators in context
                for adv_pattern in advanced_keywords:
                    if re.search(adv_pattern, context):
                        level = "advanced"
                        confidence = min(0.9, confidence + 0.15)
                        break
                
                if level != "advanced":
                    for int_pattern in intermediate_keywords:
                        if re.search(int_pattern, context):
                            level = "intermediate"
                            confidence = min(0.85, confidence + 0.10)
                            break
                
                if level == "beginner":
                    for beg_pattern in beginner_keywords:
                        if re.search(beg_pattern, context):
                            level = "beginner"
                            confidence = min(0.7, confidence + 0.05)
                            break
                
                # Extract experience years if present
                year_match = re.search(r'(\d+)\+?\s+years?\s+(?:of\s+)?(?:experience|expertise)', context)
                if year_match:
                    years = int(year_match.group(1))
                    experience_years = max(experience_years, years)
                    # Adjust level based on years
                    if years >= 5 and level != "advanced":
                        level = "intermediate"
                    elif years >= 3 and level == "beginner":
                        level = "intermediate"
            
            # Ensure confidence is reasonable
            if experience_years >= 5:
                if level == "beginner":
                    level = "intermediate"
                confidence = min(0.85, confidence + 0.1)
            
            skill_analyses[skill] = {
                "level": level,
                "confidence": min(0.9, max(0.3, confidence)),
                "experience_years": experience_years,
                "justification": f"Found {len(matches)} mention(s) of '{skill}' in CV"
            }
        
        # Construct response with proper schema
        skills = []
        overall_confidence = 0.0
        level_counts = {"beginner": 0, "intermediate": 0, "advanced": 0}
        
        for skill in skills_list:
            analysis = skill_analyses.get(skill, {
                "level": "beginner",
                "confidence": 0.3,
                "experience_years": 0,
                "justification": "Default analysis"
            })
            
            level = analysis["level"]
            level_counts[level] = level_counts.get(level, 0) + 1
            
            # Create SkillLevelAssessment object with correct field names
            skills.append(SkillLevelAssessment(
                skill=skill,
                level=level,
                confidence=analysis["confidence"],
                reasoning=analysis["justification"],
                evidence=f"Regex/keyword analysis: {analysis['experience_years']} years mentioned"
            ))
            overall_confidence += analysis["confidence"]
        
        overall_confidence = overall_confidence / len(skills_list) if skills_list else 0.3
        
        # Determine overall level (most common level among skills)
        overall_level = max(level_counts.items(), key=lambda x: x[1])[0] if level_counts else "beginner"
        
        result = CVSkillLevelAnalysis(
            skills=skills,
            overall_level=overall_level,
            overall_confidence=overall_confidence,
            summary="Analysis based on keyword matching and pattern recognition from CV text"
        )
        
        logger.info(f"Hybrid detection completed: {len(skills)} skills analyzed")
        self.debug_logs.append(f"Hybrid detection: {len(skills)} skills analyzed")
        return result


    async def _emergency_simple_analysis(
        self, 
        skills_list: List[str]
    ) -> Optional[CVSkillLevelAnalysis]:
        """
        Final emergency fallback - attempts absolute minimum analysis.
        
        Used when all standard attempts fail. Creates a simple prompt
        and tries to get any response from the LLM.
        
        Args:
            skills_list: Skills to analyze
            
        Returns:
            CVSkillLevelAnalysis with basic assessments or None if completely fails
        """
        logger.info("Attempting emergency simple analysis...")
        self.debug_logs.append("--- Emergency Simple Attempt ---")
        
        # Extremely simple prompt without complex JSON expectations
        simple_prompt = f"For these skills: {', '.join(skills_list[:5])}, rate each as beginner/intermediate/advanced. Respond with JSON only."
        
        try:
            logger.debug(f"Emergency prompt: {simple_prompt}")
            response = await self.llm.get_response(
                prompt=simple_prompt,
                need_json_output=True,
                temperature=0.05  # Even more deterministic
            )
            
            if inspect.iscoroutine(response):
                response = await response
            
            self.debug_logs.append(f"Emergency response type: {type(response)}")
            
            if response is None:
                logger.error("Emergency analysis: LLM returned None")
                self.debug_logs.append("Emergency: LLM returned None")
                return None
            
            # Extract text from any response format
            raw_text = self._extract_raw_text(response)
            if not raw_text.strip():
                logger.error("Emergency analysis: Empty response")
                self.debug_logs.append("Emergency: Empty response")
                return None
            
            self.debug_logs.append(f"Emergency response text: {raw_text[:150]}")
            
            # Try to parse JSON - be very lenient
            json_data = self._aggressive_json_parse(raw_text)
            if json_data:
                # Attempt to create analysis from whatever we got
                try:
                    analysis = CVSkillLevelAnalysis(**json_data)
                    logger.info("Success: Emergency analysis created valid result")
                    self.debug_logs.append("Emergency analysis succeeded")
                    return analysis
                except ValidationError:
                    logger.warning("Emergency JSON validation failed, attempting repair")
                    return self._repair_analysis(json_data, skills_list)
            
            logger.error("Emergency analysis: No valid JSON found")
            self.debug_logs.append("Emergency: No JSON found")
            return None
            
        except Exception as e:
            logger.error(f"Emergency analysis error: {e}")
            self.debug_logs.append(f"Emergency error: {str(e)}")
            return None

    def _extract_raw_text(self, response) -> str:
        """
        Extracts text from various LLM response formats.
        
        Handles:
        - Pydantic v2 objects (model_dump)
        - Pydantic v1 objects (dict)
        - Google GenAI responses (text, candidates)
        - Dictionary responses
        - Plain string responses
        
        Args:
            response: Response from LLM provider (various types possible)
            
        Returns:
            Extracted text string
        """
        try:
            # Pydantic v2 format
            if hasattr(response, 'model_dump'):
                return json.dumps(response.model_dump())
            
            # Pydantic v1 format
            if hasattr(response, 'dict'):
                return json.dumps(response.dict())
            
            # Google GenAI format
            if hasattr(response, 'text'):
                return response.text.strip()
            
            # Google GenAI candidates format
            if hasattr(response, 'candidates') and response.candidates:
                return response.candidates[0].content.parts[0].text.strip()
            
            # Dictionary format
            if isinstance(response, dict):
                if 'text' in response:
                    return response['text'].strip()
                if 'content' in response:
                    return response['content'].strip()
                return json.dumps(response)
            
            # Fallback to string conversion
            return str(response).strip()
            
        except Exception as e:
            self.debug_logs.append(f"Extract raw text error: {e}")
            return str(response).strip()

    def _aggressive_json_parse(self, text: str) -> Optional[Dict]:
        """
        Extracts JSON from text containing markdown code blocks or other formatting.
        
        Uses multiple regex patterns to locate JSON objects in various formats:
        - ```json ... ``` wrapped
        - Bare JSON objects
        
        Args:
            text: Text potentially containing JSON
            
        Returns:
            Parsed JSON dictionary or None if no valid JSON found
        """
        # Remove markdown code block markers
        text = re.sub(r'```json|```', '', text)
        
        # Try multiple patterns to find JSON
        patterns = [
            r'(\{[\s\S]*?\})(?=\s*[\}\]]|$)',  # Balanced braces
            r'\{.*\}'  # Any braces
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.DOTALL)
            if match:
                json_str = match.group(1).strip()
                try:
                    return json.loads(json_str)
                except json.JSONDecodeError:
                    continue
        
        return None

    def _repair_analysis(
        self, 
        json_data: dict, 
        required_skills: List[str]
    ) -> Optional[CVSkillLevelAnalysis]:
        """
        Attempts to repair incomplete or malformed JSON analysis data.
        
        Handles:
        - Missing 'skills' field
        - Missing required skills (fills with beginner level)
        - Invalid field types (converts to proper types)
        - Missing overall statistics (uses defaults)
        
        Args:
            json_data: Partially parsed JSON data
            required_skills: Skills that should be present
            
        Returns:
            Repaired CVSkillLevelAnalysis or None if repair fails
        """
        self.debug_logs.append("Attempting to repair incomplete analysis data")
        try:
            # Ensure skills list exists
            if 'skills' not in json_data:
                json_data['skills'] = []
            
            # Build valid skill assessments from JSON
            skills = []
            for item in json_data['skills']:
                if isinstance(item, dict):
                    skill_name = item.get('skill', item.get('name', 'Unknown'))
                    level = item.get('level', 'beginner')
                    confidence = float(item.get('confidence', 0.5))
                    reasoning = item.get('reasoning', 'No reasoning provided')
                    evidence = item.get('evidence')
                    
                    skills.append(SkillLevelAssessment(
                        skill=skill_name,
                        level=level,
                        confidence=confidence,
                        reasoning=reasoning,
                        evidence=evidence
                    ))
            
            # Add skills not mentioned in analysis (with beginner level)
            existing = {s.skill.lower() for s in skills}
            for skill in required_skills:
                if skill.lower() not in existing:
                    skills.append(SkillLevelAssessment(
                        skill=skill,
                        level='beginner',
                        confidence=0.3,
                        reasoning='Skill not mentioned in CV - defaulting to beginner',
                        evidence=None
                    ))
            
            # Extract or use defaults for overall statistics
            overall_level = json_data.get('overall_level', 'intermediate')
            overall_confidence = float(json_data.get('overall_confidence', 0.6))
            summary = json_data.get('summary', 'Analysis completed with repairs')
            
            return CVSkillLevelAnalysis(
                skills=skills,
                overall_level=overall_level,
                overall_confidence=overall_confidence,
                summary=summary
            )
            
        except Exception as e:
            logger.error(f"Repair failed: {e}")
            self.debug_logs.append(f"Repair error: {e}")
            return None

    def _format_response(
        self, 
        analysis: CVSkillLevelAnalysis, 
        required_skills: List[str]
    ) -> Dict[str, Any]:
        """
        Formats the analysis result into API response format.
        
        Adds:
        - Confidence badges (High/Good/Medium/Low with colors)
        - User override capabilities
        - Suggested alternative levels
        - Skill metadata
        
        Args:
            analysis: Validated CVSkillLevelAnalysis from LLM
            required_skills: Original required skills list
            
        Returns:
            Formatted response dictionary ready for API
        """
        # Index skills by lowercase name for lookup
        analyzed = {s.skill.lower(): s for s in analysis.skills}
        skill_levels = []
        
        # Format each skill with additional metadata
        for skill in required_skills:
            s = analyzed.get(skill.lower())
            if s:
                badge = self._get_confidence_badge(s.confidence)
                skill_levels.append({
                    'skill': s.skill,
                    'detected_level': s.level,
                    'confidence': s.confidence,
                    'confidence_badge': badge['label'],
                    'confidence_color': badge['color'],
                    'reasoning': s.reasoning,
                    'evidence': s.evidence,
                    'user_can_override': True,
                    'suggested_levels': ['none', 'beginner', 'intermediate', 'advanced']
                })
            else:
                # Skill not in analysis - add with defaults
                skill_levels.append({
                    'skill': skill,
                    'detected_level': 'beginner',
                    'confidence': 0.3,
                    'confidence_badge': 'Low',
                    'confidence_color': 'red',
                    'reasoning': 'Skill not mentioned in CV - defaulting to beginner',
                    'evidence': None,
                    'user_can_override': True,
                    'suggested_levels': ['none', 'beginner', 'intermediate', 'advanced']
                })
        
        # Add overall statistics with badge
        badge_overall = self._get_confidence_badge(analysis.overall_confidence)
        return {
            'skill_levels': skill_levels,
            'overall_level': analysis.overall_level,
            'overall_confidence_badge': badge_overall['label'],
            'overall_confidence_color': badge_overall['color'],
            'summary': analysis.summary,
            'user_review_recommended': True,
            'analysis_method': 'llm'
        }

    def _fallback_detection(self, required_skills: List[str]) -> Dict[str, Any]:
        """
        Returns basic skill level detection when LLM analysis fails.
        
        Used when:
        - All LLM attempts fail
        - Network errors occur
        - LLM quota exceeded
        - LLM provider not initialized
        
        Args:
            required_skills: List of skills to assess
            
        Returns:
            Fallback response with all skills marked as 'beginner' with low confidence
        """
        logger.warning(f"Using fallback detection for {len(required_skills)} skills - LLM analysis was unsuccessful")
        self.debug_logs.append(f"Fallback: All LLM attempts exhausted, using conservative defaults")
        self.debug_logs.append(f"Fallback: Marking {len(required_skills)} skills as 'beginner' with low confidence")
        
        skill_levels = []
        for skill in required_skills:
            skill_levels.append({
                'skill': skill,
                'detected_level': 'beginner',
                'confidence': 0.3,  # Very low confidence
                'confidence_badge': 'Low',
                'confidence_color': 'red',
                'reasoning': 'LLM analysis unavailable - skill level estimated based on availability in CV',
                'evidence': None,
                'user_can_override': True,
                'suggested_levels': ['none', 'beginner', 'intermediate', 'advanced']
            })
        
        return {
            'skill_levels': skill_levels,
            'overall_level': 'beginner',
            'overall_confidence': 0.25,
            'overall_confidence_badge': 'Very Low',
            'overall_confidence_color': 'red',
            'summary': 'FALLBACK MODE: LLM analysis failed. All skills estimated as beginner level. Please review and adjust manually.',
            'analysis_method': 'fallback',
            'is_fallback': True,
            'warning': 'This is a fallback response. LLM analysis was not available.'
        }

    @staticmethod
    def _get_confidence_badge(confidence: float) -> Dict[str, str]:
        """
        Maps confidence score to visual badge representation.
        
        Confidence ranges:
        - >= 0.85: High (green)
        - >= 0.70: Good (blue)
        - < 0.70: Medium (orange)
        
        Args:
            confidence: Confidence score (0.0 to 1.0)
            
        Returns:
            Dictionary with 'label' and 'color' keys
        """
        if confidence >= 0.85:
            return {'label': 'High', 'color': 'green'}
        if confidence >= 0.70:
            return {'label': 'Good', 'color': 'blue'}
        return {'label': 'Medium', 'color': 'orange'}

    def _extract_experience_years(self, data: Dict) -> Optional[int]:
        """
        Extracts total years of experience from parsed CV data.
        
        Tries:
        1. Direct 'years_of_experience' field
        2. Number of experience entries (multiply by 2 as estimate)
        
        Args:
            data: Parsed CV data dictionary
            
        Returns:
            Years of experience or None if not found
        """
        if not data:
            return None
        
        if 'years_of_experience' in data:
            return data['years_of_experience']
        
        if 'experience' in data and isinstance(data['experience'], list):
            return len(data['experience']) * 2
        
        return None

    def _extract_job_titles(self, data: Dict) -> List[str]:
        """
        Extracts all job titles from parsed CV experience section.
        
        Args:
            data: Parsed CV data dictionary
            
        Returns:
            List of job title strings (empty list if none found)
        """
        if not data:
            return []
        
        titles = []
        if 'experience' in data and isinstance(data['experience'], list):
            for exp in data['experience']:
                if isinstance(exp, dict) and 'title' in exp:
                    titles.append(exp['title'])
        
        return titles

    async def diagnose_llm_issue(self) -> Dict[str, Any]:
        """
        Diagnostic method to identify why LLM analysis is failing.
        
        Tests:
        1. Is LLM provider initialized?
        2. Can the LLM provider respond to a minimal prompt?
        3. What is the response type?
        
        Returns:
            Dictionary with diagnostic information
        """
        logger.info("Running LLM diagnostic...")
        diagnostics = {
            'llm_provider_type': type(self.llm).__name__ if self.llm else 'None',
            'llm_provider_initialized': self.llm is not None,
            'tests': {}
        }
        
        # Test 1: Provider exists
        if not self.llm:
            diagnostics['tests']['provider_check'] = 'FAILED - LLM provider is None'
            return diagnostics
        
        diagnostics['tests']['provider_check'] = 'PASSED'
        
        # Test 2: Try minimal prompt
        try:
            logger.info("Attempting minimal diagnostic prompt...")
            test_response = await self.llm.get_response(
                prompt="Say 'OK'",
                need_json_output=False,
                temperature=0.1
            )
            
            if inspect.iscoroutine(test_response):
                test_response = await test_response
            
            diagnostics['tests']['minimal_prompt'] = {
                'status': 'SUCCESS' if test_response else 'FAILED - Returned None',
                'response_type': str(type(test_response)),
                'response_preview': str(test_response)[:100] if test_response else 'None'
            }
            
        except Exception as e:
            diagnostics['tests']['minimal_prompt'] = {
                'status': 'FAILED - Exception',
                'error_type': type(e).__name__,
                'error': str(e)
            }
        
        # Test 3: Try JSON prompt
        try:
            logger.info("Attempting JSON diagnostic prompt...")
            test_json_response = await self.llm.get_response(
                prompt='Return {"status": "ok"}',
                need_json_output=True,
                temperature=0.1
            )
            
            if inspect.iscoroutine(test_json_response):
                test_json_response = await test_json_response
            
            diagnostics['tests']['json_prompt'] = {
                'status': 'SUCCESS' if test_json_response else 'FAILED - Returned None',
                'response_type': str(type(test_json_response)),
                'response_preview': str(test_json_response)[:100] if test_json_response else 'None'
            }
            
        except Exception as e:
            diagnostics['tests']['json_prompt'] = {
                'status': 'FAILED - Exception',
                'error_type': type(e).__name__,
                'error': str(e)
            }
        
        # Overall assessment
        if diagnostics['tests'].get('minimal_prompt', {}).get('status') == 'SUCCESS':
            diagnostics['assessment'] = 'LLM provider appears to be working'
        elif diagnostics['tests'].get('provider_check') == 'FAILED':
            diagnostics['assessment'] = 'LLM provider is not initialized. Check environment variables and create_llm_provider() function.'
        else:
            diagnostics['assessment'] = 'LLM provider exists but is not responding. Check API keys, network, and provider configuration.'
        
        return diagnostics