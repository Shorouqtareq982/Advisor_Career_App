# backend/shared/providers/supabase/database.py
from .client import supabase_client
from typing import Dict, List, Any, Optional, Union
from datetime import datetime
import json

class DatabaseProvider:
    """
    Complete Database Provider for GROWZA Platform
    Supports all features: Profiles, Skills, CV, Career Builder, Jobs, 
    Mock Interviews, Portfolio, Education, Certifications, Files, and Notifications
    """
    
    def __init__(self):
        self.client = supabase_client.get_client()

    # ============================================================
    # UNIVERSAL CRUD METHODS
    # ============================================================
    
    def create(self, table: str, data: Dict) -> Optional[Dict]:
        """Create a new record in any table"""
        try:
            response = self.client.table(table).insert(data).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            print(f"❌ Error creating in {table}: {e}")
            return None

    def read(self, table: str, filters: Dict = None, 
             columns: str = "*", limit: int = None, 
             order_by: str = None, desc: bool = False) -> List[Dict]:
        """Read records from a table with flexible filtering"""
        try:
            query = self.client.table(table).select(columns)
            
            if filters:
                for key, value in filters.items():
                    if isinstance(value, list):
                        query = query.in_(key, value)
                    else:
                        query = query.eq(key, value)
            
            if order_by:
                query = query.order(order_by, desc=desc)
            
            if limit:
                query = query.limit(limit)
            
            response = query.execute()
            return response.data
        except Exception as e:
            print(f"❌ Error reading from {table}: {e}")
            return []

    def update(self, table: str, data: Dict, filters: Dict) -> Optional[Dict]:
        """Update records in any table"""
        try:
            query = self.client.table(table).update(data)
            
            for key, value in filters.items():
                query = query.eq(key, value)
            
            response = query.execute()
            return response.data[0] if response.data else None
        except Exception as e:
            print(f"❌ Error updating {table}: {e}")
            return None

    def delete(self, table: str, filters: Dict) -> bool:
        """Delete records from any table"""
        try:
            query = self.client.table(table).delete()
            
            for key, value in filters.items():
                query = query.eq(key, value)
            
            query.execute()
            return True
        except Exception as e:
            print(f"❌ Error deleting from {table}: {e}")
            return False

    # ============================================================
    # PROFILES
    # ============================================================
    
    def get_profile_by_id(self, user_id: str) -> Optional[Dict]:
        """Get user profile by ID"""
        profiles = self.read("profiles", {"id": user_id}, limit=1)
        return profiles[0] if profiles else None

    def create_profile(self, profile_data: Dict) -> Optional[Dict]:
        """Create a new user profile"""
        return self.create("profiles", profile_data)

    def update_profile(self, user_id: str, update_data: Dict) -> Optional[Dict]:
        """Update user profile"""
        return self.update("profiles", update_data, {"id": user_id})

    def delete_profile(self, user_id: str) -> bool:
        """Soft delete user profile"""
        return self.update("profiles", {"is_active": False}, {"id": user_id}) is not None

    # ============================================================
    # SKILLS
    # ============================================================
    
    def add_user_skill(self, user_id: str, skill_name: str, image_url: str = None) -> Optional[Dict]:
        """Add a skill to user's profile"""
        skill_data = {
            "user_id": user_id,
            "name": skill_name,
            "imageurl": image_url,
            "is_public": True
        }
        return self.create("skill", skill_data)

    def get_user_skills(self, user_id: str) -> List[Dict]:
        """Get all skills for a user"""
        return self.read("skill", {"user_id": user_id})

    def remove_user_skill(self, user_id: str, skill_id: int) -> bool:
        """Remove a skill from user's profile"""
        return self.delete("skill", {"user_id": user_id, "skill_id": skill_id})

    def update_user_skill(self, user_id: str, skill_id: int, update_data: Dict) -> Optional[Dict]:
        """Update a user's skill"""
        return self.update("skill", update_data, {"user_id": user_id, "skill_id": skill_id})

    # ============================================================
    # CV / RESUME
    # ============================================================
    
    def upload_cv(self, user_id: str, file_url: str, text_content: str = None) -> Optional[Dict]:
        """Upload a new CV/resume"""
        # Auto-detect language
        language = "ar" if text_content and any(
            char in text_content for char in "ابتثجحخدذرزسشصضطظعغفقكلمنهوي"
        ) else "en"
        
        cv_data = {
            "user_id": user_id,
            "file_url": file_url,
            "text_content": text_content,
            "is_primary": True,
            "language": language
        }
        return self.create("cv", cv_data)

    def get_user_cvs(self, user_id: str) -> List[Dict]:
        """Get all CVs for a user"""
        return self.read("cv", {"user_id": user_id}, order_by="created_at", desc=True)

    def get_primary_cv(self, user_id: str) -> Optional[Dict]:
        """Get user's primary CV"""
        cvs = self.read("cv", {"user_id": user_id, "is_primary": True}, limit=1)
        return cvs[0] if cvs else None

    def set_primary_cv(self, user_id: str, cv_id: str) -> bool:
        """Set a CV as primary (unset others)"""
        # First, unset all primary CVs for this user
        self.update("cv", {"is_primary": False}, {"user_id": user_id})
        
        # Then set the specified CV as primary
        result = self.update("cv", {"is_primary": True}, {"cv_id": cv_id, "user_id": user_id})
        return result is not None

    def delete_cv(self, cv_id: str) -> bool:
        """Delete a CV"""
        return self.delete("cv", {"cv_id": cv_id})

    def request_cv_optimization(self, user_id: str, cv_id: str) -> Optional[Dict]:
        """Create a CV optimization request"""
        request_data = {
            "user_id": user_id,
            "cv_id": cv_id,
            "status": "pending"
        }
        return self.create("cv_optimization_requests", request_data)

    def save_cv_optimization_report(self, request_id: str, report_data: Dict) -> Optional[Dict]:
        """Save CV optimization analysis report"""
        update_data = {
            "status": "completed",
            "report": report_data,
            "completed_at": datetime.utcnow().isoformat()
        }
        return self.update("cv_optimization_requests", update_data, {"request_id": request_id})

    # ============================================================
    # CAREER BUILDER
    # ============================================================
    
    def get_all_tracks(self) -> List[Dict]:
        """Get all available career tracks"""
        return self.read("tracks")

    def get_track_by_id(self, track_id: int) -> Optional[Dict]:
        """Get a specific career track"""
        tracks = self.read("tracks", {"track_id": track_id}, limit=1)
        return tracks[0] if tracks else None

    def create_career_plan(self, user_id: str, track_id: int, duration_months: int = 6) -> Optional[Dict]:
        """Create a new career plan for user"""
        plan_data = {
            "user_id": user_id,
            "track_id": track_id,
            "duration_months": duration_months,
            "duration_weeks": duration_months * 4,
            "saved": False
        }
        return self.create("plan_info", plan_data)

    def get_user_plan(self, user_id: str) -> Optional[Dict]:
        """Get user's most recent career plan"""
        plans = self.read("plan_info", {"user_id": user_id}, limit=1, order_by="created_at", desc=True)
        return plans[0] if plans else None

    def get_all_user_plans(self, user_id: str) -> List[Dict]:
        """Get all plans for a user"""
        return self.read("plan_info", {"user_id": user_id}, order_by="created_at", desc=True)

    def mark_plan_as_saved(self, plan_id: int) -> Optional[Dict]:
        """Mark a plan as saved by user"""
        return self.update("plan_info", {"saved": True}, {"plan_id": plan_id})

    def delete_plan(self, plan_id: int) -> bool:
        """Delete a career plan"""
        return self.delete("plan_info", {"plan_id": plan_id})

    def get_plan_content(self, plan_id: int) -> List[Dict]:
        """Get all content for a career plan"""
        return self.read("plan_content", {"plan_id": plan_id}, order_by="week_number")

    def add_plan_content(self, plan_id: int, week_number: int, skill_id: int, 
                        goal: str, course_link: str = None) -> Optional[Dict]:
        """Add content to a career plan"""
        content_data = {
            "plan_id": plan_id,
            "week_number": week_number,
            "skill_id": skill_id,
            "goal": goal,
            "course_link": course_link
        }
        return self.create("plan_content", content_data)

    def remove_plan_content(self, plan_id: int, week_number: int, skill_id: int) -> bool:
        """Remove content from a career plan"""
        return self.delete("plan_content", {
            "plan_id": plan_id,
            "week_number": week_number,
            "skill_id": skill_id
        })

    def update_plan_content(self, plan_id: int, week_number: int, skill_id: int, 
                           update_data: Dict) -> Optional[Dict]:
        """Update plan content"""
        return self.update("plan_content", update_data, {
            "plan_id": plan_id,
            "week_number": week_number,
            "skill_id": skill_id
        })

    def get_skills_by_track(self, track_id: int) -> List[Dict]:
        """Get all skills associated with a career track"""
        return self.read("track_skills", {"track_id": track_id})

    def save_user_skill_for_plan(self, user_id: str, plan_id: int, 
                                 skill_id: int, status: str = "selected") -> Optional[Dict]:
        """Save user's skill selection for a plan"""
        skill_data = {
            "user_id": user_id,
            "plan_id": plan_id,
            "skill_id": skill_id,
            "status": status
        }
        return self.create("user_skills", skill_data)

    def get_skills_by_user_plan(self, user_id: str, plan_id: int) -> List[Dict]:
        """Get all skills selected by user for a specific plan"""
        return self.read("user_skills", {"user_id": user_id, "plan_id": plan_id})

    def update_user_plan_skill_status(self, user_id: str, plan_id: int, 
                                     skill_id: int, status: str) -> Optional[Dict]:
        """Update status of a skill in user's plan"""
        return self.update("user_skills", {"status": status}, {
            "user_id": user_id,
            "plan_id": plan_id,
            "skill_id": skill_id
        })

    # ============================================================
    # JOBS & RECOMMENDATIONS
    # ============================================================
    
    def save_job(self, job_data: Dict) -> Optional[Dict]:
        """Save a new job posting"""
        return self.create("jobs", job_data)

    def get_job_by_id(self, job_id: str) -> Optional[Dict]:
        """Get a specific job by ID"""
        jobs = self.read("jobs", {"job_id": job_id}, limit=1)
        return jobs[0] if jobs else None

    def search_jobs(self, filters: Dict = None, limit: int = 50) -> List[Dict]:
        """Search jobs with flexible filters"""
        try:
            query = self.client.table("jobs").select("*")
            
            if filters:
                if filters.get("title"):
                    query = query.ilike("title", f"%{filters['title']}%")
                if filters.get("company"):
                    query = query.ilike("company", f"%{filters['company']}%")
                if filters.get("location"):
                    query = query.ilike("location", f"%{filters['location']}%")
                if filters.get("job_type"):
                    query = query.eq("job_type", filters["job_type"])
                if filters.get("experience_level"):
                    query = query.eq("experience_level", filters["experience_level"])
            
            if limit:
                query = query.limit(limit)
            
            response = query.execute()
            return response.data
        except Exception as e:
            print(f"❌ Error searching jobs: {e}")
            return []

    def update_job(self, job_id: str, update_data: Dict) -> Optional[Dict]:
        """Update job posting"""
        return self.update("jobs", update_data, {"job_id": job_id})

    def delete_job(self, job_id: str) -> bool:
        """Delete a job posting"""
        return self.delete("jobs", {"job_id": job_id})

    def create_recommendation(self, user_id: str, job_id: str, cv_id: str, 
                            score: float, model_version: str = "v1.0") -> Optional[Dict]:
        """Create a job recommendation for user"""
        data = {
            "user_id": user_id,
            "job_id": job_id,
            "cv_id": cv_id,
            "score": score,
            "status": "new",
            "model_version": model_version
        }
        return self.create("recommendations", data)

    def get_user_recommendations(self, user_id: str, limit: int = 20) -> List[Dict]:
        """Get job recommendations for user"""
        return self.read("recommendations", {"user_id": user_id}, 
                        limit=limit, order_by="score", desc=True)

    def update_recommendation_status(self, recommendation_id: str, status: str) -> Optional[Dict]:
        """Update recommendation status (viewed, dismissed, etc.)"""
        return self.update("recommendations", {"status": status}, 
                          {"recommendation_id": recommendation_id})

    def apply_to_job(self, user_id: str, job_id: str, cv_id: str) -> Optional[Dict]:
        """Apply to a job"""
        application_data = {
            "user_id": user_id,
            "job_id": job_id,
            "cv_id": cv_id,
            "status": "pending"
        }
        return self.create("job_applications", application_data)

    def get_applied_jobs(self, user_id: str) -> List[Dict]:
        """Get all jobs user has applied to"""
        return self.read("job_applications", {"user_id": user_id}, 
                        order_by="created_at", desc=True)

    def update_application_status(self, application_id: str, status: str) -> Optional[Dict]:
        """Update job application status"""
        return self.update("job_applications", {"status": status}, 
                          {"application_id": application_id})

    def get_application_by_id(self, application_id: str) -> Optional[Dict]:
        """Get specific job application"""
        apps = self.read("job_applications", {"application_id": application_id}, limit=1)
        return apps[0] if apps else None

    # ============================================================
    # MOCK INTERVIEW
    # ============================================================
    
    def start_interview_session(self, user_id: str, job_role: str, 
                               difficulty: str = "medium") -> Optional[Dict]:
        """Start a new mock interview session"""
        session_data = {
            "user_id": user_id,
            "job_role": job_role,
            "difficulty": difficulty,
            "status": "in_progress"
        }
        return self.create("interview_sessions", session_data)

    def get_interview_session(self, session_id: str) -> Optional[Dict]:
        """Get interview session details"""
        sessions = self.read("interview_sessions", {"session_id": session_id}, limit=1)
        return sessions[0] if sessions else None

    def get_user_interview_sessions(self, user_id: str) -> List[Dict]:
        """Get all interview sessions for a user"""
        return self.read("interview_sessions", {"user_id": user_id}, 
                        order_by="created_at", desc=True)

    def save_interview_response(self, session_id: str, question_number: int, 
                               question_text: str, user_response: str, 
                               audio_url: str = None) -> Optional[Dict]:
        """Save user's response to an interview question"""
        response_data = {
            "session_id": session_id,
            "question_number": question_number,
            "question_text": question_text,
            "user_response": user_response,
            "audio_url": audio_url
        }
        return self.create("interview_responses", response_data)

    def save_interview_analysis(self, response_id: str, analysis_data: Dict) -> Optional[Dict]:
        """Save AI analysis of interview response"""
        update_data = {
            "score": analysis_data.get("score"),
            "feedback": analysis_data.get("feedback"),
            "strengths": analysis_data.get("strengths"),
            "improvements": analysis_data.get("improvements"),
            "analyzed": True
        }
        return self.update("interview_responses", update_data, {"response_id": response_id})

    def complete_interview_session(self, session_id: str, overall_score: float, 
                                  final_feedback: str) -> Optional[Dict]:
        """Mark interview session as completed"""
        update_data = {
            "status": "completed",
            "overall_score": overall_score,
            "final_feedback": final_feedback,
            "completed_at": datetime.utcnow().isoformat()
        }
        return self.update("interview_sessions", update_data, {"session_id": session_id})

    def get_interview_complete_session(self, session_id: str) -> Optional[Dict]:
        """Get complete interview session with all responses"""
        try:
            session = self.get_interview_session(session_id)
            if not session:
                return None
            
            responses = self.read("interview_responses", {"session_id": session_id}, 
                                order_by="question_number")
            
            return {
                "session": session,
                "responses": responses
            }
        except Exception as e:
            print(f"❌ Error getting complete interview session: {e}")
            return None

    def delete_interview_session(self, session_id: str) -> bool:
        """Delete an interview session (and its responses via cascade)"""
        return self.delete("interview_sessions", {"session_id": session_id})

    # ============================================================
    # PORTFOLIO / PROJECTS
    # ============================================================
    
    def save_project(self, user_id: str, project_data: Dict) -> Optional[Dict]:
        """Add a project to user's portfolio"""
        project_data["user_id"] = user_id
        return self.create("projects", project_data)

    def get_user_projects(self, user_id: str) -> List[Dict]:
        """Get all projects in user's portfolio"""
        return self.read("projects", {"user_id": user_id}, 
                        order_by="created_at", desc=True)

    def get_project_by_id(self, project_id: str) -> Optional[Dict]:
        """Get a specific project"""
        projects = self.read("projects", {"project_id": project_id}, limit=1)
        return projects[0] if projects else None

    def update_project(self, user_id: str, project_id: str, update_data: Dict) -> Optional[Dict]:
        """Update a project"""
        return self.update("projects", update_data, 
                          {"user_id": user_id, "project_id": project_id})

    def delete_project(self, user_id: str, project_id: str) -> bool:
        """Delete a project from portfolio"""
        return self.delete("projects", {"user_id": user_id, "project_id": project_id})

    def toggle_project_visibility(self, project_id: str, is_public: bool) -> Optional[Dict]:
        """Toggle project visibility (public/private)"""
        return self.update("projects", {"is_public": is_public}, {"project_id": project_id})

    # ============================================================
    # EDUCATION
    # ============================================================
    
    def add_education(self, user_id: str, education_data: Dict) -> Optional[Dict]:
        """Add education entry to user's profile"""
        education_data["user_id"] = user_id
        return self.create("education", education_data)

    def get_user_education(self, user_id: str) -> List[Dict]:
        """Get all education entries for user"""
        return self.read("education", {"user_id": user_id}, 
                        order_by="end_date", desc=True)

    def update_education(self, user_id: str, edu_id: str, update_data: Dict) -> Optional[Dict]:
        """Update an education entry"""
        return self.update("education", update_data, 
                          {"user_id": user_id, "edu_id": edu_id})

    def delete_education(self, user_id: str, edu_id: str) -> bool:
        """Delete an education entry"""
        return self.delete("education", {"user_id": user_id, "edu_id": edu_id})

    # ============================================================
    # CERTIFICATIONS
    # ============================================================
    
    def add_certification(self, user_id: str, certification_data: Dict) -> Optional[Dict]:
        """Add certification to user's profile"""
        certification_data["user_id"] = user_id
        return self.create("certifications", certification_data)

    def get_user_certifications(self, user_id: str) -> List[Dict]:
        """Get all certifications for user"""
        return self.read("certifications", {"user_id": user_id}, 
                        order_by="issue_date", desc=True)

    def update_certification(self, user_id: str, cert_id: str, update_data: Dict) -> Optional[Dict]:
        """Update a certification"""
        return self.update("certifications", update_data, 
                          {"user_id": user_id, "cert_id": cert_id})

    def delete_certification(self, user_id: str, cert_id: str) -> bool:
        """Delete a certification"""
        return self.delete("certifications", {"user_id": user_id, "cert_id": cert_id})

    # ============================================================
    # FILES
    # ============================================================
    
    def save_file_metadata(self, user_id: str, file_data: Dict) -> Optional[Dict]:
        """Save file metadata"""
        file_data["user_id"] = user_id
        file_data["is_deleted"] = False
        return self.create("files", file_data)

    def get_user_files(self, user_id: str, include_deleted: bool = False) -> List[Dict]:
        """Get all files for a user"""
        filters = {"user_id": user_id}
        if not include_deleted:
            filters["is_deleted"] = False
        
        return self.read("files", filters, order_by="created_at", desc=True)

    def get_file_by_id(self, file_id: str) -> Optional[Dict]:
        """Get file metadata by ID"""
        files = self.read("files", {"file_id": file_id}, limit=1)
        return files[0] if files else None

    def update_file_metadata(self, file_id: str, update_data: Dict) -> Optional[Dict]:
        """Update file metadata"""
        return self.update("files", update_data, {"file_id": file_id})

    def delete_file(self, file_id: str) -> bool:
        """Soft delete a file (mark as deleted)"""
        return self.update("files", {"is_deleted": True}, {"file_id": file_id}) is not None

    def permanently_delete_file(self, file_id: str) -> bool:
        """Permanently delete file record"""
        return self.delete("files", {"file_id": file_id})

    # ============================================================
    # NOTIFICATIONS
    # ============================================================
    
    def create_notification(self, user_id: str, title: str, message: str, 
                          notification_type: str = "info") -> Optional[Dict]:
        """Create a new notification"""
        notification_data = {
            "user_id": user_id,
            "title": title,
            "message": message,
            "type": notification_type,
            "is_read": False
        }
        return self.create("notifications", notification_data)

    def get_user_notifications(self, user_id: str, unread_only: bool = False, 
                              limit: int = 50) -> List[Dict]:
        """Get notifications for a user"""
        filters = {"user_id": user_id}
        if unread_only:
            filters["is_read"] = False
        
        return self.read("notifications", filters, limit=limit, 
                        order_by="created_at", desc=True)

    def mark_notification_as_read(self, notification_id: str) -> Optional[Dict]:
        """Mark a notification as read"""
        return self.update("notifications", {"is_read": True}, 
                          {"notification_id": notification_id})

    def mark_all_notifications_read(self, user_id: str) -> bool:
        """Mark all notifications as read for a user"""
        try:
            self.client.table("notifications").update({"is_read": True}).eq("user_id", user_id).execute()
            return True
        except Exception as e:
            print(f"❌ Error marking all notifications as read: {e}")
            return False

    def delete_notification(self, notification_id: str) -> bool:
        """Delete a notification"""
        return self.delete("notifications", {"notification_id": notification_id})

    def get_unread_count(self, user_id: str) -> int:
        """Get count of unread notifications"""
        notifications = self.read("notifications", {"user_id": user_id, "is_read": False})
        return len(notifications)

    # ============================================================
    # ANALYTICS & REPORTING
    # ============================================================
    
    def get_user_activity_summary(self, user_id: str) -> Dict:
        """Get summary of user's activity across the platform"""
        try:
            return {
                "total_cvs": len(self.get_user_cvs(user_id)),
                "total_skills": len(self.get_user_skills(user_id)),
                "total_projects": len(self.get_user_projects(user_id)),
                "total_applications": len(self.get_applied_jobs(user_id)),
                "total_interviews": len(self.get_user_interview_sessions(user_id)),
                "total_plans": len(self.get_all_user_plans(user_id)),
                "unread_notifications": self.get_unread_count(user_id)
            }
        except Exception as e:
            print(f"❌ Error getting user activity summary: {e}")
            return {}

    # ============================================================
    # BATCH OPERATIONS
    # ============================================================
    
    def batch_create(self, table: str, data_list: List[Dict]) -> List[Dict]:
        """Create multiple records at once"""
        try:
            response = self.client.table(table).insert(data_list).execute()
            return response.data
        except Exception as e:
            print(f"❌ Error batch creating in {table}: {e}")
            return []

    def batch_update(self, table: str, updates: List[Dict]) -> List[Dict]:
        """Update multiple records at once"""
        try:
            response = self.client.table(table).upsert(updates).execute()
            return response.data
        except Exception as e:
            print(f"❌ Error batch updating in {table}: {e}")
            return []


