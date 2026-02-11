from shared.providers import db
from features.career_builder.schemas import CareerPlanCreateSchema
from typing import Dict, List, Optional

class CareerBuilderService:
    
    def get_all_tracks(self) -> List[Dict]:
        """Fetch all learning tracks"""
        return db.get_tracks()
    
    def create_plan(self, plan_data: CareerPlanCreateSchema) -> Dict:
        """Create a new career plan"""
        plan = db.create_career_plan(
            user_id=plan_data.user_id,
            track_id=plan_data.track_id,
            duration_months=plan_data.duration_months
        )
        # After creating the plan, add weekly content (skills)
        self._generate_plan_content(plan["plan_id"], plan_data.track_id)
        return plan
    
    def _generate_plan_content(self, plan_id: int, track_id: int):
        """Generate week-by-week plan content based on required skills"""
        skills = db.get_skills_by_track(track_id)
        # Simple example of distributing skills across weeks
        for i, skill in enumerate(skills[:8]):  # First 8 skills
            db.add_plan_content(
                plan_id=plan_id,
                week_number=i + 1,
                skill_id=skill["skill_id"],
                goal=f"Learn {skill['skill_name']}",
                course_link=f"https://example.com/course/{skill['skill_name'].lower().replace(' ', '-')}"
            )
    
    def get_plan(self, user_id: str) -> Optional[Dict]:
        """Fetch the user's career plan with its content"""
        plan = db.get_user_plan(user_id)
        if not plan:
            return None
        content = db.get_plan_content(plan["plan_id"])
        plan["content"] = content
        return plan
    
    def save_plan(self, user_id: str) -> Dict:
        """Save the plan (update its saved status)"""
        plan = db.get_user_plan(user_id)
        if plan:
            updated = db.update("plan_info", {"saved": True}, {"plan_id": plan["plan_id"]})
            return updated
        return None
    
    def select_skill(self, user_id: str, plan_id: int, skill_id: int) -> Dict:
        """Select a specific skill from the plan"""
        return db.save_user_skill(user_id, plan_id, skill_id, "selected")
