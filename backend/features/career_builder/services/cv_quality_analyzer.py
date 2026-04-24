"""
CV Quality Analyzer - Comprehensive CV validation and quality scoring
"""
import logging
from typing import Dict, List, Optional
from enum import Enum
from dataclasses import dataclass

logger = logging.getLogger(__name__)


class QualityLevel(str, Enum):
    EXCELLENT = "excellent"
    GOOD = "good"
    FAIR = "fair"
    POOR = "poor"


@dataclass
class CVQualityReport:
    quality_score: float  # 0-100
    quality_level: QualityLevel
    issues: List[str]
    recommendations: List[str]
    parsability: QualityLevel
    skill_count: int
    experience_count: int
    certification_count: int


class CVQualityAnalyzer:
    """Analyze and validate CV quality for career guidance"""
    
    # Quality thresholds
    THRESHOLDS = {
        "excellent": 85,
        "good": 70,
        "fair": 50,
        "poor": 0
    }
    
    MIN_SKILLS = 1
    MAX_SKILLS = 50
    MIN_EXPERIENCE = 0
    IDEAL_EXPERIENCE = 2
    
    def __init__(self):
        self.logger = logger
    
    async def analyze_cv(self, cv_data: Dict) -> CVQualityReport:
        """
        Comprehensive CV quality analysis
        
        Args:
            cv_data: CV analysis data with skills, experience, etc.
        
        Returns:
            CVQualityReport with detailed assessment
        """
        issues = []
        recommendations = []
        score = 100
        
        # Extract CV components
        skills = cv_data.get("skills", [])
        experience = cv_data.get("experience", [])
        certifications = cv_data.get("certifications", [])
        parsed_content = cv_data.get("parsed_content", "")
        
        # Check 1: Skill count validation
        if len(skills) < self.MIN_SKILLS:
            issues.append("⚠️ No skills detected - Manual skill entry recommended")
            score -= 30
            recommendations.append("Add skills manually or update CV content")
        elif len(skills) > self.MAX_SKILLS:
            issues.append(f"⚠️ Too many skills ({len(skills)}) - May indicate parsing issues")
            score -= 10
            recommendations.append("Review duplicate or irrelevant skills")
        
        # Check 2: Experience validation
        if len(experience) < self.MIN_EXPERIENCE:
            issues.append("ℹ️ No experience found - Suitable for entry-level roles")
            score -= 15
            recommendations.append("Add work experience when available")
        elif len(experience) < self.IDEAL_EXPERIENCE:
            recommendations.append("Add more work experience for better guidance")
        
        # Check 3: Certification validation
        if len(certifications) == 0 and len(experience) > 0:
            recommendations.append("Consider adding relevant certifications")
        
        # Check 4: Content quality
        if len(parsed_content) < 100:
            issues.append("⚠️ CV content is very short")
            score -= 20
            recommendations.append("Expand CV content with more details")
        elif len(parsed_content) > 50000:
            issues.append("⚠️ CV content is very long (may be parsing error)")
            score -= 15
            recommendations.append("Trim CV or check parsing integrity")
        
        # Check 5: Skill confidence scoring
        low_confidence_skills = self._check_skill_confidence(skills)
        if low_confidence_skills:
            issues.append(f"⚠️ {len(low_confidence_skills)} skills with low confidence")
            score -= 5 * len(low_confidence_skills)
            recommendations.append("Review and confirm low-confidence skills")
        
        # Check 6: Skill diversity
        skill_categories = self._analyze_skill_diversity(skills)
        if len(skill_categories) < 2 and len(skills) > 3:
            recommendations.append("Consider adding skills from different categories for broader appeal")
        
        # Check 7: Duplicate or similar skills
        duplicates = self._find_duplicate_skills(skills)
        if duplicates:
            issues.append(f"⚠️ Found {len(duplicates)} duplicate/similar skills")
            score -= 5
            recommendations.append("Merge or remove duplicate skills")
        
        # Determine quality level
        quality_level = self._score_to_level(score)
        
        # Determine parsability
        parsability = self._assess_parsability(cv_data, issues)
        
        self.logger.info(
            f"CV Quality Analysis Complete - Score: {score}, Level: {quality_level.value}, "
            f"Skills: {len(skills)}, Experience: {len(experience)}"
        )
        
        return CVQualityReport(
            quality_score=max(0, min(100, score)),
            quality_level=quality_level,
            issues=issues,
            recommendations=recommendations,
            parsability=parsability,
            skill_count=len(skills),
            experience_count=len(experience),
            certification_count=len(certifications)
        )
    
    def _check_skill_confidence(self, skills: List[Dict]) -> List[str]:
        """Find skills with low confidence score"""
        low_confidence = []
        for skill in skills:
            confidence = skill.get("confidence", 0.8)
            if confidence < 0.5:
                low_confidence.append(skill.get("name", "unknown"))
        return low_confidence
    
    def _analyze_skill_diversity(self, skills: List[Dict]) -> set:
        """Categorize skills to check diversity"""
        categories = set()
        for skill in skills:
            category = skill.get("category", "other")
            if category:
                categories.add(category)
        return categories
    
    def _find_duplicate_skills(self, skills: List[Dict]) -> List[tuple]:
        """Find duplicate or very similar skills"""
        duplicates = []
        skill_names = [s.get("name", "").lower() for s in skills]
        
        seen = set()
        for name in skill_names:
            if name in seen:
                duplicates.append((name, name))
            seen.add(name)
        
        return duplicates
    
    def _score_to_level(self, score: float) -> QualityLevel:
        """Convert score to quality level"""
        if score >= self.THRESHOLDS["excellent"]:
            return QualityLevel.EXCELLENT
        elif score >= self.THRESHOLDS["good"]:
            return QualityLevel.GOOD
        elif score >= self.THRESHOLDS["fair"]:
            return QualityLevel.FAIR
        else:
            return QualityLevel.POOR
    
    def _assess_parsability(self, cv_data: Dict, issues: List[str]) -> QualityLevel:
        """Assess how well CV was parsed"""
        if len(issues) == 0:
            return QualityLevel.EXCELLENT
        elif len(issues) <= 2:
            return QualityLevel.GOOD
        elif len(issues) <= 4:
            return QualityLevel.FAIR
        else:
            return QualityLevel.POOR
    
    def get_quality_suggestions(self, report: CVQualityReport) -> Dict[str, any]:
        """Generate actionable suggestions based on quality report"""
        return {
            "overall_assessment": f"Your CV quality is {report.quality_level.value} "
                                 f"(Score: {report.quality_score:.0f}/100)",
            "strengths": self._identify_strengths(report),
            "areas_for_improvement": report.issues,
            "next_steps": report.recommendations,
            "priority_actions": self._prioritize_actions(report.issues),
            "estimated_impact": self._estimate_impact(report)
        }
    
    def _identify_strengths(self, report: CVQualityReport) -> List[str]:
        """Identify what's good about the CV"""
        strengths = []
        if report.skill_count >= 3:
            strengths.append(f"✅ Good skill coverage ({report.skill_count} skills)")
        if report.experience_count > 0:
            strengths.append(f"✅ Work experience documented ({report.experience_count} positions)")
        if report.certification_count > 0:
            strengths.append(f"✅ Certifications included ({report.certification_count})")
        if len(report.issues) == 0:
            strengths.append("✅ CV is well-structured with no major issues")
        return strengths
    
    def _prioritize_actions(self, issues: List[str]) -> List[str]:
        """Prioritize which issues to fix first"""
        if not issues:
            return []
        
        # Critical issues first
        critical = [i for i in issues if "No skills" in i or "No experience" in i]
        medium = [i for i in issues if "low confidence" in i or "duplicate" in i]
        low = [i for i in issues if i not in critical and i not in medium]
        
        return critical + medium + low
    
    def _estimate_impact(self, report: CVQualityReport) -> Dict[str, any]:
        """Estimate impact of improvements"""
        return {
            "if_issues_fixed": {
                "potential_score_increase": 10 * len(report.issues),
                "new_estimated_level": self._score_to_level(
                    min(100, report.quality_score + 10 * len(report.issues))
                ).value
            },
            "current_positioning": {
                "percentile": self._estimate_percentile(report.quality_score),
                "recommendation": self._get_recommendation(report.quality_level)
            }
        }
    
    def _estimate_percentile(self, score: float) -> str:
        """Estimate percentile ranking"""
        if score >= 90:
            return "Top 10%"
        elif score >= 75:
            return "Top 25%"
        elif score >= 60:
            return "Top 50%"
        else:
            return "Below average"
    
    def _get_recommendation(self, quality_level: QualityLevel) -> str:
        """Get recommendation based on quality level"""
        recommendations = {
            QualityLevel.EXCELLENT: "Ready for advanced career planning and opportunities",
            QualityLevel.GOOD: "Suitable for most career guidance, minor improvements recommended",
            QualityLevel.FAIR: "Recommended to improve before using for career planning",
            QualityLevel.POOR: "Strongly recommend improving CV quality before proceeding"
        }
        return recommendations.get(quality_level, "")
