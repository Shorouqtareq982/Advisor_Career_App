"""
LLM-Powered Skill Matcher
Uses AI to intelligently match CV skills to database skills
Much more accurate than rule-based matching
"""
from typing import List, Dict, Optional
from dataclasses import dataclass
from pydantic import BaseModel, Field
from shared.providers.llm_models.llm_provider import LLMProvider, create_llm_provider
import logging

logger = logging.getLogger(__name__)


# =====================================================
# DATACLASSES
# =====================================================

@dataclass
class SkillMatch:
    """Represents a matched skill"""
    cv_skill: str
    db_skill_id: int
    db_skill_name: str
    category: str
    confidence: float
    match_type: str
    reasoning: Optional[str] = None


# =====================================================
# PYDANTIC SCHEMAS FOR LLM
# =====================================================

class SkillMatchResult(BaseModel):
    """Single skill match result from LLM"""
    cv_skill: str = Field(description="Original skill from CV")
    matched_db_skill: str = Field(description="Best matching database skill name")
    confidence: float = Field(
        ge=0.0,
        le=1.0,
        description="Match confidence (0-1)"
    )
    reasoning: str = Field(description="Brief explanation of why they match")


class SkillMatchingResponse(BaseModel):
    """Complete skill matching response from LLM"""
    matches: List[SkillMatchResult] = Field(
        description="List of matched skills"
    )


# =====================================================
# LLM PROMPT
# =====================================================

SKILL_MATCHING_PROMPT = """
You are an expert technical skill matcher. Your job is to match skills extracted from a CV to our standardized database of skills.

**CV Skills (extracted from resume):**
{cv_skills}

**Database Skills (our standardized list):**
{db_skills}

---

**Your Task:**
For each CV skill, find the BEST matching database skill. Be smart about:
- Synonyms (e.g., "JS" = "JavaScript", "React.js" = "React")
- Different naming conventions (e.g., "Node" = "Node.js", "Postgres" = "PostgreSQL")
- Related concepts (e.g., "Django" matches "Backend Frameworks")
- Abbreviations (e.g., "K8s" = "Kubernetes")

**Matching Rules:**
1. **Exact or Synonym match** → confidence 0.9-1.0
2. **Related/Similar technologies** → confidence 0.7-0.9
3. **Same category but different tool** → confidence 0.5-0.7
4. **No good match** → don't include it

**IMPORTANT:**
- Only include matches with confidence ≥ 0.65
- If a CV skill doesn't match any database skill well, skip it
- Be conservative - don't force matches

**Output Format:**
Return ONLY a JSON object:

{{
  "matches": [
    {{
      "cv_skill": "React.js",
      "matched_db_skill": "React",
      "confidence": 0.95,
      "reasoning": "React.js is standard name for React framework"
    }},
    {{
      "cv_skill": "Postgres",
      "matched_db_skill": "PostgreSQL",
      "confidence": 0.95,
      "reasoning": "Postgres is common abbreviation for PostgreSQL"
    }}
  ]
}}

**Examples of Good Matching:**
- "JS" → "JavaScript" (0.95, synonym)
- "Node" → "Node.js" (0.95, standard naming)
- "AWS Lambda" → "AWS" (0.85, specific service under AWS umbrella)
- "FastAPI" → "Backend Frameworks" (0.75, related category)

**Examples of What NOT to Match:**
- "Excel" → "Python" (completely different)
- "Leadership" → "Docker" (not technical match)
"""


# =====================================================
# LLM-POWERED SKILL MATCHER
# =====================================================

