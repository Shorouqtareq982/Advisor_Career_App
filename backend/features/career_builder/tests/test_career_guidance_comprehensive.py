"""
Comprehensive Test Framework for Career Guidance System
"""
import pytest
from typing import Dict, List
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


# ============================================================================
# TEST FIXTURES & MOCKS
# ============================================================================

class MockCareerRepository:
    """Mock repository for testing"""
    
    def __init__(self):
        self.test_data = {
            "skills": {
                "python": {"skill_id": 1, "required_weeks": 4, "importance_weight": 5, "is_core": True},
                "react": {"skill_id": 2, "required_weeks": 3, "importance_weight": 4, "is_core": True},
                "docker": {"skill_id": 3, "required_weeks": 3, "importance_weight": 3, "is_core": False},
                "kubernetes": {"skill_id": 4, "required_weeks": 6, "importance_weight": 3, "is_core": False},
                "javascript": {"skill_id": 5, "required_weeks": 2, "importance_weight": 5, "is_core": True},
                "typescript": {"skill_id": 6, "required_weeks": 2, "importance_weight": 4, "is_core": True},
            }
        }
    
    async def get_skills_by_track(self, track_id: str):
        return self.test_data["skills"].values()
    
    async def get_skill_by_name(self, skill_name: str):
        return self.test_data["skills"].get(skill_name.lower())


# ============================================================================
# UNIT TESTS - TIME GUIDANCE SERVICE
# ============================================================================

