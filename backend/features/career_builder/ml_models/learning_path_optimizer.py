"""
Learning Path Optimizer
Orders skills based on dependencies and prerequisites
Ensures logical learning progression
"""
from typing import List, Dict, Set, Optional
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class SkillNode:
    """Represents a skill in the learning path"""
    skill_id: int
    skill_name: str
    category: str
    importance_weight: int
    required_weeks: int
    gap_score: float
    prerequisites: List[str]  # Skill names that must be learned first


# =====================================================
# SKILL DEPENDENCY RULES
# =====================================================

SKILL_DEPENDENCIES = {
    # DevOps & Cloud
    "kubernetes": ["docker", "linux"],
    "helm": ["kubernetes"],
    "docker swarm": ["docker"],
    "docker compose": ["docker"],
    
    # CI/CD
    "ci/cd": ["git", "docker"],
    "jenkins": ["git"],
    "gitlab ci": ["git"],
    "github actions": ["git"],
    "terraform": ["cloud"],
    
    # Backend
    "microservices": ["api design", "docker"],
    "graphql": ["api design"],
    "grpc": ["api design"],
    
    # Database
    "database optimization": ["sql"],
    "database sharding": ["sql"],
    "nosql": ["database fundamentals"],
    
    # Frontend
    "next.js": ["react"],
    "nuxt.js": ["vue"],
    "redux": ["react"],
    "vuex": ["vue"],
    
    # Testing
    "integration testing": ["unit testing"],
    "e2e testing": ["unit testing"],
    "performance testing": ["testing fundamentals"],
    
    # Security
    "oauth": ["authentication"],
    "jwt": ["authentication"],
    "encryption": ["security fundamentals"],
    
    # Architecture
    "system design": ["api design", "database design"],
    "scalability": ["system design"],
    "load balancing": ["networking"],
    
    # Data Science
    "deep learning": ["machine learning", "python"],
    "tensorflow": ["machine learning"],
    "pytorch": ["machine learning"],
    "spark": ["python", "sql"],
}

# Category-level dependencies
CATEGORY_DEPENDENCIES = {
    "DevOps & Cloud": ["Programming Language", "Version Control"],
    "Architecture & Design": ["Programming Language", "Database"],
    "Testing & QA": ["Programming Language"],
}


# =====================================================
# LEARNING PATH OPTIMIZER
# =====================================================