class SkillMatcher:
    """
    LLM-powered skill matcher
    Replaces rule-based matching with intelligent AI matching
    """
    
    def __init__(self, llm: LLMProvider = None):
        self.llm = llm or create_llm_provider()
        self.cache = {}  # Cache results to avoid redundant LLM calls
    
    async def match_skills(
        self,
        cv_skills: List[str],
        db_skills: List[Dict],
        threshold: float = 0.65
    ) -> List[SkillMatch]:
        """
        Match CV skills to database skills using LLM
        
        Args:
            cv_skills: Skills extracted from CV
            db_skills: Available skills in database
            threshold: Minimum confidence threshold
        
        Returns:
            List of SkillMatch objects
        """
        if not cv_skills or not db_skills:
            return []
        
        logger.info(f"Matching {len(cv_skills)} CV skills to {len(db_skills)} DB skills...")
        
        # Check cache
        cache_key = self._get_cache_key(cv_skills, db_skills)
        if cache_key in self.cache:
            logger.info("Using cached matching results")
            return self.cache[cache_key]
        
        try:
            # Call LLM for intelligent matching
            llm_matches = await self._match_with_llm(cv_skills, db_skills)
            
            # Convert to SkillMatch objects
            matches = self._convert_to_skill_matches(llm_matches, db_skills, threshold)
            
            # Cache results
            self.cache[cache_key] = matches
            
            logger.info(f"Successfully matched {len(matches)} skills")
            return matches
            
        except Exception as e:
            logger.error(f"LLM matching failed: {e}")
            # Fallback to simple exact matching
            return self._fallback_exact_matching(cv_skills, db_skills, threshold)
    
    async def _match_with_llm(
        self,
        cv_skills: List[str],
        db_skills: List[Dict]
    ) -> List[SkillMatchResult]:
        """Use LLM to match skills"""
        
        # Format skills for prompt
        cv_skills_formatted = "\n".join([f"- {skill}" for skill in cv_skills])
        db_skills_formatted = "\n".join([
            f"- {skill['skill_name']} ({skill.get('category', 'General')})"
            for skill in db_skills[:100]  # Limit to avoid token overflow
        ])
        
        # Prepare prompt
        prompt = SKILL_MATCHING_PROMPT.format(
            cv_skills=cv_skills_formatted,
            db_skills=db_skills_formatted
        )
        
        # Call LLM
        logger.info("Calling LLM for skill matching...")
        response = self.llm.get_response(
            prompt=prompt,
            need_json_output=True,
            schema=SkillMatchingResponse
        )
        
        if isinstance(response, SkillMatchingResponse):
            return response.matches
        elif isinstance(response, dict) and 'matches' in response:
            return [SkillMatchResult(**m) for m in response['matches']]
        
        logger.warning("LLM returned unexpected format")
        return []
    
    def _convert_to_skill_matches(
        self,
        llm_matches: List[SkillMatchResult],
        db_skills: List[Dict],
        threshold: float
    ) -> List[SkillMatch]:
        """Convert LLM results to SkillMatch objects"""
        
        # Create lookup map
        db_skill_map = {
            skill['skill_name'].lower(): skill
            for skill in db_skills
        }
        
        matches = []
        
        for llm_match in llm_matches:
            # Skip low confidence matches
            if llm_match.confidence < threshold:
                continue
            
            # Find matching database skill
            db_skill_name_lower = llm_match.matched_db_skill.lower()
            db_skill = db_skill_map.get(db_skill_name_lower)
            
            if not db_skill:
                # Try fuzzy lookup
                db_skill = self._fuzzy_db_lookup(
                    llm_match.matched_db_skill,
                    db_skills
                )
            
            if db_skill:
                matches.append(SkillMatch(
                    cv_skill=llm_match.cv_skill,
                    db_skill_id=db_skill['skill_id'],
                    db_skill_name=db_skill['skill_name'],
                    category=db_skill.get('category', 'General'),
                    confidence=llm_match.confidence,
                    match_type='llm',
                    reasoning=llm_match.reasoning
                ))
        
        return matches
    
    def _fuzzy_db_lookup(
        self,
        skill_name: str,
        db_skills: List[Dict]
    ) -> Optional[Dict]:
        """Fuzzy lookup in database skills"""
        skill_lower = skill_name.lower()
        
        for db_skill in db_skills:
            db_name_lower = db_skill['skill_name'].lower()
            
            # Check if one contains the other
            if skill_lower in db_name_lower or db_name_lower in skill_lower:
                return db_skill
        
        return None
    
    def _fallback_exact_matching(
        self,
        cv_skills: List[str],
        db_skills: List[Dict],
        threshold: float
    ) -> List[SkillMatch]:
        """Simple exact matching fallback when LLM fails"""
        
        logger.info("Using fallback exact matching")
        
        matches = []
        cv_skills_lower = {s.lower(): s for s in cv_skills}
        
        for db_skill in db_skills:
            db_name = db_skill['skill_name']
            db_name_lower = db_name.lower()
            
            # Check for exact match
            if db_name_lower in cv_skills_lower:
                matches.append(SkillMatch(
                    cv_skill=cv_skills_lower[db_name_lower],
                    db_skill_id=db_skill['skill_id'],
                    db_skill_name=db_name,
                    category=db_skill.get('category', 'General'),
                    confidence=1.0,
                    match_type='exact',
                    reasoning='Exact name match'
                ))
        
        return matches
    
    def _get_cache_key(
        self,
        cv_skills: List[str],
        db_skills: List[Dict]
    ) -> str:
        """Generate cache key for this matching request"""
        cv_key = '|'.join(sorted(cv_skills))
        db_key = '|'.join(sorted([s['skill_name'] for s in db_skills[:20]]))
        return f"{cv_key}::{db_key}"
    
    def get_unmatched_skills(
        self,
        cv_skills: List[str],
        matches: List[SkillMatch]
    ) -> List[str]:
        """Get CV skills that didn't match any database skill"""
        matched_cv = {m.cv_skill.lower() for m in matches}
        return [
            skill for skill in cv_skills
            if skill.lower() not in matched_cv
        ]
    
    def get_match_quality_report(
        self,
        matches: List[SkillMatch]
    ) -> Dict[str, any]:
        """
        Generate quality report for matches
        Useful for debugging and transparency
        """
        if not matches:
            return {
                'total_matches': 0,
                'average_confidence': 0.0,
                'quality': 'no_matches'
            }
        
        total = len(matches)
        avg_confidence = sum(m.confidence for m in matches) / total
        
        high_confidence = sum(1 for m in matches if m.confidence >= 0.9)
        medium_confidence = sum(1 for m in matches if 0.7 <= m.confidence < 0.9)
        low_confidence = sum(1 for m in matches if m.confidence < 0.7)
        
        return {
            'total_matches': total,
            'average_confidence': round(avg_confidence, 3),
            'high_confidence_count': high_confidence,
            'medium_confidence_count': medium_confidence,
            'low_confidence_count': low_confidence,
            'quality': 'excellent' if avg_confidence >= 0.9 else
                      'good' if avg_confidence >= 0.75 else
                      'fair' if avg_confidence >= 0.65 else 'poor'
        }