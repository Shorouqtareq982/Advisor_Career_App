"""
Skill Extractor - LLM-Powered
Uses DocumentParser for CV parsing, then extracts skills intelligently
"""
from typing import List, Dict, Any, Set, Optional
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
from pydantic import BaseModel, Field
import re
import logging

logger = logging.getLogger(__name__)


# =====================================================
# PYDANTIC SCHEMAS FOR LLM OUTPUT
# =====================================================

class ExtractedSkills(BaseModel):
    """Schema for LLM skill extraction output"""
    technical_skills: List[str] = Field(
        description="List of technical skills (programming languages, frameworks, tools)"
    )
    soft_skills: List[str] = Field(
        default=[],
        description="Soft skills (optional)"
    )
    certifications: List[str] = Field(
        default=[],
        description="Certifications mentioned"
    )


# =====================================================
# SKILL EXTRACTION PROMPTS
# =====================================================

SKILL_EXTRACTION_PROMPT = """
You are an expert CV analyzer. Extract ALL technical skills from this CV text.

**Instructions:**
1. Extract programming languages, frameworks, libraries, tools, databases, cloud platforms
2. Include both explicit mentions (e.g., "Python, JavaScript") and implicit ones from project descriptions
3. Normalize skill names (e.g., "JS" → "JavaScript", "PostgreSQL" → "PostgreSQL")
4. Remove duplicates
5. Only include technical/professional skills, NOT soft skills like "communication"

**CV Text:**
{cv_text}

**Output Format:**
Return ONLY a JSON object with this structure:
{{
  "technical_skills": ["Python", "JavaScript", "Docker", ...],
  "soft_skills": [],
  "certifications": ["AWS Certified", ...]
}}

Do not include any explanation, just the JSON.
"""


LEVEL_DETECTION_PROMPT = """
You are an expert career advisor. Analyze this CV and determine the candidate's level.

**CV Information:**
- Years of Experience: {experience_years}
- Job Titles: {job_titles}
- Skills Mentioned: {skills}
- Projects: {projects}
- Education: {education}

**Instructions:**
Determine the level as one of: beginner, intermediate, advanced

**Criteria:**
- **Beginner:** 0-2 years experience, 0-3 relevant skills, junior titles, few projects
- **Intermediate:** 2-5 years experience, 3-6 relevant skills, mid-level titles, some projects
- **Advanced:** 5+ years experience, 6+ relevant skills, senior titles, multiple projects

**Output Format:**
Return ONLY a JSON object:
{{
  "detected_level": "intermediate",
  "confidence": 0.85,
  "reasoning": "5 years experience, senior developer title, 8 relevant skills"
}}
"""


# =====================================================
# SKILL EXTRACTOR CLASS
# =====================================================

