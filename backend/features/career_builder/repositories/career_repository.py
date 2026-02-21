"""
Career Planning Repository
Database operations layer
"""
from typing import List, Optional, Dict, Any, Tuple
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, text
from sqlalchemy.orm import selectinload
import logging

logger = logging.getLogger(__name__)


class CareerRepository:
    """Repository for career planning database operations"""
    
    def __init__(self, session: AsyncSession):
        self.session = session
    
    # =====================================================
    # TRACKS
    # =====================================================
    
    async def get_all_tracks(self) -> List[Dict[str, Any]]:
        """Get all career tracks with summary"""
        query = text("""
            SELECT * FROM v_track_summary ORDER BY track_id
        """)
        result = await self.session.execute(query)
        return [dict(row._mapping) for row in result]
    
    async def get_track_by_id(self, track_id: int) -> Optional[Dict[str, Any]]:
        """Get track details by ID"""
        query = text("""
            SELECT * FROM career_tracks WHERE track_id = :track_id
        """)
        result = await self.session.execute(query, {"track_id": track_id})
        row = result.fetchone()
        return dict(row._mapping) if row else None
    
    # =====================================================
    # SKILLS
    # =====================================================
    
    async def get_skills_by_track(
        self, 
        track_id: int, 
        level: str = 'beginner'
    ) -> List[Dict[str, Any]]:
        """Get all skills for a track with duration for specific level"""
        query = text("""
            SELECT * FROM get_track_skills(:track_id, :level::level_enum)
        """)
        result = await self.session.execute(
            query, 
            {"track_id": track_id, "level": level}
        )
        return [dict(row._mapping) for row in result]
    
    async def get_skill_by_id(self, skill_id: int) -> Optional[Dict[str, Any]]:
        """Get skill details by ID"""
        query = text("""
            SELECT * FROM skills WHERE skill_id = :skill_id
        """)
        result = await self.session.execute(query, {"skill_id": skill_id})
        row = result.fetchone()
        return dict(row._mapping) if row else None
    
    async def search_skills_by_name(self, search_term: str) -> List[Dict[str, Any]]:
        """Search skills by name (fuzzy match)"""
        query = text("""
            SELECT skill_id, skill_name, category
            FROM skills
            WHERE LOWER(skill_name) LIKE LOWER(:search)
            ORDER BY skill_name
            LIMIT 50
        """)
        result = await self.session.execute(
            query, 
            {"search": f"%{search_term}%"}
        )
        return [dict(row._mapping) for row in result]
    
    async def get_popular_skills(self) -> List[Dict[str, Any]]:
        """Get skills that appear in multiple tracks"""
        query = text("""
            SELECT * FROM v_popular_skills
        """)
        result = await self.session.execute(query)
        return [dict(row._mapping) for row in result]
    
    # =====================================================
    # TRACK SKILLS (Junction)
    # =====================================================
    
    async def get_track_skill_details(
        self, 
        track_id: int, 
        skill_id: int
    ) -> Optional[Dict[str, Any]]:
        """Get specific skill details for a track"""
        query = text("""
            SELECT 
                ts.*,
                s.skill_name,
                s.category
            FROM track_skills ts
            JOIN skills s ON ts.skill_id = s.skill_id
            WHERE ts.track_id = :track_id AND ts.skill_id = :skill_id
        """)
        result = await self.session.execute(
            query, 
            {"track_id": track_id, "skill_id": skill_id}
        )
        row = result.fetchone()
        return dict(row._mapping) if row else None
    
    async def calculate_min_weeks(self, track_id: int, level: str) -> int:
        """Calculate minimum weeks for a track at specific level"""
        query = text("""
            SELECT calc_min_weeks(:track_id, :level::level_enum)
        """)
        result = await self.session.execute(
            query, 
            {"track_id": track_id, "level": level}
        )
        return result.scalar()
    
    # =====================================================
    # CV & USER DATA
    # =====================================================
    
    async def get_cv_by_id(self, cv_id: UUID) -> Optional[Dict[str, Any]]:
        """Get CV details"""
        query = text("""
            SELECT * FROM cv WHERE cv_id = :cv_id
        """)
        result = await self.session.execute(query, {"cv_id": str(cv_id)})
        row = result.fetchone()
        return dict(row._mapping) if row else None
    
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
    ) -> int:
        """Create a new career plan and return plan_id"""
        query = text("""
            INSERT INTO career_plan_info (
                user_id, cv_id, track_id, 
                detected_level, confirmed_level, 
                duration_weeks, suggested_min_weeks, realism_flag
            ) VALUES (
                :user_id, :cv_id, :track_id,
                :detected_level::level_enum, :confirmed_level::level_enum,
                :duration_weeks, :suggested_min_weeks, :realism_flag
            )
            RETURNING plan_id
        """)
        result = await self.session.execute(query, {
            "user_id": str(user_id),
            "cv_id": str(cv_id),
            "track_id": track_id,
            "detected_level": detected_level,
            "confirmed_level": confirmed_level,
            "duration_weeks": duration_weeks,
            "suggested_min_weeks": suggested_min_weeks,
            "realism_flag": realism_flag
        })
        await self.session.commit()
        return result.scalar()
    
    async def add_user_skill_gap(
        self,
        plan_id: int,
        skill_id: int,
        status: str,
        current_level: str,
        required_level: str,
        gap_score: float
    ):
        """Add skill gap for user"""
        query = text("""
            INSERT INTO career_user_skills (
                plan_id, skill_id, status, 
                current_level, required_level, gap_score
            ) VALUES (
                :plan_id, :skill_id, :status::status_enum,
                :current_level::current_level_enum, 
                :required_level::level_enum, :gap_score
            )
        """)
        await self.session.execute(query, {
            "plan_id": plan_id,
            "skill_id": skill_id,
            "status": status,
            "current_level": current_level,
            "required_level": required_level,
            "gap_score": gap_score
        })
    
    async def add_weekly_content(
        self,
        plan_id: int,
        week_number: int,
        skill_id: int,
        topic: str,
        description: str,
        resources: List[str]
    ):
        """Add weekly content to plan"""
        query = text("""
            INSERT INTO career_plan_content (
                plan_id, week_number, skill_id, 
                topic, description, resources
            ) VALUES (
                :plan_id, :week_number, :skill_id,
                :topic, :description, :resources
            )
        """)
        await self.session.execute(query, {
            "plan_id": plan_id,
            "week_number": week_number,
            "skill_id": skill_id,
            "topic": topic,
            "description": description,
            "resources": resources  # Will be converted to JSONB
        })
    
    async def get_user_plans(self, user_id: UUID) -> List[Dict[str, Any]]:
        """Get all plans for a user"""
        query = text("""
            SELECT 
                p.plan_id,
                t.track_name,
                p.confirmed_level as level,
                p.duration_weeks,
                p.created_at,
                p.updated_at,
                COUNT(pc.content_id) as total_weeks,
                COUNT(CASE WHEN pc.completed THEN 1 END) as completed_weeks,
                ROUND(
                    COUNT(CASE WHEN pc.completed THEN 1 END)::numeric / 
                    NULLIF(COUNT(pc.content_id), 0) * 100, 
                    2
                ) as progress_percentage
            FROM career_plan_info p
            JOIN career_tracks t ON p.track_id = t.track_id
            LEFT JOIN career_plan_content pc ON p.plan_id = pc.plan_id
            WHERE p.user_id = :user_id
            GROUP BY p.plan_id, t.track_name, p.confirmed_level, 
            p.duration_weeks, p.created_at, p.updated_at
            ORDER BY p.created_at DESC
        """)
        result = await self.session.execute(query, {"user_id": str(user_id)})
        return [dict(row._mapping) for row in result]
    
    async def get_plan_details(self, plan_id: int) -> Optional[Dict[str, Any]]:
        """Get complete plan details"""
        query = text("""
            SELECT 
                p.*,
                t.track_name,
                t.description as track_description
            FROM career_plan_info p
            JOIN career_tracks t ON p.track_id = t.track_id
            WHERE p.plan_id = :plan_id
        """)
        result = await self.session.execute(query, {"plan_id": plan_id})
        row = result.fetchone()
        return dict(row._mapping) if row else None
    
    async def get_plan_skill_gaps(self, plan_id: int) -> List[Dict[str, Any]]:
        """Get skill gaps for a plan"""
        query = text("""
            SELECT 
                us.*,
                s.skill_name,
                s.category,
                ts.importance_weight
            FROM career_user_skills us
            JOIN skills s ON us.skill_id = s.skill_id
            JOIN career_plan_info p ON us.plan_id = p.plan_id
            LEFT JOIN track_skills ts ON s.skill_id = ts.skill_id 
                AND p.track_id = ts.track_id
            WHERE us.plan_id = :plan_id
            ORDER BY us.gap_score DESC, ts.importance_weight DESC
        """)
        result = await self.session.execute(query, {"plan_id": plan_id})
        return [dict(row._mapping) for row in result]
    
    async def get_plan_weekly_content(self, plan_id: int) -> List[Dict[str, Any]]:
        """Get weekly content for a plan"""
        query = text("""
            SELECT 
                pc.*,
                s.skill_name,
                s.category
            FROM career_plan_content pc
            JOIN skills s ON pc.skill_id = s.skill_id
            WHERE pc.plan_id = :plan_id
            ORDER BY pc.week_number
        """)
        result = await self.session.execute(query, {"plan_id": plan_id})
        return [dict(row._mapping) for row in result]
    
    # =====================================================
    # ANALYTICS & STATS
    # =====================================================
    
    async def get_track_stats(self, track_id: int) -> Dict[str, Any]:
        """Get statistics for a track"""
        query = text("""
            SELECT 
                COUNT(DISTINCT p.user_id) as total_users,
                AVG(p.duration_weeks) as avg_duration,
                COUNT(p.plan_id) as total_plans,
                p.confirmed_level as level,
                COUNT(*) as level_count
            FROM career_plan_info p
            WHERE p.track_id = :track_id
            GROUP BY p.confirmed_level
        """)
        result = await self.session.execute(query, {"track_id": track_id})
        return [dict(row._mapping) for row in result]
    
    async def get_most_missing_skills(self, track_id: int) -> List[Dict[str, Any]]:
        """Get most commonly missing skills for a track"""
        query = text("""
            SELECT 
                s.skill_id,
                s.skill_name,
                s.category,
                COUNT(*) as missing_count,
                ROUND(AVG(us.gap_score), 2) as avg_gap_score
            FROM career_user_skills us
            JOIN skills s ON us.skill_id = s.skill_id
            JOIN career_plan_info p ON us.plan_id = p.plan_id
            WHERE p.track_id = :track_id
            AND us.status = 'missing'
            GROUP BY s.skill_id, s.skill_name, s.category
            ORDER BY missing_count DESC
            LIMIT 10
        """)
        result = await self.session.execute(query, {"track_id": track_id})
        return [dict(row._mapping) for row in result]