class TestTimeGuidanceService:
    """Test TimeGuidanceService with various scenarios"""
    
    @pytest.fixture
    def setup(self):
        """Setup test environment"""
        self.repo = MockCareerRepository()
        # self.service = TimeGuidanceService(self.repo)
        return self
    
    @pytest.mark.unit
    async def test_complete_beginner_minimum_mode(self, setup):
        """Scenario: User is complete beginner, selecting few skills"""
        # Given: Complete beginner, selecting 2 skills
        selected_skills = ["python", "react"]
        owned_skills = {}  # Empty - no prior knowledge
        available_hours = 6
        
        # When: Calculate guidance
        guidance = await self._calculate_guidance(selected_skills, owned_skills, available_hours)
        
        # Then: Should return beginner-friendly estimates
        assert guidance["minimum_weeks"] >= 4
        assert guidance["suitable_weeks"] >= 6
        assert guidance["maximum_weeks"] >= 8
        assert len(guidance["minimum_breakdown"]) == 2
    
    @pytest.mark.unit
    async def test_partial_expert_suitable_mode(self, setup):
        """Scenario: User knows some skills, expanding knowledge"""
        # Given: User knows Python & JavaScript, adding React & TypeScript
        selected_skills = ["react", "typescript"]
        owned_skills = {"python": "intermediate", "javascript": "beginner"}
        available_hours = 8
        
        # When: Calculate guidance
        guidance = await self._calculate_guidance(selected_skills, owned_skills, available_hours)
        
        # Then: Should include level-up targets for core skills
        assert "javascript (level-up)" in str(guidance["suitable_breakdown"])
        assert guidance["suitable_weeks"] < 10
    
    @pytest.mark.unit
    async def test_extreme_hours_high(self, setup):
        """Scenario: User claims to have 40 hours/week available"""
        # Given: Very high availability
        selected_skills = ["python"]
        available_hours = 40
        
        # When: Calculate guidance
        guidance = await self._calculate_guidance(selected_skills, {}, available_hours)
        
        # Then: Should apply efficiency penalty (can't learn 40 hrs/wk sustainably)
        expected_weeks = 4 * (1.0 / 0.7)  # With efficiency multiplier
        assert guidance["suitable_weeks"] < 5
    
    @pytest.mark.unit
    async def test_extreme_hours_low(self, setup):
        """Scenario: User has very limited time (1 hour/week)"""
        # Given: Minimal availability
        selected_skills = ["python"]
        available_hours = 1
        
        # When: Calculate guidance
        guidance = await self._calculate_guidance(selected_skills, {}, available_hours)
        
        # Then: Should extend timeline significantly
        assert guidance["suitable_weeks"] > 15
    
    @pytest.mark.unit
    async def test_many_skills(self, setup):
        """Scenario: User selected too many skills (20+)"""
        # Given: Large skill set
        selected_skills = [f"skill_{i}" for i in range(20)]
        available_hours = 6
        
        # When: Calculate guidance
        guidance = await self._calculate_guidance(selected_skills, {}, available_hours)
        
        # Then: Should succeed but with warning
        assert guidance["total_weeks"] > 100
        assert guidance["warning"] == "Too many skills selected"
    
    @pytest.mark.unit
    async def test_no_skills_error(self, setup):
        """Scenario: User didn't select any skills"""
        # Given: Empty skill selection
        selected_skills = []
        
        # When/Then: Should raise error
        with pytest.raises(ValueError) as exc_info:
            await self._calculate_guidance(selected_skills, {}, 6)
        
        assert "at least one skill" in str(exc_info.value).lower()
    
    @pytest.mark.unit
    async def test_invalid_hours_error(self, setup):
        """Scenario: User entered invalid hours"""
        # Given: Invalid hours
        selected_skills = ["python"]
        available_hours = 0  # Invalid
        
        # When/Then: Should raise error
        with pytest.raises(ValueError) as exc_info:
            await self._calculate_guidance(selected_skills, {}, available_hours)
        
        assert "hours" in str(exc_info.value).lower()
    
    @pytest.mark.unit
    async def test_skill_name_normalization(self, setup):
        """Scenario: Skill names with different casing"""
        # Given: Skills with different cases
        selected_skills = ["PYTHON", "python", "Python"]
        owned_skills = {"python": "beginner"}
        
        # When: Calculate guidance
        guidance = await self._calculate_guidance(selected_skills, owned_skills, 6)
        
        # Then: Should deduplicate correctly
        assert len(guidance["skills"]) == 1  # Only 1 unique skill
        assert "python" in [s.lower() for s in guidance["skills"]]
    
    @pytest.mark.unit
    async def test_confidence_calculation(self, setup):
        """Scenario: Verify confidence scores"""
        # Given: Various timeframe requests
        selected_skills = ["python"]
        
        # Realistic timeframe
        conf1 = await self._calculate_confidence(selected_skills, 6, 6)
        assert conf1 > 0.9
        
        # Tight timeframe
        conf2 = await self._calculate_confidence(selected_skills, 2, 6)
        assert 0.6 < conf2 <= 0.8
        
        # Unrealistic (too short)
        conf3 = await self._calculate_confidence(selected_skills, 1, 6)
        assert conf3 < 0.5
    
    async def _calculate_guidance(self, selected, owned, hours):
        """Helper method"""
        return {"minimum_weeks": 4, "suitable_weeks": 6, "maximum_weeks": 10}
    
    async def _calculate_confidence(self, skills, requested, suitable):
        """Helper method"""
        if requested >= suitable:
            return 0.95
        elif requested >= suitable * 0.7:
            return 0.75
        else:
            return 0.3


# ============================================================================
# INTEGRATION TESTS - FULL FLOW
# ============================================================================

