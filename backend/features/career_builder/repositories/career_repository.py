"""
Career Planning Repository
Database operations layer using Supabase DatabaseProvider
✅ FIXED: All table names corrected
"""
from typing import List, Optional, Dict, Any
from uuid import UUID
import logging
from shared.providers.supabase.database import db

logger = logging.getLogger(__name__)


class CareerRepository:
    """Repository for career planning database operations using Supabase"""

    # =====================================================
    # TRACKS
    # =====================================================
    
    async def get_all_tracks(self) -> List[Dict[str, Any]]:
        """Get all career tracks"""
        try:
            return db.read("career_tracks", limit=100)
        except Exception as e:
            logger.error(f"Error getting tracks: {e}")
            return []

    async def get_track_by_id(self, track_id: int) -> Optional[Dict[str, Any]]:
        """Get track details by ID"""
        try:
            tracks = db.read("career_tracks", {"track_id": track_id}, limit=1)
            return tracks[0] if tracks else None
        except Exception as e:
            logger.error(f"Error getting track {track_id}: {e}")
            return None

    # =====================================================
    # SKILLS
    # =====================================================
    
    async def get_skills_by_track(
        self, 
        track_id: int, 
        level: str = 'beginner'
    ) -> List[Dict[str, Any]]:
        """Get all skills for a track"""
        try:
            # Get track_skills (junction table)
            track_skills = db.read("track_skills", {"track_id": track_id})
            
            if not track_skills:
                return []
            
            # Get full skill details
            skill_ids = [ts['skill_id'] for ts in track_skills]
            all_skills = []
            
            for skill_id in skill_ids:
                skill = await self.get_skill_by_id(skill_id)
                if skill:
                    # Add track-specific metadata
                    track_skill_meta = next(
                        (ts for ts in track_skills if ts['skill_id'] == skill_id),
                        {}
                    )
                    skill.update({
                        'importance': track_skill_meta.get('importance', 3),
                        'duration_weeks': track_skill_meta.get('duration_weeks', 4)
                    })
                    all_skills.append(skill)
            
            return all_skills
            
        except Exception as e:
            logger.error(f"Error getting skills for track {track_id}: {e}")
            return []

    async def get_skill_by_id(self, skill_id: int) -> Optional[Dict[str, Any]]:
        """Get skill details by ID"""
        try:
            skills = db.read("career_skills", {"skill_id": skill_id}, limit=1)
            return skills[0] if skills else None
        except Exception as e:
            logger.error(f"Error getting skill {skill_id}: {e}")
            return None

    async def search_skills_by_name(self, search_term: str = '') -> List[Dict[str, Any]]:
        """Search skills by name"""
        try:
            all_skills = db.read("career_skills", limit=1000)
            
            if not search_term:
                return all_skills
            
            return [
                s for s in all_skills
                if search_term.lower() in s.get('skill_name', '').lower()
            ]
        except Exception as e:
            logger.error(f"Error searching skills: {e}")
            return []

    async def get_popular_skills(self) -> List[Dict[str, Any]]:
        """Get skills that appear in multiple tracks"""
        # TODO: Implement with proper aggregation
        return []

    # =====================================================
    # CV & USER DATA
    # =====================================================
    
    async def get_cv_by_id(self, cv_id: UUID) -> Optional[Dict[str, Any]]:
        """Get CV details"""
        try:
            cvs = db.read("cv", {"cv_id": str(cv_id)}, limit=1)
            return cvs[0] if cvs else None
        except Exception as e:
            logger.error(f"Error getting CV {cv_id}: {e}")
            return None

    # =====================================================
    # CAREER PLANS
    # =====================================================
    
    async def create_career_plan(
        self,
        user_id: UUID,
        cv_id: UUID,
        track_id: int,
        detected_level: str,
        confirmed_level: str,
        duration_weeks: int,
        suggested_min_weeks: int,
        realism_flag: bool
    ) -> Optional[int]:
        """Create a new career plan and return plan_id"""
        try:
            plan_data = {
                "user_id": str(user_id),
                "cv_id": str(cv_id),
                "track_id": track_id,
                "detected_level": detected_level,
                "confirmed_level": confirmed_level,
                "duration_weeks": duration_weeks,
                "suggested_min_weeks": suggested_min_weeks,
                "realism_flag": realism_flag
            }
            result = db.create("career_plan_info", plan_data)
            return result.get("plan_id") if result else None
        except Exception as e:
            logger.error(f"Error creating plan: {e}")
            return None

    async def add_user_skill_gap(
        self,
        plan_id: int,
        skill_id: int,
        status: str,
        current_level: str,
        required_level: str,
        gap_score: float
    ) -> Optional[Dict]:
        """Add skill gap for user"""
        try:
            data = {
                "plan_id": plan_id,
                "skill_id": skill_id,
                "status": status,
                "current_level": current_level,
                "required_level": required_level,
                "gap_score": gap_score
            }
            return db.create("career_user_skills", data)
        except Exception as e:
            logger.error(f"Error adding skill gap: {e}")
            return None

    async def add_weekly_content(
        self,
        plan_id: int,
        week_number: int,
        skill_id: int,
        topic: str,
        description: str,
        resources: List[str]
    ) -> Optional[Dict]:
        """Add weekly content to plan"""
        try:
            data = {
                "plan_id": plan_id,
                "week_number": week_number,
                "skill_id": skill_id,
                "topic": topic,
                "description": description,
                "resources": resources
            }
            return db.create("career_plan_content", data)
        except Exception as e:
            logger.error(f"Error adding weekly content: {e}")
            return None

    async def get_user_plans(self, user_id: UUID) -> List[Dict[str, Any]]:
        """Get all plans for a user"""
        try:
            return db.read(
                "career_plan_info",
                {"user_id": str(user_id)},
                order_by="created_at",
                desc=True
            )
        except Exception as e:
            logger.error(f"Error getting user plans: {e}")
            return []

    async def get_plan_details(self, plan_id: int) -> Optional[Dict[str, Any]]:
        """Get complete plan details"""
        try:
            plans = db.read("career_plan_info", {"plan_id": plan_id}, limit=1)
            plan = plans[0] if plans else None
            
            if plan:
                # Add track info
                track = await self.get_track_by_id(plan["track_id"])
                if track:
                    plan["track_name"] = track.get("track_name")
            
            return plan
        except Exception as e:
            logger.error(f"Error getting plan details: {e}")
            return None

    async def get_plan_skill_gaps(self, plan_id: int) -> List[Dict[str, Any]]:
        """Get skill gaps for a plan"""
        try:
            return db.read("career_user_skills", {"plan_id": plan_id})
        except Exception as e:
            logger.error(f"Error getting skill gaps: {e}")
            return []

    async def get_plan_weekly_content(self, plan_id: int) -> List[Dict[str, Any]]:
        """Get weekly content for a plan"""
        try:
            return db.read(
                "career_plan_content",
                {"plan_id": plan_id},
                order_by="week_number"
            )
        except Exception as e:
            logger.error(f"Error getting weekly content: {e}")
            return []

    # =====================================================
    # HELPER: Calculate min weeks
    # =====================================================
    
    async def calculate_min_weeks(self, track_id: int, level: str) -> int:
        """Calculate minimum weeks for track/level"""
        try:
            skills = await self.get_skills_by_track(track_id, level)
            total_weeks = sum(s.get('duration_weeks', 4) for s in skills)
            return max(total_weeks, 12)  # Minimum 12 weeks
        except Exception as e:
            logger.error(f"Error calculating min weeks: {e}")
            return 12

    # =====================================================
    # ANALYTICS & STATS
    # =====================================================
    
    async def get_track_stats(self, track_id: int) -> Dict[str, Any]:
        """Get statistics for a track"""
        try:
            skills = await self.get_skills_by_track(track_id)
            return {
                'total_skills': len(skills),
                'avg_weeks': sum(s.get('duration_weeks', 4) for s in skills) / len(skills) if skills else 0
            }
        except Exception as e:
            logger.error(f"Error getting track stats: {e}")
            return {}

    async def get_most_missing_skills(self, track_id: int) -> List[Dict[str, Any]]:
        """Get most commonly missing skills for a track"""
        # TODO: Implement with proper aggregation
        return []