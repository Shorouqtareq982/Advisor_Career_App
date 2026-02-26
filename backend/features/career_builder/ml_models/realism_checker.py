"""
Time Realism Checker
Validates if requested learning duration is achievable
"""
from typing import Dict, Any


class RealismChecker:
    """Checks if requested learning duration is realistic"""
    
    # Compression limits per level (how much can we compress the timeline?)
    COMPRESSION_LIMITS = {
        'beginner': 0.80,      # Can't go below 80% of minimum (needs more time)
        'intermediate': 0.85,  # Can't go below 85% (some foundation exists)
        'advanced': 0.90       # Can't go below 90% (has strong foundation)
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
        
        Args:
            track_id: Career track ID
            level: User's level (beginner, intermediate, advanced)
            requested_weeks: Weeks user wants to complete in
            min_weeks: Calculated minimum weeks for this track/level
        
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
        
        Examples:
            >>> checker = RealismChecker()
            >>> result = checker.check_realism(1, 'beginner', 12, 24)
            >>> result['is_realistic']
            False
            >>> result['suggested_min_weeks']
            19  # 80% of 24
        """
        # Get compression limit for this level
        compression_limit = self.COMPRESSION_LIMITS.get(level, 0.85)
        
        # Calculate absolute minimum (can't go below this)
        absolute_minimum = int(min_weeks * compression_limit)
        
        # Check if request is realistic
        is_realistic = requested_weeks >= absolute_minimum
        
        # Calculate actual compression ratio
        compression_ratio = requested_weeks / min_weeks if min_weeks > 0 else 1.0
        
        # Generate message
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
            'compression_ratio': round(compression_ratio, 2),
            'compression_limit': compression_limit,
            'message': message
        }
    
    def calculate_smart_duration(
        self,
        min_weeks: int,
        skill_gaps: list,
        level: str
    ) -> int:
        """
        Calculate smart duration based on skill gaps
        
        Args:
            min_weeks: Base minimum weeks
            skill_gaps: List of skill gaps with scores
            level: User level
        
        Returns:
            Estimated realistic duration in weeks
        """
        # Calculate total learning weight from gaps
        total_weight = sum(
            gap.get('importance_weight', 3) * gap.get('gap_score', 1.0)
            for gap in skill_gaps
        )
        
        # Smart formula: base time + gap-based adjustment
        estimated_weeks = int(min_weeks * 0.7 + total_weight * 1.5)
        
        # Ensure it's at least the minimum
        compression_limit = self.COMPRESSION_LIMITS.get(level, 0.85)
        absolute_min = int(min_weeks * compression_limit)
        
        return max(estimated_weeks, absolute_min)