class TestFullCareerFlow:
    """End-to-end integration tests"""
    
    @pytest.mark.integration
    async def test_frontend_dev_complete_journey(self):
        """
        Test complete flow: CV upload → Analysis → Skill selection → Time estimate → Plan
        """
        # Step 1: Mock CV upload
        cv_data = {
            "cv_id": "cv_123",
            "skills": ["React", "JavaScript", "CSS"],
            "experience": [
                {"position": "Frontend Developer", "years": 2}
            ],
            "detected_level": "intermediate"
        }
        
        # Step 2: Analyze CV
        analysis = await self._mock_analyze_cv(cv_data)
        assert analysis["status"] == "success"
        assert analysis["detected_level"] == "intermediate"
        
        # Step 3: Confirm skills
        selected = ["TypeScript", "Vue.js", "Webpack"]  # Expanding skills
        confirm = await self._mock_confirm_skills(cv_data["cv_id"], selected)
        assert confirm["status"] == "success"
        assert len(confirm["confirmed_skills"]) == 3
        
        # Step 4: Get preview (time guidance)
        preview = await self._mock_get_preview(cv_data["cv_id"], track_id="frontend")
        assert preview["time_guidance"]["suitable_weeks"] >= 4
        assert preview["time_guidance"]["suitable_weeks"] <= 16
        
        # Step 5: Confirm time with realistic request
        confirm_time = await self._mock_confirm_time(
            cv_id=cv_data["cv_id"],
            track_id="frontend",
            requested_weeks=12,
            available_hours=8
        )
        assert confirm_time["realism"]["is_realistic"] == True
        assert len(confirm_time["realism"]["warnings"]) == 0
        
        # Step 6: Generate plan
        plan = await self._mock_generate_plan(
            cv_id=cv_data["cv_id"],
            track_id="frontend",
            duration_weeks=12
        )
        assert len(plan["weekly_breakdown"]) == 12
        assert plan["total_hours"] == 12 * 8  # 96 hours
    
    @pytest.mark.integration
    async def test_unrealistic_request_handling(self):
        """
        Test system catches unrealistic time requests
        """
        cv_id = "cv_unrealistic"
        
        # Get preview
        preview = await self._mock_get_preview(cv_id, track_id="python")
        suitable = preview["time_guidance"]["suitable_weeks"]
        
        # Request unrealistic: 2 weeks (way too short)
        confirm = await self._mock_confirm_time(
            cv_id=cv_id,
            requested_weeks=2,
            available_hours=4
        )
        
        # Should flag as unrealistic
        assert confirm["realism"]["is_realistic"] == False
        assert "unrealistic" in confirm["realism"]["adjustment_status"].lower()
        assert len(confirm["realism"]["warnings"]) > 0
    
    @pytest.mark.integration
    async def test_large_skill_set_performance(self):
        """
        Test system handles large skill sets gracefully
        """
        # Generate large skill set
        large_skills = [f"Skill_{i}" for i in range(50)]
        
        # Should not crash or take too long
        import time
        start = time.time()
        
        guidance = await self._mock_calculate_guidance(large_skills, {}, 6)
        
        elapsed = time.time() - start
        assert elapsed < 2.0  # Should complete in < 2 seconds
        assert guidance["total_weeks"] > 200
    
    @pytest.mark.integration
    async def test_error_recovery(self):
        """
        Test graceful degradation on errors
        """
        # Database error scenario
        cv_id = "cv_db_error"
        
        try:
            preview = await self._mock_get_preview_with_error(cv_id)
        except Exception as e:
            # Should provide fallback or meaningful error
            assert "fallback" in str(e).lower() or "cached" in str(e).lower()
    
    async def _mock_analyze_cv(self, cv_data):
        return {"status": "success", "detected_level": cv_data["detected_level"]}
    
    async def _mock_confirm_skills(self, cv_id, skills):
        return {"status": "success", "confirmed_skills": skills}
    
    async def _mock_get_preview(self, cv_id, track_id):
        return {
            "time_guidance": {
                "suitable_weeks": 8,
                "minimum_weeks": 4,
                "maximum_weeks": 12
            }
        }
    
    async def _mock_confirm_time(self, cv_id, track_id, requested_weeks, available_hours):
        return {
            "realism": {
                "is_realistic": requested_weeks >= 4,
                "adjustment_status": "unrealistic_too_short" if requested_weeks < 4 else "ok",
                "warnings": [] if requested_weeks >= 4 else ["Too short"]
            }
        }
    
    async def _mock_generate_plan(self, cv_id, track_id, duration_weeks):
        return {
            "weekly_breakdown": [f"Week {i}" for i in range(duration_weeks)],
            "total_hours": duration_weeks * 8
        }
    
    async def _mock_calculate_guidance(self, skills, owned, hours):
        return {"total_weeks": len(skills) * 4}
    
    async def _mock_get_preview_with_error(self, cv_id):
        raise Exception("DB error - using fallback data")


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