class LearningPathOptimizer:
    """
    Optimizes learning path by ordering skills based on:
    1. Dependencies (prerequisites)
    2. Importance
    3. Difficulty (gap score)
    4. Foundational vs Advanced
    """
    
    def __init__(self):
        self.dependencies = SKILL_DEPENDENCIES
        self.category_deps = CATEGORY_DEPENDENCIES
    
    def optimize_learning_path(
        self,
        selected_skills: List[Dict],
        user_current_skills: Optional[List[str]] = None
    ) -> List[Dict]:
        """
        Optimize learning path for selected skills
        
        Args:
            selected_skills: Skills user wants to learn
            user_current_skills: Skills user already has (optional)
        
        Returns:
            Ordered list of skills with week assignments
        """
        if not selected_skills:
            return []
        
        logger.info(f"Optimizing learning path for {len(selected_skills)} skills...")
        
        # Filter out skills user already knows
        user_skills_set = set((user_current_skills or []))
        skills_to_learn = [
            s for s in selected_skills
            if s['skill_name'].lower() not in user_skills_set
        ]
        
        # Build dependency graph
        graph = self._build_dependency_graph(skills_to_learn)
        
        # Topological sort (dependency order)
        ordered_skills = self._topological_sort(graph, skills_to_learn)
        
        # Add week assignments
        learning_path = self._assign_weeks(ordered_skills)
        
        # Add difficulty levels
        learning_path = self._assign_difficulty_levels(learning_path)
        
        logger.info(f"Optimized path created with {len(learning_path)} steps")
        
        return learning_path
    
    def _build_dependency_graph(
        self,
        skills: List[Dict]
    ) -> Dict[str, List[str]]:
        """
        Build dependency graph for skills
        
        Returns:
            {skill_name: [prerequisite1, prerequisite2, ...]}
        """
        graph = {}
        skill_names = {s['skill_name'].lower() for s in skills}
        
        for skill in skills:
            skill_name = skill['skill_name'].lower()
            prerequisites = []
            
            # Check direct dependencies
            for dep_skill, deps in self.dependencies.items():
                if dep_skill in skill_name or skill_name in dep_skill:
                    for dep in deps:
                        # Only add if prerequisite is in selected skills
                        if any(dep in s['skill_name'].lower() for s in skills):
                            prerequisites.append(dep)
            
            # Check category dependencies
            category = skill.get('category', '')
            if category in self.category_deps:
                for required_cat in self.category_deps[category]:
                    # Check if any skill from required category is selected
                    for s in skills:
                        if s.get('category') == required_cat:
                            prereq = s['skill_name'].lower()
                            if prereq != skill_name:
                                prerequisites.append(prereq)
                            break
            
            graph[skill_name] = list(set(prerequisites))  # Remove duplicates
        
        return graph
    
    def _topological_sort(
        self,
        graph: Dict[str, List[str]],
        skills: List[Dict]
    ) -> List[Dict]:
        """
        Topological sort to ensure dependencies are learned first
        """
        # Create skill lookup
        skill_map = {s['skill_name'].lower(): s for s in skills}
        
        # Calculate in-degree for each node
        in_degree = {skill: 0 for skill in graph}
        for skill, deps in graph.items():
            for dep in deps:
                if dep in in_degree:
                    in_degree[skill] += 1
        
        # Queue for skills with no prerequisites
        queue = [
            skill for skill, degree in in_degree.items()
            if degree == 0
        ]
        
        # Sort queue by importance
        queue.sort(
            key=lambda s: skill_map[s].get('importance_weight', 0),
            reverse=True
        )
        
        ordered = []
        
        while queue:
            # Take highest priority skill
            current = queue.pop(0)
            ordered.append(skill_map[current])
            
            # Update neighbors
            for skill, deps in graph.items():
                if current in deps:
                    in_degree[skill] -= 1
                    if in_degree[skill] == 0:
                        queue.append(skill)
                        # Re-sort by importance
                        queue.sort(
                            key=lambda s: skill_map[s].get('importance_weight', 0),
                            reverse=True
                        )
        
        # Handle any remaining skills (circular dependencies - shouldn't happen)
        remaining = set(skill_map.keys()) - {s['skill_name'].lower() for s in ordered}
        for skill_name in remaining:
            ordered.append(skill_map[skill_name])
        
        return ordered
    
    def _assign_weeks(self, ordered_skills: List[Dict]) -> List[Dict]:
        """Assign week numbers to each skill"""
        current_week = 1
        learning_path = []
        
        for i, skill in enumerate(ordered_skills):
            weeks_needed = skill.get('required_weeks', 4)
            
            learning_path.append({
                **skill,
                'order': i + 1,
                'start_week': current_week,
                'end_week': current_week + weeks_needed - 1,
                'duration_weeks': weeks_needed
            })
            
            current_week += weeks_needed
        
        return learning_path
    
    def _assign_difficulty_levels(self, learning_path: List[Dict]) -> List[Dict]:
        """Assign difficulty progression labels"""
        total_skills = len(learning_path)
        
        for i, skill in enumerate(learning_path):
            # Early skills = Foundation
            if i < total_skills * 0.3:
                difficulty = "Foundation"
                emoji = "🟢"
            # Middle skills = Intermediate
            elif i < total_skills * 0.7:
                difficulty = "Intermediate"
                emoji = "🟡"
            # Late skills = Advanced
            else:
                difficulty = "Advanced"
                emoji = "🔴"
            
            skill['difficulty_level'] = difficulty
            skill['difficulty_emoji'] = emoji
        
        return learning_path
    
    def validate_path(self, learning_path: List[Dict]) -> Dict:
        """
        Validate that the learning path makes sense
        
        Returns validation report
        """
        issues = []
        
        learned_so_far = set()
        
        for step in learning_path:
            skill_name = step['skill_name'].lower()
            
            # Check if prerequisites are met
            skill_deps = self.dependencies.get(skill_name, [])
            for dep in skill_deps:
                if dep not in learned_so_far:
                    issues.append({
                        'skill': skill_name,
                        'issue': f"Missing prerequisite: {dep}",
                        'severity': 'warning'
                    })
            
            learned_so_far.add(skill_name)
        
        return {
            'is_valid': len(issues) == 0,
            'total_weeks': learning_path[-1]['end_week'] if learning_path else 0,
            'issues': issues
        }
    
    def generate_visual_timeline(self, learning_path: List[Dict]) -> str:
        """
        Generate ASCII visual timeline of learning path
        """
        timeline = []
        timeline.append("=" * 60)
        timeline.append("📚 YOUR LEARNING PATH")
        timeline.append("=" * 60)
        timeline.append("")
        
        for skill in learning_path:
            order = skill['order']
            name = skill['skill_name']
            weeks_range = f"Week {skill['start_week']}-{skill['end_week']}"
            difficulty = f"{skill['difficulty_emoji']} {skill['difficulty_level']}"
            
            timeline.append(f"{order}. {name}")
            timeline.append(f"   ⏱  {weeks_range} ({skill['duration_weeks']} weeks)")
            timeline.append(f"   📊 {difficulty}")
            timeline.append("")
        
        timeline.append("=" * 60)
        timeline.append(f"Total Duration: {learning_path[-1]['end_week']} weeks")
        timeline.append("=" * 60)
        
        return "\n".join(timeline)


def get_skill_prerequisites(skill_name: str) -> List[str]:
    """
    Get prerequisites for a specific skill
    
    Public helper function for frontend
    """
    skill_lower = skill_name.lower()
    
    for dep_skill, deps in SKILL_DEPENDENCIES.items():
        if dep_skill in skill_lower or skill_lower in dep_skill:
            return deps
    
    return []