# ============================================================
# GLOBAL INSTANCE
# ============================================================

# Create a single global instance to be imported across the application
db = DatabaseProvider()


# ============================================================
# USAGE EXAMPLES
# ============================================================

"""
Example Usage:

# Import the global instance
from backend.shared.providers.supabase.database import db

# Profile operations
profile = db.get_profile_by_id("user-123")
db.update_profile("user-123", {"full_name": "Ahmed Ali"})

# Skills
db.add_user_skill("user-123", "Python", "https://example.com/python.png")
skills = db.get_user_skills("user-123")

# CV operations
db.upload_cv("user-123", "https://storage.com/cv.pdf", "CV text content")
primary_cv = db.get_primary_cv("user-123")

# Career planning
tracks = db.get_all_tracks()
plan = db.create_career_plan("user-123", track_id=1, duration_months=6)
db.add_plan_content(plan["plan_id"], week_number=1, skill_id=5, goal="Learn Python basics")

# Job applications
jobs = db.search_jobs({"title": "Python Developer", "location": "Cairo"})
db.apply_to_job("user-123", job["job_id"], cv["cv_id"])

# Mock interviews
session = db.start_interview_session("user-123", "Software Engineer")
db.save_interview_response(session["session_id"], 1, "Tell me about yourself", "I am...")

# Portfolio
db.save_project("user-123", {
    "title": "E-commerce Platform",
    "description": "Full-stack web app",
    "tech_stack": ["React", "Node.js", "PostgreSQL"],
    "project_url": "https://github.com/user/project"
})

# Notifications
db.create_notification("user-123", "New Job Match", "We found 5 jobs matching your profile")
notifications = db.get_user_notifications("user-123", unread_only=True)

# Analytics
summary = db.get_user_activity_summary("user-123")
"""