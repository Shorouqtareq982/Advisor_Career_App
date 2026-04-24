"""
Capstone Project Management Service
Manages the 2 capstone projects in weeks 29-32 of the 32-week optimized plan.

Capstone 1 (Weeks 29-30): End-to-End ML Pipeline
  - Design and build complete ML pipeline from data ingestion to model deployment
  - Demonstrate understanding of preprocessing, feature engineering, model selection, evaluation
  - Portfolio piece for GitHub

Capstone 2 (Weeks 31-32): Real-World Analytics Problem
  - Advanced analysis on complex real-world dataset
  - Integrate multiple skills: ML, visualization, statistics, feature engineering
  - Publication-ready insights and visualizations
  - Portfolio piece for GitHub
"""

import logging
from typing import Dict, List, Optional, Any
from uuid import UUID
from datetime import datetime

from features.career_builder.schemas.checkpoint_schemas import (
    CapstoneProject,
    CapstoneSubmission,
    CapstoneEvaluation,
)

logger = logging.getLogger(__name__)


class CapstoneProjectManager:
    """
    Manages capstone projects for 32-week optimized plans.
    Provides project specifications, submission handling, and evaluation.
    """

    def __init__(self):
        self.projects = self._define_capstone_projects()

    def _define_capstone_projects(self) -> List[Dict]:
        """Define the two capstone projects"""
        return [
            {
                "project_id": 1,
                "project_number": 1,
                "phase": "capstone_1",
                "weeks": [29, 30],
                "title": "End-to-End ML Pipeline: Predictive Analytics",
                "description": (
                    "Build a complete machine learning pipeline from raw data to "
                    "model deployment. This project demonstrates your ability to:"
                    "\n• Load and explore complex datasets"
                    "\n• Handle missing values and outliers"
                    "\n• Engineer meaningful features"
                    "\n• Train multiple models and compare performance"
                    "\n• Select and tune the best model"
                    "\n• Evaluate using appropriate metrics"
                    "\n• Document the entire process"
                ),
                "learning_objectives": [
                    "Apply end-to-end data science workflow",
                    "Implement feature engineering techniques",
                    "Use scikit-learn for model training and evaluation",
                    "Compare multiple models systematically",
                    "Interpret model results and limitations",
                    "Document code and methodology",
                    "Create production-ready pipeline",
                ],
                "required_skills": [
                    "Python Basics",
                    "NumPy",
                    "Pandas",
                    "Statistics & Probability",
                    "Matplotlib",
                    "Seaborn",
                    "Model Evaluation & Metrics",
                    "Scikit-learn & Supervised Learning",
                    "Feature Engineering",
                ],
                "project_type": "portfolio_piece",
                "difficulty_level": "intermediate_advanced",
                "deliverables": [
                    "Jupyter notebook with complete pipeline",
                    "Cleaned dataset and preprocessing code",
                    "Exploratory data analysis (EDA) with visualizations",
                    "Feature engineering notebook",
                    "Model training and comparison results",
                    "Evaluation metrics and model selection justification",
                    "Production-ready Python script (no notebook)",
                    "README with project overview and instructions",
                    "Requirements.txt with all dependencies",
                ],
                "evaluation_criteria": {
                    "Data Understanding & Exploration": 15,
                    "Feature Engineering Quality": 15,
                    "Model Selection & Training": 20,
                    "Evaluation & Metrics": 20,
                    "Code Quality & Documentation": 15,
                    "Reproducibility & Deployment": 10,
                    "Insights & Recommendations": 5,
                },
                "github_portfolio_requirements": [
                    "Clear repository name (e.g., 'ml-pipeline-project')",
                    "Comprehensive README with project description",
                    "Well-commented code throughout",
                    "Requirements.txt for easy reproduction",
                    "Sample data or instructions to get data",
                    "Jupyter notebook viewable on GitHub",
                    "Visualization screenshots in README",
                    "Instructions for running the project",
                ],
                "estimated_hours": 35,
                "dataset_suggestion": (
                    "Choose from Kaggle datasets: Housing Price Prediction, "
                    "Customer Churn, Credit Risk, or similar ~50k-500k rows"
                ),
                "skills_demonstrated": [
                    "Data preprocessing mastery",
                    "Statistical understanding",
                    "Feature engineering creativity",
                    "ML algorithm knowledge",
                    "Model evaluation expertise",
                    "Professional coding practices",
                ],
            },
            {
                "project_id": 2,
                "project_number": 2,
                "phase": "capstone_2",
                "weeks": [31, 32],
                "title": "Advanced Analytics: Business Intelligence & Insights",
                "description": (
                    "Perform advanced analytics on a complex real-world dataset "
                    "to extract actionable business insights. This project demonstrates:"
                    "\n• Advanced data analysis techniques"
                    "\n• Multi-variate analysis and pattern discovery"
                    "\n• Unsupervised learning for segmentation/clustering"
                    "\n• Advanced visualizations for stakeholder communication"
                    "\n• Statistical hypothesis testing"
                    "\n• Business insight articulation"
                    "\n• Professional reporting and presentation"
                ),
                "learning_objectives": [
                    "Perform exploratory data analysis on complex datasets",
                    "Apply unsupervised learning (clustering) techniques",
                    "Conduct statistical hypothesis testing",
                    "Extract actionable business insights",
                    "Create publication-quality visualizations",
                    "Build professional analytics report",
                    "Communicate findings to non-technical stakeholders",
                ],
                "required_skills": [
                    "Python Basics",
                    "NumPy",
                    "Pandas",
                    "Statistics & Probability",
                    "Matplotlib",
                    "Seaborn",
                    "SQL & Databases",
                    "Unsupervised Learning & Clustering",
                    "Feature Engineering",
                ],
                "project_type": "real_world_app",
                "difficulty_level": "advanced",
                "deliverables": [
                    "Comprehensive Jupyter notebook with analysis",
                    "SQL queries for data extraction (if applicable)",
                    "Advanced visualizations (10+ publication-quality charts)",
                    "Statistical analysis and hypothesis test results",
                    "Clustering analysis with interpretation",
                    "Executive summary (1-2 page PDF)",
                    "Detailed findings report (5-10 pages)",
                    "Presentation slides (10-15 slides)",
                    "Data processing scripts",
                    "README with project documentation",
                ],
                "evaluation_criteria": {
                    "Data Exploration Depth": 15,
                    "Statistical Analysis": 15,
                    "Clustering/Pattern Discovery": 15,
                    "Visualization Quality": 15,
                    "Insight Discovery & Actionability": 20,
                    "Documentation & Clarity": 10,
                    "Presentation Quality": 10,
                },
                "github_portfolio_requirements": [
                    "Descriptive repository name (e.g., 'business-analytics-project')",
                    "Executive summary at top of README",
                    "Key findings highlighted with statistics",
                    "High-resolution visualization screenshots",
                    "PDF report included in repository",
                    "Link to presentation slides",
                    "Clear data source attribution",
                    "Instructions for reproducing analysis",
                ],
                "estimated_hours": 40,
                "dataset_suggestion": (
                    "Real-world datasets: Ecommerce transactions, Customer behavior, "
                    "Weather data, Sports statistics, or social media analytics. "
                    "Preferably 100k+ rows with multiple dimensions"
                ),
                "skills_demonstrated": [
                    "Advanced analytics expertise",
                    "Statistical rigor",
                    "Unsupervised learning application",
                    "Visualization mastery",
                    "Business acumen",
                    "Communication skills",
                    "Professional reporting",
                ],
            },
        ]

    def get_capstone_project(self, project_number: int) -> Optional[Dict]:
        """Get details of a specific capstone project"""
        for project in self.projects:
            if project["project_number"] == project_number:
                return project
        return None

    def get_all_projects(self) -> List[Dict]:
        """Get all capstone projects"""
        return self.projects

    def get_project_timeline(self) -> Dict[str, Any]:
        """Get timeline for capstone projects"""
        return {
            "capstone_1": {
                "weeks": [29, 30],
                "duration_hours": 35,
                "title": "End-to-End ML Pipeline",
                "phase": "capstone_1",
                "checkpoint_week": 30,
            },
            "capstone_2": {
                "weeks": [31, 32],
                "duration_hours": 40,
                "title": "Advanced Analytics",
                "phase": "capstone_2",
                "checkpoint_week": 32,
            },
        }

    def validate_capstone_submission(
        self, submission: CapstoneSubmission
    ) -> Dict[str, Any]:
        """
        Validate that a capstone submission includes all required deliverables.
        """
        project = self.get_capstone_project(submission.project_number)
        if not project:
            return {"valid": False, "error": f"Project {submission.project_number} not found"}

        deliverables = project["deliverables"]
        validation_results = {
            "github_repo_url": bool(submission.github_repo_url),
            "project_description": bool(submission.project_description),
            "technologies_used": len(submission.technologies_used) > 0,
            "key_features": len(submission.key_features) > 0,
            "challenges_addressed": bool(submission.challenges_overcome),
            "learning_reflection": bool(submission.what_you_learned),
            "github_quality": self._assess_github_quality(
                submission.github_repo_url, submission.project_number
            ),
        }

        overall_valid = all(validation_results.values())
        return {
            "valid": overall_valid,
            "submission_validation": validation_results,
            "missing_items": [k for k, v in validation_results.items() if not v],
        }

    def _assess_github_quality(self, repo_url: str, project_number: int) -> bool:
        """
        Assess if GitHub repo looks professional and well-documented.
        (In production, would do actual GitHub API checks)
        """
        requirements = {
            1: ["README", "requirements.txt", "notebook", "data", "scripts"],
            2: ["README", "requirements.txt", "notebook", "visualizations", "report"],
        }
        # Simplified check - in production would verify actual GitHub repo structure
        return bool(repo_url and repo_url.startswith(("https://github.com", "http://github.com")))

    def generate_evaluation_rubric(self, project_number: int) -> Dict[str, Any]:
        """Generate detailed evaluation rubric for a project"""
        project = self.get_capstone_project(project_number)
        if not project:
            return {}

        criteria = project["evaluation_criteria"]
        rubric = {
            "project_number": project_number,
            "project_title": project["title"],
            "total_points": 100,
            "criteria": {},
        }

        for criterion, weight in criteria.items():
            rubric["criteria"][criterion] = {
                "weight": weight,
                "points": weight,
                "excellent": f"{criterion}: Exceeds expectations (90-100%)",
                "good": f"{criterion}: Meets expectations (80-89%)",
                "acceptable": f"{criterion}: Acceptable (70-79%)",
                "needs_improvement": f"{criterion}: Below expectations (<70%)",
            }

        return rubric

    def create_project_kickoff_guide(self, project_number: int) -> Dict[str, Any]:
        """
        Create a comprehensive kickoff guide for students starting a capstone project.
        """
        project = self.get_capstone_project(project_number)
        if not project:
            return {}

        guide = {
            "project_number": project_number,
            "project_title": project["title"],
            "duration_weeks": len(project["weeks"]),
            "estimated_hours": project["estimated_hours"],
            "difficulty": project["difficulty_level"],
            "kickoff_checklist": [
                "☐ Read project description and learning objectives",
                "☐ Review required skills checklist",
                "☐ Choose or obtain your dataset",
                "☐ Set up GitHub repository",
                "☐ Create project planning document",
                "☐ Break down into weekly milestones",
                "☐ Set up development environment",
            ],
            "phase_breakdown": self._generate_phase_breakdown(project),
            "data_selection_guidance": project.get("dataset_suggestion", ""),
            "portfolio_preparation": {
                "github_requirements": project["github_portfolio_requirements"],
                "what_employers_look_for": [
                    "Clean, readable, well-commented code",
                    "Comprehensive documentation and README",
                    "Evidence of problem-solving approach",
                    "Professional presentation of results",
                    "Attention to detail and completeness",
                ],
            },
            "success_metrics": [
                "All deliverables included and professional quality",
                f"Code demonstrates mastery of required skills",
                "GitHub repository is well-organized and documented",
                "Project tells a clear story from problem to solution",
                "Insights/results are actionable and well-articulated",
            ],
        }

        return guide

    def _generate_phase_breakdown(self, project: Dict) -> Dict[str, Any]:
        """Generate week-by-week phase breakdown for project"""
        weeks = project["weeks"]
        if len(weeks) == 2:
            return {
                f"Week {weeks[0]}": {
                    "focus": "Planning, Setup, and Exploration",
                    "tasks": [
                        "Finalize project scope and research questions",
                        "Set up GitHub repository and development environment",
                        "Exploratory Data Analysis (EDA)",
                        "Identify data quality issues and preprocessing needs",
                    ],
                },
                f"Week {weeks[1]}": {
                    "focus": "Analysis, Modeling, and Documentation",
                    "tasks": [
                        "Data preprocessing and feature engineering",
                        "Model training and evaluation" if project["project_number"] == 1 else
                        "Statistical analysis and clustering",
                        "Final visualizations and insights",
                        "Documentation and GitHub readiness",
                    ],
                },
            }
        return {}

    def generate_submission_reminder(
        self, project_number: int, days_until_deadline: int
    ) -> str:
        """Generate a reminder message for students approaching deadline"""
        project = self.get_capstone_project(project_number)
        if not project:
            return ""

        deliverables = len(project["deliverables"])
        hours = project["estimated_hours"]

        if days_until_deadline >= 7:
            tone = "On track! Keep making steady progress."
        elif days_until_deadline >= 3:
            tone = "Final sprint! Focus on completeness and quality."
        else:
            tone = "Crunch time! Make sure all deliverables are included."

        return (
            f"📌 Capstone {project_number}: {project['title']}\n"
            f"⏰ {days_until_deadline} days until deadline\n"
            f"📋 {deliverables} deliverables to complete\n"
            f"⏱️  {hours} hours of work estimated\n"
            f"💪 {tone}\n"
            f"✅ Checklist: GitHub repo ready, README updated, all code committed"
        )

    def create_portfolio_optimization_guide(self, project_number: int) -> Dict[str, Any]:
        """
        Create guidance on optimizing capstone for portfolio/resume.
        """
        project = self.get_capstone_project(project_number)
        if not project:
            return {}

        return {
            "project_number": project_number,
            "portfolio_title": (
                f"Portfolio Project {project_number}: {project['title']}"
            ),
            "linkedin_summary": self._generate_linkedin_summary(project),
            "resume_bullet_points": [
                f"Developed {project['title'].lower()} "
                f"demonstrating expertise in {', '.join(project['skills_demonstrated'][:3])}",
                f"Analyzed large-scale dataset using Python, "
                f"scikit-learn, and statistical methods",
                f"Created production-ready code with comprehensive documentation",
                f"Delivered actionable insights through data visualization",
            ],
            "github_optimization": {
                "repository_name": self._suggest_repo_name(project),
                "star_earning_elements": project["github_portfolio_requirements"],
                "emoji_usage": self._suggest_emojis(project),
            },
            "job_interview_talking_points": [
                "Why I chose this dataset/problem",
                "Challenges overcome during implementation",
                "Key technical decisions and tradeoffs",
                "What I learned from the project",
                "How this project demonstrates my skills",
            ],
        }

    def _generate_linkedin_summary(self, project: Dict) -> str:
        """Generate LinkedIn summary for portfolio project"""
        return (
            f"📊 {project['title']}\n"
            f"Developed a comprehensive analytics project demonstrating expertise in "
            f"{', '.join(project['skills_demonstrated'][:2])}. "
            f"The project showcases my ability to handle real-world data challenges "
            f"and deliver actionable insights. "
            f"[GitHub Link] #DataScience #MachineLearning #Analytics"
        )

    def _suggest_repo_name(self, project: Dict) -> str:
        """Suggest a professional GitHub repository name"""
        titles = {
            1: "ml-pipeline-project",
            2: "business-analytics-project",
        }
        return titles.get(project["project_number"], "capstone-project")

    def _suggest_emojis(self, project: Dict) -> List[str]:
        """Suggest emojis for GitHub README"""
        if project["project_number"] == 1:
            return ["🤖", "📊", "🔍", "✨", "🎯"]
        else:
            return ["📈", "💡", "📊", "🔬", "💼"]

    def log_capstone_summary(self):
        """Log summary of capstone projects"""
        logger.info("=" * 80)
        logger.info("CAPSTONE PROJECTS SUMMARY (Weeks 29-32)")
        logger.info("=" * 80)
        
        for project in self.projects:
            logger.info(f"\n📌 PROJECT {project['project_number']}: {project['title']}")
            logger.info(f"   Weeks: {project['weeks']}")
            logger.info(f"   Estimated Hours: {project['estimated_hours']}")
            logger.info(f"   Difficulty: {project['difficulty_level']}")
            logger.info(f"   Deliverables: {len(project['deliverables'])}")
            logger.info(f"   Key Skills: {', '.join(project['skills_demonstrated'][:3])}")
        
        logger.info("=" * 80)
