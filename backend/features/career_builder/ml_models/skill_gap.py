"""
Skill Gap Analysis & Realism Checking
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
        
        Returns:
            0.0 = no gap (at or above required level)
            1.0 = maximum gap (completely missing)
        """
        level_values = {
            'none': 0,
            'beginner': 1,
            'intermediate': 2,
            'advanced': 3
        }
        
        current = level_values.get(current_level, 0)
        required = level_values.get(required_level, 1)
        
        if current >= required:
            return 0.0
        
        gap = required - current
        max_gap = required
        
        return gap / max_gap if max_gap > 0 else 1.0


class RealismChecker:
    """Checks if requested learning duration is realistic"""
    
    # Compression limits per level
    COMPRESSION_LIMITS = {
        'beginner': 0.80,      # Can't go below 80% of minimum
        'intermediate': 0.85,  # Can't go below 85%
        'advanced': 0.90       # Can't go below 90%
    }
    
    def check_realism(
        self,
        track_id: int,
        level: str,
        requested_weeks: int,
        min_weeks: int
    ) -> Dict[str, Any]:
        """
        Check if requested duration is realistic
        
        Returns:
            {
                'is_realistic': bool,
                'min_weeks_required': int,
                'suggested_min_weeks': int,
                'requested_weeks': int,
                'compression_ratio': float,
                'compression_limit': float,
                'message': str
            }
        """
        compression_limit = self.COMPRESSION_LIMITS.get(level, 0.85)
        absolute_minimum = int(min_weeks * compression_limit)
        
        is_realistic = requested_weeks >= absolute_minimum
        compression_ratio = requested_weeks / min_weeks if min_weeks > 0 else 1.0
        
        if is_realistic:
            message = f"Duration is realistic ({compression_ratio:.0%} of minimum)"
        else:
            message = (
                f"Duration too short. Minimum {absolute_minimum} weeks required "
                f"({compression_limit:.0%} compression limit)."
            )
        
        return {
            'is_realistic': is_realistic,
            'min_weeks_required': min_weeks,
            'suggested_min_weeks': absolute_minimum,
            'requested_weeks': requested_weeks,
            'compression_ratio': compression_ratio,
            'compression_limit': compression_limit,
            'message': message
        }