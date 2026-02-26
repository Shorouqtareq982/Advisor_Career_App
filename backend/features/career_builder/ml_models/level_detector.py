"""
Advanced Level Detector - LLM-Powered
Analyzes CV to detect skill levels with context awareness
"""
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
import logging

logger = logging.getLogger(__name__)


# =====================================================
# PYDANTIC SCHEMAS
# =====================================================

class SkillLevelAssessment(BaseModel):
    """Individual skill level assessment"""
    skill: str = Field(description="Skill name")
    level: str = Field(
        description="Detected level: none, beginner, intermediate, or advanced"
    )
    confidence: float = Field(
        ge=0.0, 
        le=1.0,
        description="Confidence in this assessment (0-1)"
    )
    reasoning: str = Field(
        description="Brief explanation of why this level was assigned"
    )
    evidence: Optional[str] = Field(
        default=None,
        description="Quote or evidence from CV supporting this level"
    )


class CVSkillLevelAnalysis(BaseModel):
    """Complete CV skill level analysis"""
    skills: List[SkillLevelAssessment] = Field(
        description="List of skill assessments"
    )
    overall_level: str = Field(
        description="Overall level: beginner, intermediate, or advanced"
    )
    overall_confidence: float = Field(
        ge=0.0,
        le=1.0,
        description="Overall confidence in assessment"
    )
    summary: str = Field(
        description="Brief summary of candidate's experience"
    )


# =====================================================
# LLM PROMPTS
# =====================================================

SKILL_LEVEL_ANALYSIS_PROMPT = """
You are an expert technical recruiter analyzing a CV to assess skill levels.

**CV Content:**
{cv_text}

**Skills to Assess:**
{skills_list}

**Years of Experience:** {experience_years}
**Job Titles:** {job_titles}

---

**Your Task:**
Analyze the CV and determine the skill level for EACH skill in the list.

**Level Definitions:**

1. **None** - Skill not mentioned or no evidence of usage
   
2. **Beginner** - Basic knowledge or limited usage
   - Mentioned in coursework or tutorials
   - "Familiar with", "Basic knowledge of"
   - Used in small personal projects
   - No production experience
   
3. **Intermediate** - Practical working knowledge
   - Used in professional projects
   - 1-3 years of hands-on experience
   - "Developed", "Implemented", "Built"
   - Can work independently with guidance
   
4. **Advanced** - Expert-level proficiency
   - 3+ years of extensive experience
   - "Led", "Designed", "Architected", "Optimized"
   - Production systems at scale
   - Mentored others or taught the skill

---

**Context Indicators:**

**Strong Indicators of Advanced:**
- "Led team using X"
- "Architected system with X"
- "Optimized X for production"
- "Scaled X to handle Y users/requests"
- "Mentored developers in X"

**Indicators of Intermediate:**
- "Developed features using X"
- "Implemented X in production"
- "Worked with X for 2 years"
- "Contributed to X codebase"

**Indicators of Beginner:**
- "Academic project using X"
- "Online course in X"
- "Basic knowledge of X"
- "Explored X in personal project"

---

**Output Format:**
Return ONLY a JSON object (no markdown, no explanation):

{{
  "skills": [
    {{
      "skill": "Python",
      "level": "intermediate",
      "confidence": 0.85,
      "reasoning": "Used Python for 2 years in production, developed APIs",
      "evidence": "Developed RESTful APIs using Python/Flask for e-commerce platform"
    }},
    {{
      "skill": "Docker",
      "level": "beginner",
      "confidence": 0.7,
      "reasoning": "Mentioned in skills section but no projects showing usage",
      "evidence": "Docker listed in technical skills"
    }}
  ],
  "overall_level": "intermediate",
  "overall_confidence": 0.82,
  "summary": "Mid-level developer with 2-3 years experience, strong in backend development"
}}

**IMPORTANT:**
- Be conservative - when in doubt, assign a lower level
- Only assign "advanced" if there's clear evidence of expertise
- Consider the CONTEXT of usage, not just mentions
- Confidence should be lower if evidence is weak
"""


# =====================================================
# LEVEL DETECTOR CLASS
# =====================================================

