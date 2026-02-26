"""
Backend 1 - Analysis Service (Updated)
Uses existing DocumentParser + LLM integration
Complete implementation following the required phases
"""
from typing import Dict, List, Any, Optional
from uuid import UUID
from dataclasses import dataclass
import logging
import json

from shared.helpers.document_parser import DocumentParser
from features.career_builder.ml_models.skill_extractor import SkillExtractor
from features.career_builder.ml_models.skill_matcher import SkillMatcher
from features.career_builder.ml_models.level_detector import LevelDetector
from features.career_builder.ml_models.gap_analyzer import SkillGapAnalyzer
from features.career_builder.ml_models.realism_checker import RealismChecker
from features.career_builder.repositories.career_repository import CareerRepository

logger = logging.getLogger(__name__)


@dataclass
class AnalysisResult:
    """Complete Backend 1 output"""
    cv_id: UUID
    track_id: int
    track_name: str
    
    # PHASE 1: Skill Extraction
    extracted_skills: List[str]
    normalized_skills: List[str]
    extraction_confidence: float
    
    # PHASE 2: Level Detection
    detected_level: str
    level_confidence: float
    level_reasoning: str
    
    # PHASE 3: Skill Gaps
    skill_gaps: List[Dict[str, Any]]
    missing_skills_count: int
    
    # PHASE 4: Realism
    min_weeks_required: int
    suggested_min_weeks: int
    realism_flag: bool
    realism_info: Dict[str, Any]
    
    # Overall quality
    analysis_quality: float


