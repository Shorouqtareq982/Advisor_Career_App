# ✅ Enhanced with track_skills metadata
import json, logging
from uuid import UUID
from typing import Optional, Dict, Any, List

logger = logging.getLogger(__name__)

class CareerRepository:
    def __init__(self, db_provider):
        self.client = db_provider.client
        logger.debug(f"CareerRepository initialized")

    async def get_all_tracks(self) -> List[Dict[str, Any]]:
        try:
            result = self.client.table("career_tracks").select("*").execute()
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error: {e}")
            raise

    async def get_track_by_id(self, track_id: int) -> Optional[Dict[str, Any]]:
        try:
            result = self.client.table("career_tracks").select("*").eq("track_id", track_id).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error: {e}")
            raise

    async def search_skills_by_name(self, query: str) -> List[Dict[str, Any]]:
        try:
            result = self.client.table("career_skills").select("*").ilike("skill_name", f"%{query}%").execute()
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error: {e}")
            raise

    async def get_skills_by_track(self, track_id: int, level: str = 'beginner') -> List[Dict[str, Any]]:
        """
        Get skills for track WITH metadata (importance, weeks)
        """
        try:
            # Get track_skills with metadata
            ts_result = self.client.table("track_skills") \
                .select("skill_id, importance_weight, beginner_weeks, intermediate_weeks, advanced_weeks, is_core") \
                .eq("track_id", track_id) \
                .execute()
            
            if not ts_result.data:
                return []
            
            # Create lookup map
            metadata_map = {
                item["skill_id"]: item
                for item in ts_result.data
            }
            
            # Get skill IDs
            skill_ids = list(metadata_map.keys())
            
            # Get full skill details
            skills_result = self.client.table("career_skills") \
                .select("*") \
                .in_("skill_id", skill_ids) \
                .execute()
            
            # Merge metadata
            skills = []
            for skill in (skills_result.data or []):
                skill_id = skill["skill_id"]
                metadata = metadata_map.get(skill_id, {})
                
                # Add metadata
                skill["importance"] = metadata.get("importance_weight", 3)
                skill["is_core"] = metadata.get("is_core", True)
                
                # Add duration based on level
                if level == 'beginner':
                    skill["duration_weeks"] = metadata.get("beginner_weeks", 4)
                elif level == 'intermediate':
                    skill["duration_weeks"] = metadata.get("intermediate_weeks", 3)
                elif level == 'advanced':
                    skill["duration_weeks"] = metadata.get("advanced_weeks", 2)
                else:
                    skill["duration_weeks"] = metadata.get("beginner_weeks", 4)
                
                skills.append(skill)
            
            return skills
            
        except Exception as e:
            logger.error(f"Error: {e}", exc_info=True)
            raise

    async def save_cv(self, file_url: str, text_content: str, parsed_content: dict, user_id: Optional[UUID] = None) -> Optional[UUID]:
        try:
            data = {"file_url": file_url, "text_content": text_content, "parsed_content": parsed_content}
            if user_id: data["user_id"] = str(user_id)
            result = self.client.table("cv").insert(data).execute()
            return UUID(result.data[0]["cv_id"]) if result.data else None
        except Exception as e:
            logger.error(f"Error: {e}")
            raise

    async def get_cv_by_id(self, cv_id: UUID) -> Optional[Dict[str, Any]]:
        try:
            result = self.client.table("cv").select("*").eq("cv_id", str(cv_id)).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error: {e}")
            raise

    async def save_analysis_cache(self, cv_id: UUID, track_id: int, analysis_data: dict) -> None:
        try:
            data = {"cv_id": str(cv_id), "track_id": track_id, "analysis_data": json.dumps(analysis_data)}
            existing = self.client.table("analysis_cache").select("*").eq("cv_id", str(cv_id)).eq("track_id", track_id).execute()
            if existing.data:
                self.client.table("analysis_cache").update({"analysis_data": json.dumps(analysis_data)}).eq("cv_id", str(cv_id)).eq("track_id", track_id).execute()
            else:
                self.client.table("analysis_cache").insert(data).execute()
        except Exception as e:
            logger.error(f"Error: {e}")
            raise

    async def get_analysis_cache(self, cv_id: UUID, track_id: int) -> Optional[Dict[str, Any]]:
        try:
            result = self.client.table("analysis_cache").select("*").eq("cv_id", str(cv_id)).eq("track_id", track_id).execute()
            if result.data:
                return json.loads(result.data[0].get("analysis_data"))
            return None
        except Exception as e:
            logger.error(f"Error: {e}")
            return None

    async def delete_analysis_cache(self, cv_id: UUID, track_id: int) -> None:
        try:
            self.client.table("analysis_cache").delete().eq("cv_id", str(cv_id)).eq("track_id", track_id).execute()
        except Exception as e:
            logger.error(f"Error: {e}")
            raise

    async def get_user_cvs(self, user_id: UUID) -> List[Dict[str, Any]]:
        try:
            result = self.client.table("cv").select("*").eq("user_id", str(user_id)).execute()
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error: {e}")
            raise