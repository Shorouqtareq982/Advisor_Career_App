"""
Simplified Skill Matcher
Smart matching between CV skills and database skills
"""
from typing import List, Dict, Set, Tuple, Optional
from dataclasses import dataclass
import re


@dataclass
class SkillMatch:
    """Represents a matched skill"""
    cv_skill: str
    db_skill_id: int
    db_skill_name: str
    category: str
    confidence: float
    match_type: str


class SkillMatcher:
    """Match CV skills to database skills"""
    
    # Synonym mapping
    SYNONYMS = {
        'js': 'javascript',
        'ts': 'typescript',
        'py': 'python',
        'reactjs': 'react',
        'nodejs': 'node.js',
        'postgres': 'postgresql',
        'mongo': 'mongodb',
        'k8s': 'kubernetes',
    }
    
    def match_skills(
        self,
        cv_skills: List[str],
        db_skills: List[Dict],
        threshold: float = 0.65
    ) -> List[SkillMatch]:
        """Match CV skills to database skills"""
        matches = []
        matched_db_ids = set()
        
        for cv_skill in cv_skills:
            best_match = self._find_best_match(
                cv_skill,
                db_skills,
                matched_db_ids,
                threshold
            )
            
            if best_match:
                matches.append(best_match)
                matched_db_ids.add(best_match.db_skill_id)
        
        return matches
    
    def _find_best_match(
        self,
        cv_skill: str,
        db_skills: List[Dict],
        matched_ids: Set[int],
        threshold: float
    ) -> Optional[SkillMatch]:
        """Find best matching database skill"""
        cv_norm = self._normalize(cv_skill)
        best_score = 0.0
        best_match = None
        
        for db_skill in db_skills:
            if db_skill['skill_id'] in matched_ids:
                continue
            
            db_norm = self._normalize(db_skill['skill_name'])
            score, match_type = self._calculate_score(cv_norm, db_norm)
            
            if score > best_score and score >= threshold:
                best_score = score
                best_match = SkillMatch(
                    cv_skill=cv_skill,
                    db_skill_id=db_skill['skill_id'],
                    db_skill_name=db_skill['skill_name'],
                    category=db_skill.get('category', 'General'),
                    confidence=score,
                    match_type=match_type
                )
        
        return best_match
    
    def _calculate_score(self, cv_skill: str, db_skill: str) -> Tuple[float, str]:
        """Calculate match score"""
        # Exact match
        if cv_skill == db_skill:
            return (1.0, 'exact')
        
        # Synonym match
        cv_canonical = self.SYNONYMS.get(cv_skill, cv_skill)
        db_canonical = self.SYNONYMS.get(db_skill, db_skill)
        if cv_canonical == db_canonical:
            return (0.95, 'synonym')
        
        # Partial match
        if cv_skill in db_skill or db_skill in cv_skill:
            return (0.85, 'partial')
        
        # Word overlap
        cv_words = set(cv_skill.split())
        db_words = set(db_skill.split())
        if cv_words and db_words:
            overlap = len(cv_words & db_words)
            total = len(cv_words | db_words)
            if overlap > 0:
                score = overlap / total
                if score >= 0.5:
                    return (score * 0.9, 'word_overlap')
        
        return (0.0, 'none')
    
    def _normalize(self, skill: str) -> str:
        """Normalize skill name"""
        normalized = skill.lower().strip()
        normalized = re.sub(r'[^\w\s]', ' ', normalized)
        normalized = ' '.join(normalized.split())
        return normalized
    
    def get_unmatched_skills(
        self,
        cv_skills: List[str],
        matches: List[SkillMatch]
    ) -> List[str]:
        """Get unmatched CV skills"""
        matched_cv = {m.cv_skill.lower() for m in matches}
        return [s for s in cv_skills if s.lower() not in matched_cv]