class CareerAnalysisService:
    """
    Backend 1 - Complete Analysis Service
    
    Implements all 5 phases as specified:
    1. ✅ CV → Skill Extraction
    2. ✅ Level Detection (Hybrid)
    3. ✅ Skill Gap Engine
    4. ✅ Time Realism Engine
    5. ✅ Output Contract
    """
    
    def __init__(self, repository: CareerRepository):
        self.repo = repository
        self.doc_parser = DocumentParser()  # Uses existing shared parser
        self.skill_extractor = SkillExtractor()  # LLM-based
        self.level_detector = LevelDetector()  # LLM + Rules
        self.skill_matcher = SkillMatcher()  # Smart matching
        self.gap_analyzer = SkillGapAnalyzer()  # Gap scoring
        self.realism_checker = RealismChecker()  # Duration validation
    
    async def analyze_cv_for_track(
        self,
        cv_id: UUID,
        track_id: int
    ) -> AnalysisResult:
        """
        🎯 COMPLETE ANALYSIS PIPELINE
        
        Phases:
        1. Get CV from database
        2. ✅ PHASE 1: Extract & normalize skills
        3. ✅ PHASE 2: Detect level (LLM + rules)
        4. ✅ PHASE 3: Calculate skill gaps
        5. ✅ PHASE 4: Check time realism
        6. ✅ PHASE 5: Return standardized output
        """
        logger.info(f"🎯 Starting analysis: cv_id={cv_id}, track_id={track_id}")
        
        # =====================================================
        # STEP 1: Get CV and Track data
        # =====================================================
        cv_data = await self.repo.get_cv_by_id(cv_id)
        if not cv_data:
            raise ValueError(f"CV not found: {cv_id}")
        
        track_data = await self.repo.get_track_by_id(track_id)
        if not track_data:
            raise ValueError(f"Track not found: {track_id}")
        
        # =====================================================
        # PHASE 1: CV → Skill Extraction
        # =====================================================
        logger.info("📋 PHASE 1: Extracting skills from CV...")
        
        # Get text and parsed content
        cv_text = cv_data.get('text_content', '')
        parsed_content = cv_data.get('parsed_content', {})
        
        # If parsed_content is string, parse it
        if isinstance(parsed_content, str):
            try:
                parsed_content = json.loads(parsed_content)
            except:
                parsed_content = {}
        
        # Extract skills using LLM + validation
        skill_extraction_result = self.skill_extractor.extract_skills_from_cv(
            cv_text=cv_text,
            parsed_cv_data=parsed_content
        )
        
        extracted_skills = skill_extraction_result['extracted_skills']
        normalized_skills = skill_extraction_result['normalized_skills']
        extraction_confidence = skill_extraction_result['extraction_confidence']
        
        logger.info(
            f"✅ Extracted {len(normalized_skills)} skills "
            f"(confidence: {extraction_confidence:.2f})"
        )
        
        # =====================================================
        # Get all database skills for matching
        # =====================================================
        all_db_skills = await self._get_all_db_skills()
        
        # Match extracted skills to database
        matched_skills = self.skill_matcher.match_skills(
            cv_skills=normalized_skills,
            db_skills=all_db_skills,
            threshold=0.65
        )
        
        logger.info(f"🔗 Matched {len(matched_skills)} skills to database")
        
        # =====================================================
        # Get track skills
        # =====================================================
        track_skills_all = await self.repo.get_skills_by_track(track_id, 'beginner')
        required_skill_names = [s['skill_name'] for s in track_skills_all]
        
        # =====================================================
        # PHASE 2: Level Detection (Hybrid) using LevelDetector
        # =====================================================
        logger.info("🎓 PHASE 2: Detecting user level...")
        
        # Use the async detect_skill_levels method
        level_result = await self.level_detector.detect_skill_levels(
            cv_text=cv_text,
            parsed_cv_data=parsed_content,
            required_skills=required_skill_names
        )
        
        # Extract overall level from result
        detected_level = level_result.get('overall_level', 'beginner')
        level_confidence = level_result.get('overall_confidence', 0.5)
        level_reasoning = level_result.get('summary', '')
        
        logger.info(
            f"✅ Level: {detected_level} "
            f"(confidence: {level_confidence:.2f})"
        )
        
        # Get track skills for detected level
        track_skills_for_level = await self.repo.get_skills_by_track(
            track_id,
            detected_level
        )
        
        # =====================================================
        # PHASE 3: Skill Gap Engine
        # =====================================================
        logger.info("📊 PHASE 3: Calculating skill gaps...")
        
        skill_gaps = await self._calculate_skill_gaps(
            matched_skills=matched_skills,
            track_skills=track_skills_for_level,
            required_level=detected_level
        )
        
        missing_count = sum(
            1 for gap in skill_gaps 
            if gap['status'] == 'missing'
        )
        
        logger.info(
            f"✅ Gap analysis: {missing_count}/{len(track_skills_for_level)} "
            f"skills missing"
        )
        
        # =====================================================
        # PHASE 4: Time Realism Engine
        # =====================================================
        logger.info("⏱️  PHASE 4: Calculating time realism...")
        
        # Calculate minimum weeks
        min_weeks = await self.repo.calculate_min_weeks(track_id, detected_level)
        
        # Calculate adjusted weeks based on gaps
        total_learning_weight = sum(
            gap['importance_weight'] * gap['gap_score']
            for gap in skill_gaps
        )
        
        # Smart formula: base time + gap-based adjustment
        estimated_weeks = int(min_weeks * 0.7 + total_learning_weight * 1.5)
        
        # Check realism
        realism_info = self.realism_checker.check_realism(
            track_id=track_id,
            level=detected_level,
            requested_weeks=estimated_weeks,
            min_weeks=min_weeks
        )
        
        realism_flag = not realism_info['is_realistic']
        suggested_min_weeks = realism_info['suggested_min_weeks']
        
        logger.info(
            f"✅ Time estimate: {estimated_weeks} weeks "
            f"(min: {min_weeks}, suggested: {suggested_min_weeks})"
        )
        
        # =====================================================
        # Calculate overall analysis quality
        # =====================================================
        match_rate = len(matched_skills) / max(len(normalized_skills), 1)
        analysis_quality = self._calculate_overall_quality(
            extraction_confidence=extraction_confidence,
            level_confidence=level_confidence,
            match_rate=match_rate
        )
        
        logger.info(f"✅ Analysis complete (quality: {analysis_quality:.2f})")
        
        # =====================================================
        # PHASE 5: Return standardized output
        # =====================================================
        return AnalysisResult(
            cv_id=cv_id,
            track_id=track_id,
            track_name=track_data['track_name'],
            
            # Phase 1
            extracted_skills=list(extracted_skills),
            normalized_skills=list(normalized_skills),
            extraction_confidence=extraction_confidence,
            
            # Phase 2
            detected_level=detected_level,
            level_confidence=level_confidence,
            level_reasoning=level_reasoning,
            
            # Phase 3
            skill_gaps=skill_gaps,
            missing_skills_count=missing_count,
            
            # Phase 4
            min_weeks_required=min_weeks,
            suggested_min_weeks=suggested_min_weeks,
            realism_flag=realism_flag,
            realism_info=realism_info,
            
            # Quality
            analysis_quality=analysis_quality
        )
    
    async def _get_all_db_skills(self) -> List[Dict[str, Any]]:
        """Get all skills from database"""
        return await self.repo.search_skills_by_name('')
    
    async def _calculate_skill_gaps(
        self,
        matched_skills: List,
        track_skills: List[Dict[str, Any]],
        required_level: str
    ) -> List[Dict[str, Any]]:
        """
        PHASE 3: Calculate detailed skill gaps
        
        For each track skill:
        - Check if user has it
        - Calculate gap score (importance × level difference)
        - Add metadata
        """
        # Build user skill map
        user_skill_map = {
            match.db_skill_id: match 
            for match in matched_skills
        }
        
        gaps = []
        
        for track_skill in track_skills:
            skill_id = track_skill['skill_id']
            skill_name = track_skill['skill_name']
            importance = track_skill.get('importance', 3)
            
            # Check if user has this skill
            user_match = user_skill_map.get(skill_id)
            
            if user_match:
                # User has skill - estimate current level from match confidence
                if user_match.confidence >= 0.9:
                    current_level = 'intermediate' if required_level == 'advanced' else 'beginner'
                else:
                    current_level = 'beginner'
                
                status = 'has'
            else:
                # User missing this skill
                current_level = 'none'
                status = 'missing'
            
            # Calculate gap score
            gap_score = self.gap_analyzer.calculate_gap_score(
                current_level=current_level,
                required_level=required_level
            )
            
            # Boost gap score by importance
            weighted_gap_score = gap_score * (importance / 5.0)
            
            gaps.append({
                'skill_id': skill_id,
                'skill_name': skill_name,
                'category': track_skill.get('category', 'General'),
                'status': status,
                'current_level': current_level,
                'required_level': required_level,
                'gap_score': gap_score,
                'weighted_gap_score': weighted_gap_score,
                'importance_weight': importance,
                'required_weeks': track_skill.get('duration_weeks', 4),
                'match_confidence': user_match.confidence if user_match else 0.0
            })
        
        # Sort by weighted gap score (priority)
        gaps.sort(
            key=lambda x: (x['weighted_gap_score'], -x['importance_weight']),
            reverse=True
        )
        
        return gaps
    
    def _calculate_overall_quality(
        self,
        extraction_confidence: float,
        level_confidence: float,
        match_rate: float
    ) -> float:
        """Calculate overall analysis quality score"""
        quality = (
            extraction_confidence * 0.3 +
            level_confidence * 0.4 +
            match_rate * 0.3
        )
        return min(quality, 0.95)
    
    def to_output_contract(self, result: AnalysisResult) -> Dict[str, Any]:
        """
        PHASE 5: Convert to standardized output contract
        
        This is the exact format Backend 2 expects
        """
        return {
            "detected_level": result.detected_level,
            "level_confidence": round(result.level_confidence, 3),
            "realism_flag": result.realism_flag,
            "suggested_min_weeks": result.suggested_min_weeks,
            "min_weeks_required": result.min_weeks_required,
            "skills": [
                {
                    "skill_id": gap['skill_id'],
                    "skill_name": gap['skill_name'],
                    "category": gap['category'],
                    "status": gap['status'],
                    "current_level": gap['current_level'],
                    "required_level": gap['required_level'],
                    "gap_score": round(gap['gap_score'], 3),
                    "importance_weight": gap['importance_weight'],
                    "required_weeks": gap['required_weeks']
                }
                for gap in result.skill_gaps
            ],
            "metadata": {
                "extracted_skills_count": len(result.normalized_skills),
                "extraction_confidence": round(result.extraction_confidence, 3),
                "analysis_quality": round(result.analysis_quality, 3),
                "level_reasoning": result.level_reasoning
            }
        }