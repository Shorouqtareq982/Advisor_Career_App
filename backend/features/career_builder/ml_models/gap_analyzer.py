"""
Skill Gap Analyzer
Calculates skill gaps between current and required levels
"""


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