class SkillExtractor:
    """
    LLM-powered skill extraction from CV
    Integrates with existing DocumentParser
    """
    
    # Skill normalization map
    SKILL_NORMALIZATIONS = {
        # Programming Languages
        'js': 'javascript',
        'ts': 'typescript',
        'py': 'python',
        'cpp': 'c++',
        'csharp': 'c#',
        
        # Frameworks
        'reactjs': 'react',
        'react.js': 'react',
        'vuejs': 'vue',
        'vue.js': 'vue',
        'angularjs': 'angular',
        'nodejs': 'node.js',
        'node': 'node.js',
        'expressjs': 'express',
        
        # Databases
        'postgres': 'postgresql',
        'psql': 'postgresql',
        'mongo': 'mongodb',
        'mssql': 'sql server',
        
        # DevOps
        'k8s': 'kubernetes',
        'kube': 'kubernetes',
        
        # Cloud
        'aws': 'amazon web services',
        'gcp': 'google cloud platform',
    }
    
    # Common tech skill keywords (for validation)
    KNOWN_TECH_KEYWORDS = {
        'python', 'javascript', 'java', 'c++', 'c#', 'ruby', 'go', 'rust',
        'react', 'vue', 'angular', 'django', 'flask', 'spring', 'express',
        'sql', 'mysql', 'postgresql', 'mongodb', 'redis', 'elasticsearch',
        'docker', 'kubernetes', 'jenkins', 'gitlab', 'github',
        'aws', 'azure', 'gcp', 'terraform', 'ansible',
        'git', 'linux', 'bash', 'api', 'rest', 'graphql'
    }
    
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
    
    def extract_skills_from_cv(
        self, 
        cv_text: str,
        parsed_cv_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Extract skills using LLM + validation
        
        Args:
            cv_text: Raw CV text
            parsed_cv_data: Structured CV data from DocumentParser
            
        Returns:
            {
                'extracted_skills': [...],
                'normalized_skills': [...],
                'certifications': [...],
                'extraction_confidence': 0.9
            }
        """
        logger.info("Starting skill extraction...")
        
        # Method 1: Extract from parsed_cv_data if available
        explicit_skills = self._extract_from_parsed_data(parsed_cv_data)
        
        # Method 2: Use LLM for comprehensive extraction
        llm_skills = self._extract_with_llm(cv_text)
        
        # Combine and deduplicate
        all_skills = self._merge_skills(explicit_skills, llm_skills)
        
        # Normalize
        normalized_skills = self._normalize_skills(all_skills)
        
        # Validate (remove non-tech skills)
        validated_skills = self._validate_technical_skills(normalized_skills)
        
        # Calculate confidence
        confidence = self._calculate_extraction_confidence(
            len(validated_skills),
            len(all_skills)
        )
        
        logger.info(f"Extracted {len(validated_skills)} validated skills")
        
        return {
            'extracted_skills': list(all_skills),
            'normalized_skills': list(validated_skills),
            'certifications': llm_skills.get('certifications', []),
            'extraction_confidence': confidence
        }
    
    def _extract_from_parsed_data(self, parsed_data: Dict) -> Set[str]:
        """Extract skills from DocumentParser output"""
        skills = set()
        
        if not parsed_data:
            return skills
        
        # Check 'skills' field
        if 'skills' in parsed_data:
            skill_data = parsed_data['skills']
            if isinstance(skill_data, list):
                skills.update(skill_data)
            elif isinstance(skill_data, dict):
                # Handle nested skills by category
                for category, skill_list in skill_data.items():
                    if isinstance(skill_list, list):
                        skills.update(skill_list)
        
        # Extract from experience descriptions
        if 'experience' in parsed_data and isinstance(parsed_data['experience'], list):
            for job in parsed_data['experience']:
                if isinstance(job, dict):
                    desc = job.get('description', '')
                    if desc:
                        # Extract tech keywords from description
                        desc_skills = self._extract_tech_keywords(desc)
                        skills.update(desc_skills)
        
        return skills
    
    def _extract_with_llm(self, cv_text: str) -> Dict[str, List[str]]:
        """Use LLM to extract skills"""
        try:
            logger.info("Calling LLM for skill extraction...")
            
            response = self.llm.get_response(
                prompt=SKILL_EXTRACTION_PROMPT.format(cv_text=cv_text[:4000]),  # Limit text
                need_json_output=True,
                schema=ExtractedSkills
            )
            
            if response:
                if isinstance(response, ExtractedSkills):
                    return response.dict()
                return response
            
            logger.warning("LLM returned empty response")
            return {'technical_skills': [], 'certifications': []}
            
        except Exception as e:
            logger.error(f"LLM extraction failed: {e}")
            # Fallback to keyword extraction
            return {
                'technical_skills': list(self._extract_tech_keywords(cv_text)),
                'certifications': []
            }
    
    def _extract_tech_keywords(self, text: str) -> Set[str]:
        """Extract known tech keywords from text"""
        found = set()
        text_lower = text.lower()
        
        for keyword in self.KNOWN_TECH_KEYWORDS:
            pattern = r'\b' + re.escape(keyword) + r'\b'
            if re.search(pattern, text_lower):
                found.add(keyword)
        
        return found
    
    def _merge_skills(
        self, 
        explicit_skills: Set[str], 
        llm_result: Dict
    ) -> Set[str]:
        """Merge skills from different sources"""
        merged = set(explicit_skills)
        merged.update(llm_result.get('technical_skills', []))
        return merged
    
    def _normalize_skills(self, skills: Set[str]) -> Set[str]:
        """Normalize skill names"""
        normalized = set()
        
        for skill in skills:
            # Lowercase and trim
            skill_clean = skill.lower().strip()
            
            # Apply normalization map
            skill_normalized = self.SKILL_NORMALIZATIONS.get(
                skill_clean, 
                skill_clean
            )
            
            normalized.add(skill_normalized)
        
        return normalized
    
    def _validate_technical_skills(self, skills: Set[str]) -> Set[str]:
        """
        Remove non-technical skills
        Keep only skills that match known tech or patterns
        """
        validated = set()
        
        for skill in skills:
            skill_lower = skill.lower()
            
            # Check if in known list
            if skill_lower in self.KNOWN_TECH_KEYWORDS:
                validated.add(skill)
                continue
            
            # Check if looks like a tech skill (contains version, framework pattern, etc)
            if self._looks_like_tech_skill(skill_lower):
                validated.add(skill)
        
        return validated
    
    def _looks_like_tech_skill(self, skill: str) -> bool:
        """Heuristic to detect if a skill is technical"""
        # Contains version numbers
        if re.search(r'\d+\.\d+', skill):
            return True
        
        # Contains tech suffixes
        tech_suffixes = ['js', 'py', 'sql', 'db', 'api', 'css', 'html', 'framework']
        if any(suffix in skill for suffix in tech_suffixes):
            return True
        
        # Multi-word technical terms (e.g., "machine learning", "api gateway")
        tech_patterns = [
            'machine learning', 'deep learning', 'data science',
            'web development', 'mobile development',
            'cloud computing', 'api', 'database'
        ]
        if any(pattern in skill for pattern in tech_patterns):
            return True
        
        # Default: if in doubt, exclude (conservative approach)
        return False
    
    def _calculate_extraction_confidence(
        self,
        validated_count: int,
        total_count: int
    ) -> float:
        """Calculate confidence in extraction quality"""
        if total_count == 0:
            return 0.0
        
        # High validation rate = high confidence
        validation_rate = validated_count / total_count
        
        # More skills = higher confidence (up to a point)
        quantity_factor = min(validated_count / 10, 1.0)
        
        confidence = (validation_rate * 0.7 + quantity_factor * 0.3)
        
        return min(confidence, 0.95)