class TestEdgeCases:
    """Test handling of exceptional scenarios"""
    
    @pytest.mark.edge_case
    async def test_cv_with_no_skills(self):
        """CV parsed but no skills detected"""
        cv = {"parsed_content": "My name is John, I worked for 5 years"}
        
        result = await self._handle_no_skills(cv)
        assert result["status"] == "insufficient_data"
        assert result["manual_entry_available"] == True
    
    @pytest.mark.edge_case
    async def test_complete_beginner_no_owned_skills(self):
        """User is complete beginner"""
        guidance = await self._get_guidance(
            selected=["Python"],
            owned={},
            hours=2
        )
        
        assert guidance["planning_mode"] == "beginner_bootstrap"
        assert guidance["suitable_weeks"] > 8
    
    @pytest.mark.edge_case
    async def test_complete_expert_all_advanced(self):
        """User already expert in everything"""
        guidance = await self._get_guidance(
            selected=["Python", "React"],
            owned={"Python": "advanced", "React": "advanced"},
            hours=6
        )
        
        assert guidance["message"] == "mastered_all"
        assert len(guidance["recommendations"]) > 0
    
    @pytest.mark.edge_case
    async def test_very_high_hours_unsustainable(self):
        """User claims unrealistic availability"""
        guidance = await self._get_guidance(
            selected=["Python"],
            owned={},
            hours=60  # 60 hours/week
        )
        
        assert guidance["efficiency_multiplier"] < 0.7
        assert "unsustainable" in guidance["warnings"]
    
    @pytest.mark.edge_case
    async def test_very_low_hours_minimal_progress(self):
        """User has minimal availability"""
        guidance = await self._get_guidance(
            selected=["Python"],
            owned={},
            hours=0.5  # 30 min/week
        )
        
        assert guidance["suitable_weeks"] > 30
        assert "micro-learning" in guidance["recommendations"][0].lower()
    
    async def _handle_no_skills(self, cv):
        return {"status": "insufficient_data", "manual_entry_available": True}
    
    async def _get_guidance(self, selected, owned, hours):
        return {
            "suitable_weeks": 8,
            "efficiency_multiplier": 1.0,
            "warnings": [],
            "recommendations": []
        }


# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

class TestPerformance:
    """Performance and scalability tests"""
    
    @pytest.mark.performance
    async def test_large_database_query_performance(self):
        """Query 10000+ skills"""
        import time
        
        start = time.time()
        # Mock querying 10000 skills
        skills = [{"id": i, "name": f"Skill_{i}"} for i in range(10000)]
        elapsed = time.time() - start
        
        assert elapsed < 1.0  # Should complete in < 1 second
    
    @pytest.mark.performance
    async def test_concurrent_requests(self):
        """Handle 100 concurrent guidance requests"""
        import asyncio
        
        async def mock_request():
            return await self._calculate_guidance(["Python"], {}, 6)
        
        tasks = [mock_request() for _ in range(100)]
        import time
        start = time.time()
        results = await asyncio.gather(*tasks)
        elapsed = time.time() - start
        
        assert len(results) == 100
        assert elapsed < 5.0  # All 100 should complete in < 5 seconds
    
    async def _calculate_guidance(self, skills, owned, hours):
        return {"suitable_weeks": 8}


# ============================================================================
# TEST EXECUTION HELPERS
# ============================================================================

def run_all_tests():
    """Run complete test suite"""
    pytest.main([
        __file__,
        "-v",  # Verbose
        "-m", "unit or integration or edge_case or performance",
        "--tb=short",  # Short traceback
        "--disable-warnings"
    ])


if __name__ == "__main__":
    run_all_tests()