class LevelDetector:
    """
    Advanced LLM-powered level detection
    Analyzes CV to determine skill levels with context awareness
    """
    
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
    
    async def detect_skill_levels(
        self,
        cv_text: str,
        parsed_cv_data: Dict[str, Any],
        required_skills: List[str]
    ) -> Dict[str, Any]:
        """
        Detect skill levels using LLM analysis
        
        Args:
            cv_text: Full CV text
            parsed_cv_data: Structured CV data
            required_skills: List of skills to assess
        
        Returns:
            {
                'skill_levels': [
                    {
                        'skill': 'Python',
                        'detected_level': 'intermediate',
                        'confidence': 0.85,
                        'reasoning': '...',
                        'evidence': '...',
                        'user_can_override': True
                    }
                ],
                'overall_level': 'intermediate',
                'overall_confidence': 0.82,
                'summary': '...'
            }
        """
        logger.info(f"Detecting levels for {len(required_skills)} skills...")
        
        # Extract metadata
        experience_years = self._extract_experience_years(parsed_cv_data)
        job_titles = self._extract_job_titles(parsed_cv_data)
        
        # Call LLM for analysis
        try:
            analysis = await self._analyze_with_llm(
                cv_text=cv_text[:5000],  # Limit text to avoid token limits
                skills_list=required_skills,
                experience_years=experience_years,
                job_titles=job_titles
            )
            
            if not analysis:
                logger.warning("LLM returned empty analysis, using fallback")
                return self._fallback_detection(required_skills)
            
            # Format response with user override capability
            return self._format_response(analysis)
            
        except Exception as e:
            logger.error(f"LLM analysis failed: {e}")
            return self._fallback_detection(required_skills)
    
    async def _analyze_with_llm(
        self,
        cv_text: str,
        skills_list: List[str],
        experience_years: Optional[int],
        job_titles: List[str]
    ) -> Optional[CVSkillLevelAnalysis]:
        """Call LLM for skill level analysis"""
        
        # Format skills list
        skills_formatted = "\n".join([f"- {skill}" for skill in skills_list])
        
        # Format job titles
        titles_formatted = ", ".join(job_titles[:5]) if job_titles else "Not specified"
        
        # Prepare prompt
        prompt = SKILL_LEVEL_ANALYSIS_PROMPT.format(
            cv_text=cv_text,
            skills_list=skills_formatted,
            experience_years=experience_years or "Unknown",
            job_titles=titles_formatted
        )
        
        # Call LLM
        logger.info("Calling LLM for skill level analysis...")
        response = self.llm.get_response(
            prompt=prompt,
            need_json_output=True,
            schema=CVSkillLevelAnalysis
        )
        
        if isinstance(response, CVSkillLevelAnalysis):
            return response
        elif isinstance(response, dict):
            return CVSkillLevelAnalysis(**response)
        
        return None
    
    def _format_response(self, analysis: CVSkillLevelAnalysis) -> Dict[str, Any]:
        """Format LLM analysis into structured response"""
        
        skill_levels = []
        
        for skill_assessment in analysis.skills:
            confidence_value = skill_assessment.confidence
            
            # Convert confidence to user-friendly badge
            confidence_badge = self._get_confidence_badge(confidence_value)
            
            # Determine if override is required (low confidence)
            override_required = confidence_value < 0.6
            
            # For low confidence: don't show LLM's suggestion to avoid bias
            if override_required:
                skill_levels.append({
                    'skill': skill_assessment.skill,
                    'detected_level': None,  # Hide LLM suggestion
                    'show_detection': False,  # Don't show "AI Detected" section
                    'confidence_score': round(confidence_value, 3),  # Keep for backend
                    'confidence_badge': confidence_badge['label'],
                    'confidence_color': confidence_badge['color'],
                    'confidence_description': None,  # Hide technical details
                    'reasoning': None,  # Hide reasoning to avoid bias
                    'evidence': None,  # Hide evidence
                    'user_must_select': True,  # Force user selection
                    'override_required': True,
                    'suggested_levels': ['none', 'beginner', 'intermediate', 'advanced'],
                    'ui_message': '⚠️ Please select your actual level for this skill'
                })
            else:
                # Normal confidence: show LLM suggestion
                skill_levels.append({
                    'skill': skill_assessment.skill,
                    'detected_level': skill_assessment.level,
                    'show_detection': True,
                    'confidence_score': round(confidence_value, 3),
                    'confidence_badge': confidence_badge['label'],
                    'confidence_color': confidence_badge['color'],
                    'confidence_description': confidence_badge['description'],
                    'reasoning': skill_assessment.reasoning,
                    'evidence': skill_assessment.evidence,
                    'user_can_override': True,
                    'override_required': False,
                    'user_must_select': False,
                    'suggested_levels': ['none', 'beginner', 'intermediate', 'advanced']
                })
        
        # Overall confidence badge
        overall_badge = self._get_confidence_badge(analysis.overall_confidence)
        
        return {
            'skill_levels': skill_levels,
            'overall_level': analysis.overall_level,
            'overall_confidence_score': round(analysis.overall_confidence, 3),
            'overall_confidence_badge': overall_badge['label'],
            'overall_confidence_color': overall_badge['color'],
            'summary': analysis.summary,
            'analysis_method': 'llm',
            'user_review_recommended': True,
            'requires_mandatory_review': any(s.get('user_must_select', False) for s in skill_levels),
            'low_confidence_count': sum(1 for s in skill_levels if s.get('user_must_select', False))
        }
    
    @staticmethod
    def _get_confidence_badge(confidence: float) -> Dict[str, str]:
        """
        Convert confidence score to user-friendly badge
        
        Args:
            confidence: Confidence score (0.0-1.0)
        
        Returns:
            {
                'label': 'High Confidence',
                'color': 'green',
                'description': 'Our assessment is highly reliable',
                'action': None
            }
        """
        if confidence >= 0.85:
            return {
                'label': 'High Confidence',
                'color': 'green',
                'icon': '✓',
                'description': 'Strong evidence supports this assessment',
                'action': None
            }
        elif confidence >= 0.70:
            return {
                'label': 'Good Confidence',
                'color': 'blue',
                'icon': '✓',
                'description': 'Reliable assessment with supporting evidence',
                'action': 'Review recommended'
            }
        elif confidence >= 0.60:
            return {
                'label': 'Medium Confidence',
                'color': 'orange',
                'icon': '⚠',
                'description': 'Assessment based on limited evidence',
                'action': 'Please review and verify'
            }
        else:
            return {
                'label': 'Low Confidence',
                'color': 'red',
                'icon': '!',
                'description': 'Insufficient evidence - manual review required',
                'action': 'You must verify this level'
            }
    
    def _fallback_detection(self, required_skills: List[str]) -> Dict[str, Any]:
        """Simple fallback when LLM fails"""
        
        skill_levels = [
            {
                'skill': skill,
                'detected_level': 'beginner',
                'confidence': 0.5,
                'reasoning': 'Unable to analyze CV, defaulting to beginner',
                'evidence': None,
                'user_can_override': True,
                'suggested_levels': ['none', 'beginner', 'intermediate', 'advanced']
            }
            for skill in required_skills
        ]
        
        return {
            'skill_levels': skill_levels,
            'overall_level': 'beginner',
            'overall_confidence': 0.5,
            'summary': 'Analysis fallback - please review and adjust levels',
            'analysis_method': 'fallback',
            'user_review_recommended': True
        }
    
    def apply_user_overrides(
        self,
        detected_levels: List[Dict],
        user_overrides: Dict[str, str]
    ) -> List[Dict]:
        """
        Apply user's manual overrides to detected levels
        
        Args:
            detected_levels: Original LLM detection results
            user_overrides: Dict of {skill_name: new_level}
        
        Returns:
            Updated skill levels with user overrides applied
        """
        updated = []
        
        for skill_level in detected_levels:
            skill_name = skill_level['skill']
            
            if skill_name in user_overrides:
                # User overrode this skill
                new_level = user_overrides[skill_name]
                
                updated.append({
                    **skill_level,
                    'detected_level': skill_level['detected_level'],  # Keep original
                    'final_level': new_level,  # User's choice
                    'user_overridden': True,
                    'confidence': 1.0  # Full confidence in user's choice
                })
            else:
                # No override, use detected level
                updated.append({
                    **skill_level,
                    'final_level': skill_level['detected_level'],
                    'user_overridden': False
                })
        
        return updated
    
    def _extract_experience_years(self, parsed_cv_data: Dict) -> Optional[int]:
        """Extract years of experience from parsed CV"""
        
        if not parsed_cv_data:
            return None
        
        # Try direct field
        if 'years_of_experience' in parsed_cv_data:
            return parsed_cv_data['years_of_experience']
        
        # Estimate from experience list
        experience = parsed_cv_data.get('experience', [])
        if isinstance(experience, list) and experience:
            return min(len(experience) * 2, 15)  # Rough estimate
        
        return None
    
    def _extract_job_titles(self, parsed_cv_data: Dict) -> List[str]:
        """Extract job titles from parsed CV"""
        
        if not parsed_cv_data:
            return []
        
        titles = []
        
        # Try direct field
        if 'job_titles' in parsed_cv_data:
            return parsed_cv_data['job_titles']
        
        # Extract from experience
        experience = parsed_cv_data.get('experience', [])
        if isinstance(experience, list):
            for job in experience:
                if isinstance(job, dict):
                    title = job.get('title') or job.get('position') or job.get('role')
                    if title:
                        titles.append(title)
        
        return titles
    
    def calculate_overall_level_from_skills(
        self,
        skill_levels: List[Dict]
    ) -> Dict[str, Any]:
        """
        Calculate overall user level from individual skill levels
        
        Used after user overrides to recalculate overall level
        """
        if not skill_levels:
            return {
                'overall_level': 'beginner',
                'confidence': 0.5
            }
        
        # Count levels
        level_counts = {
            'none': 0,
            'beginner': 0,
            'intermediate': 0,
            'advanced': 0
        }
        
        for skill in skill_levels:
            level = skill.get('final_level') or skill.get('detected_level')
            level_counts[level] = level_counts.get(level, 0) + 1
        
        total = len(skill_levels)
        
        # Calculate percentages
        advanced_pct = level_counts['advanced'] / total
        intermediate_pct = level_counts['intermediate'] / total
        beginner_pct = level_counts['beginner'] / total
        
        # Determine overall level
        if advanced_pct >= 0.5:
            overall = 'advanced'
            confidence = 0.85
        elif intermediate_pct >= 0.4 or advanced_pct >= 0.3:
            overall = 'intermediate'
            confidence = 0.80
        else:
            overall = 'beginner'
            confidence = 0.75
        
        return {
            'overall_level': overall,
            'confidence': confidence,
            'level_distribution': {
                'advanced': level_counts['advanced'],
                'intermediate': level_counts['intermediate'],
                'beginner': level_counts['beginner'],
                'none': level_counts['none']
            }
        }