"""
Skill Gap Analyzer
Calculates skill gaps between current and required levels
"""
from typing import Dict, Any


class SkillGapAnalyzer:
    """Analyzes skill gaps between current and required level"""
    
    def calculate_gap_score(
        self,
        current_level: str,
        required_level: str
    ) -> float:
        """
        Calculate gap score between current and required level
        
        Args:
            current_level: User's current level (none, beginner, intermediate, advanced)
            required_level: Required level for the track (beginner, intermediate, advanced)
        
        Returns:
            0.0 = no gap (at or above required level)
            1.0 = maximum gap (completely missing)
        
        Examples:
            >>> analyzer = SkillGapAnalyzer()
            >>> analyzer.calculate_gap_score('none', 'intermediate')
            1.0
            >>> analyzer.calculate_gap_score('beginner', 'intermediate')
            0.5
            >>> analyzer.calculate_gap_score('intermediate', 'intermediate')
            0.0
        """
        level_values = {
            'none': 0,
            'beginner': 1,
            'intermediate': 2,
            'advanced': 3
        }
        
        current = level_values.get(current_level, 0)
        required = level_values.get(required_level, 1)
        
        # No gap if current level >= required level
        if current >= required:
            return 0.0
        
        gap = required - current
        max_gap = required
        
        return gap / max_gap if max_gap > 0 else 1.0
    
    def analyze_gaps(
        self,
        user_skills: list,
        track_skills: list,
        required_level: str
    ) -> list:
        """
        Analyze skill gaps for a complete track
        
        Args:
            user_skills: List of skills user has
            track_skills: List of required skills for track
            required_level: Target level (beginner/intermediate/advanced)
        
        Returns:
            List of gap analysis results with scores
        """
        gaps = []
        
        for track_skill in track_skills:
            # Check if user has this skill
            user_has_skill = any(
                us.get('skill_id') == track_skill.get('skill_id') 
                for us in user_skills
            )
            
            if user_has_skill:
                current_level = 'beginner'  # Assume beginner if they have it
                status = 'has'
            else:
                current_level = 'none'
                status = 'missing'
            
            # Calculate gap score
            gap_score = self.calculate_gap_score(current_level, required_level)
            
            gaps.append({
                'skill_id': track_skill.get('skill_id'),
                'skill_name': track_skill.get('skill_name'),
                'status': status,
                'current_level': current_level,
                'required_level': required_level,
                'gap_score': gap_score,
                'importance_weight': track_skill.get('importance_weight', 3)
            })
        
        # Sort by gap score (highest first)
        gaps.sort(key=lambda x: x['gap_score'], reverse=True)
        
        return gaps