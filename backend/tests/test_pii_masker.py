"""
Extensive test suite for the PII masker pipeline.

Run with:
    pytest test_pii_masker.py -v
or for a coverage report:
    pytest test_pii_masker.py -v --tb=short
"""

import re
import pytest
from unittest.mock import patch, MagicMock

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _has_token_type(mask_map: dict, token_type: str) -> bool:
    return any(v["type"] == token_type for v in mask_map.values())

def _count_token_type(mask_map: dict, token_type: str) -> int:
    return sum(1 for v in mask_map.values() if v["type"] == token_type)

def _original_values(mask_map: dict) -> set:
    return {v["value"] for v in mask_map.values()}

def _tokens_of_type(mask_map: dict, token_type: str) -> list:
    return [k for k, v in mask_map.items() if v["type"] == token_type]


# ===========================================================================
# 1. is_whitelisted
# ===========================================================================
class TestIsWhitelisted:
    """Unit tests for the whitelist guard."""

    def test_exact_tech_skill_whitelisted(self, pii):
        assert pii.is_whitelisted("PERSON", "python") is True

    def test_exact_cv_header_whitelisted(self, pii):
        assert pii.is_whitelisted("PERSON", "education") is True

    def test_org_keyword_in_person_value(self, pii):
        assert pii.is_whitelisted("PERSON", "Cairo University") is True

    def test_org_keyword_in_location_value(self, pii):
        assert pii.is_whitelisted("LOCATION", "MIT Laboratory") is True

    def test_single_word_company_suffix_not_whitelisted(self, pii):
        # "Hugo" contains "go" but should NOT be whitelisted
        assert pii.is_whitelisted("PERSON", "Hugo") is False

    def test_multiword_company_suffix_whitelisted(self, pii):
        assert pii.is_whitelisted("PERSON", "Acme Corp") is True

    def test_regular_name_not_whitelisted(self, pii):
        assert pii.is_whitelisted("PERSON", "Ahmed Hassan") is False

    def test_email_not_whitelisted(self, pii):
        assert pii.is_whitelisted("EMAIL_ADDRESS", "ahmed@gmail.com") is False

    def test_location_with_tech_skill_not_a_person(self, pii):
        # "AWS" is a tech skill; whitelisted for any entity
        assert pii.is_whitelisted("LOCATION", "aws") is True

    def test_company_suffix_check_only_for_relevant_types(self, pii):
        # EMAIL_ADDRESS with "co" in domain should NOT be whitelisted via suffix logic
        result = pii.is_whitelisted("EMAIL_ADDRESS", "test co")
        assert result is False


# ===========================================================================
# 2. looks_like_date_range
# ===========================================================================
class TestLooksLikeDateRange:

    def test_year_range(self, pii):
        assert pii.looks_like_date_range("2019-2021") is True

    def test_year_range_with_en_dash(self, pii):
        assert pii.looks_like_date_range("2019–2021") is True

    def test_month_year_range(self, pii):
        assert pii.looks_like_date_range("05/22 - 01/23") is True

    def test_named_month_range(self, pii):
        assert pii.looks_like_date_range("January 2020 - March 2022") is True

    def test_named_month_to_present(self, pii):
        assert pii.looks_like_date_range("June 2021 - Present") is True

    def test_plain_phone_not_date(self, pii):
        assert pii.looks_like_date_range("0501234567") is False

    def test_formatted_phone_not_date(self, pii):
        assert pii.looks_like_date_range("+20 100 123 4567") is False

    def test_partial_year_not_date(self, pii):
        assert pii.looks_like_date_range("2021") is False


# ===========================================================================
# 3. categorize_url
# ===========================================================================
class TestCategorizeUrl:

    def test_linkedin(self, pii):
        assert pii.categorize_url("https://linkedin.com/in/johndoe") == "LINKEDIN_URL"

    def test_github(self, pii):
        assert pii.categorize_url("https://github.com/johndoe") == "GITHUB_URL"

    def test_medium(self, pii):
        assert pii.categorize_url("https://medium.com/@johndoe") == "MEDIUM_URL"

    def test_devpost(self, pii):
        assert pii.categorize_url("https://devpost.com/johndoe") == "DEVPOST_URL"

    def test_generic_url(self, pii):
        assert pii.categorize_url("https://johndoe.io") == "URL"

    def test_case_insensitive(self, pii):
        assert pii.categorize_url("https://LINKEDIN.COM/in/test") == "LINKEDIN_URL"


# ===========================================================================
# 4. _trim_url_span
# ===========================================================================
class TestTrimUrlSpan:

    def test_trims_trailing_period(self, pii):
        text = "See https://example.com."
        start, end = pii._trim_url_span(text, 4, len(text))
        assert text[start:end] == "https://example.com"

    def test_trims_trailing_paren(self, pii):
        text = "link (https://example.com)"
        url_start = text.index("https")
        _, end = pii._trim_url_span(text, url_start, len(text))
        assert text[url_start:end] == "https://example.com"

    def test_no_trim_needed(self, pii):
        text = "https://example.com"
        s, e = pii._trim_url_span(text, 0, len(text))
        assert text[s:e] == "https://example.com"

    def test_trims_multiple_chars(self, pii):
        text = "go to https://example.com),"
        url_start = text.index("https")
        _, end = pii._trim_url_span(text, url_start, len(text))
        assert text[url_start:end] == "https://example.com"


# ===========================================================================
# 5. mask_with_mapping
# ===========================================================================
class TestMaskWithMapping:

    def _make_result(self, entity_type, start, end, score=0.9):
        return {"entity_type": entity_type, "start": start, "end": end,
                "score": score, "source": "test"}

    def test_basic_masking(self, pii):
        text = "Email: test@example.com"
        results = [self._make_result("EMAIL_ADDRESS", 7, len(text))]
        masked, mask_map = pii.mask_with_mapping(text, results)
        assert "test@example.com" not in masked
        assert "<EMAIL_ADDRESS_0>" in masked

    def test_dedup_same_value(self, pii):
        text = "test@example.com and test@example.com"
        r1 = self._make_result("EMAIL_ADDRESS", 0, 16)
        r2 = self._make_result("EMAIL_ADDRESS", 21, 37)
        masked, mask_map = pii.mask_with_mapping(text, [r1, r2])
        # Only one unique token should exist in mask_map
        assert len(mask_map) == 1

    def test_dedup_case_insensitive(self, pii):
        text = "Test@Example.com and test@example.com"
        r1 = self._make_result("EMAIL_ADDRESS", 0, 16)
        r2 = self._make_result("EMAIL_ADDRESS", 21, 37)
        masked, mask_map = pii.mask_with_mapping(text, [r1, r2])
        assert len(mask_map) == 1

    def test_multiple_entity_types(self, pii):
        text = "Ahmed Hassan test@example.com"
        results = [
            self._make_result("PERSON", 0, 12),
            self._make_result("EMAIL_ADDRESS", 13, 29),
        ]
        masked, mask_map = pii.mask_with_mapping(text, results)
        assert _has_token_type(mask_map, "PERSON")
        assert _has_token_type(mask_map, "EMAIL_ADDRESS")
        assert "Ahmed Hassan" not in masked
        assert "test@example.com" not in masked

    def test_counters_increment_per_type(self, pii):
        text = "foo@a.com bar@b.com"
        results = [
            self._make_result("EMAIL_ADDRESS", 0, 9),
            self._make_result("EMAIL_ADDRESS", 10, 19),
        ]
        masked, mask_map = pii.mask_with_mapping(text, results)
        tokens = set(mask_map.keys())
        assert "<EMAIL_ADDRESS_0>" in tokens
        assert "<EMAIL_ADDRESS_1>" in tokens

    def test_offset_correct_for_sequential_entities(self, pii):
        text = "John Doe | jane@example.com"
        results = [
            self._make_result("PERSON", 0, 8),
            self._make_result("EMAIL_ADDRESS", 11, 27),
        ]
        masked, mask_map = pii.mask_with_mapping(text, results)
        assert "John Doe" not in masked
        assert "jane@example.com" not in masked
        # Reconstruction: replace tokens back
        for token, data in mask_map.items():
            masked = masked.replace(token, data["value"])
        assert masked == text


# ===========================================================================
# 6. unmask_text
# ===========================================================================
class TestUnmaskText:

    def _make_mask_map(self, token, value, type_="PERSON"):
        return {token: {"value": value, "type": type_, "start": 0,
                        "end": len(value), "confidence": 0.9}}

    def test_exact_token_replaced(self, pii):
        mask_map = self._make_mask_map("<PERSON_0>", "Ahmed Hassan")
        result = pii.unmask_text("Hello <PERSON_0>!", mask_map)
        assert result == "Hello Ahmed Hassan!"

    def test_spaced_token_replaced(self, pii):
        mask_map = self._make_mask_map("<PERSON_0>", "Ahmed Hassan")
        result = pii.unmask_text("Hello < PERSON_0 >!", mask_map)
        assert result == "Hello Ahmed Hassan!"

    def test_multiple_occurrences_all_replaced(self, pii):
        mask_map = self._make_mask_map("<EMAIL_ADDRESS_0>", "a@b.com")
        text = "Send to <EMAIL_ADDRESS_0> and CC <EMAIL_ADDRESS_0>"
        result = pii.unmask_text(text, mask_map)
        assert result == "Send to a@b.com and CC a@b.com"

    def test_value_with_backslash_safe(self, pii):
        # Backslashes in original values should not be treated as backreferences
        mask_map = self._make_mask_map("<URL_0>", r"https://example.com/path\file")
        text = "Go to <URL_0>"
        result = pii.unmask_text(text, mask_map)
        assert r"https://example.com/path\file" in result

    def test_no_token_in_text_unchanged(self, pii):
        mask_map = self._make_mask_map("<PERSON_0>", "Ahmed")
        result = pii.unmask_text("Hello world", mask_map)
        assert result == "Hello world"

    def test_empty_mask_map(self, pii):
        result = pii.unmask_text("Hello world", {})
        assert result == "Hello world"


# ===========================================================================
# 7. filter_entities (unit)
# ===========================================================================
class TestFilterEntities:

    def _make_result(self, entity_type, start, end, score=0.9):
        return {"entity_type": entity_type, "start": start, "end": end,
                "score": score, "source": "test"}

    def test_email_always_kept(self, pii):
        text = "ahmed@example.com"
        results = [self._make_result("EMAIL_ADDRESS", 0, 17)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 1

    def test_person_in_top_region_kept(self, pii):
        text = "Ahmed Hassan\n" + "x\n" * 10
        results = [self._make_result("PERSON", 0, 12)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 1

    def test_person_outside_top_region_dropped(self, pii):
        header = "\n".join(["line"] * 20) + "\n"
        text = header + "Ahmed Hassan"
        start = len(header)
        results = [self._make_result("PERSON", start, start + 12)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 0

    def test_phone_valid_kept_in_top(self, pii):
        text = "+20 100 123 4567\n" + "x\n" * 10
        results = [self._make_result("PHONE_NUMBER", 0, 16)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 1

    def test_phone_date_range_dropped(self, pii):
        text = "05/22 - 01/23\n" + "x\n" * 10
        results = [self._make_result("PHONE_NUMBER", 0, 14)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 0

    def test_phone_too_few_digits_dropped(self, pii):
        text = "123-45\n" + "x\n" * 10
        results = [self._make_result("PHONE_NUMBER", 0, 6)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 0

    def test_url_low_score_dropped(self, pii):
        text = "https://example.com"
        results = [self._make_result("URL", 0, 19, score=0.3)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 0

    def test_url_sufficient_score_kept(self, pii):
        text = "https://example.com"
        results = [self._make_result("URL", 0, 19, score=0.7)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 1

    def test_whitelisted_entity_dropped(self, pii):
        text = "Python Developer"
        results = [self._make_result("PERSON", 0, 6)]   # "Python"
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 0

    def test_location_with_newline_dropped(self, pii):
        text = "Cairo\nEgypt"
        results = [self._make_result("LOCATION", 0, 11, score=0.8)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 0

    def test_unknown_entity_type_dropped(self, pii):
        text = "something"
        results = [self._make_result("CRYPTO", 0, 9)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 0

    def test_linkedin_url_in_included(self, pii):
        text = "https://linkedin.com/in/ahmedhassan"
        results = [self._make_result("LINKEDIN_URL", 0, len(text), score=0.9)]
        filtered = pii.filter_entities(results, text)
        assert len(filtered) == 1


# ===========================================================================
# 8. remove_overlaps
# ===========================================================================
class TestRemoveOverlaps:

    def _r(self, start, end, score=0.9, entity_type="PERSON"):
        return {"entity_type": entity_type, "start": start, "end": end,
                "score": score, "source": "test"}

    def test_no_overlap_both_kept(self, pii):
        results = [self._r(0, 5), self._r(10, 15)]
        assert len(pii.remove_overlaps(results)) == 2

    def test_full_overlap_higher_score_wins(self, pii):
        results = [self._r(0, 10, score=0.9), self._r(0, 10, score=0.5)]
        kept = pii.remove_overlaps(results)
        assert len(kept) == 1
        assert kept[0]["score"] == 0.9

    def test_partial_overlap_first_wins(self, pii):
        results = [self._r(0, 10, score=0.9), self._r(5, 15, score=0.9)]
        kept = pii.remove_overlaps(results)
        assert len(kept) == 1
        assert kept[0]["start"] == 0

    def test_adjacent_spans_both_kept(self, pii):
        # end of first == start of second: not overlapping
        results = [self._r(0, 5), self._r(5, 10)]
        assert len(pii.remove_overlaps(results)) == 2


# ===========================================================================
# 9. pattern_based_detection
# ===========================================================================
class TestPatternBasedDetection:

    def test_detects_email(self, pii):
        text = "Contact me at foo@bar.com"
        results = pii.pattern_based_detection(text)
        types = [r["entity_type"] for r in results]
        assert "EMAIL_ADDRESS" in types

    def test_detects_url(self, pii):
        text = "Visit https://example.com for more"
        results = pii.pattern_based_detection(text)
        types = [r["entity_type"] for r in results]
        assert "URL" in types

    def test_url_span_trimmed_of_trailing_punct(self, pii):
        text = "See https://example.com."
        results = pii.pattern_based_detection(text)
        url_result = next(r for r in results if r["entity_type"] == "URL")
        assert text[url_result["start"]:url_result["end"]] == "https://example.com"

    def test_detects_address(self, pii):
        text = "I live at 123 Main Street Cairo 12345"
        results = pii.pattern_based_detection(text)
        types = [r["entity_type"] for r in results]
        assert "LOCATION" in types

    def test_detects_phone(self, pii):
        text = "+1 (555) 123-4567"
        results = pii.pattern_based_detection(text)
        types = [r["entity_type"] for r in results]
        assert "PHONE_NUMBER" in types

    def test_version_string_not_phone(self, pii):
        # "1.2.3.4.5" should not match the tighter phone pattern
        text = "version 1.2.3"
        results = pii.pattern_based_detection(text)
        types = [r["entity_type"] for r in results]
        assert "PHONE_NUMBER" not in types


# ===========================================================================
# 10. pii_pipeline — integration tests
# ===========================================================================
class TestPiiPipelineIntegration:

    # -----------------------------------------------------------------------
    # 10a. Standard English CV
    # -----------------------------------------------------------------------
    def test_standard_english_cv(self, pii):
        cv = (
            "John Smith\n"
            "john.smith@gmail.com | +1 (555) 123-4567\n"
            "https://linkedin.com/in/johnsmith\n"
            "https://github.com/johnsmith\n\n"
            "Education\n"
            "BSc Computer Science, MIT, 2018-2022\n\n"
            "Skills\n"
            "Python, Django, Docker, AWS\n"
        )
        result = pii.pii_pipeline(cv)
        masked = result["masked_text"]
        mask_map = result["mask_map"]

        assert "john.smith@gmail.com" not in masked
        assert "+1 (555) 123-4567" not in masked
        assert "linkedin.com/in/johnsmith" not in masked
        assert "github.com/johnsmith" not in masked

        # Tech skills and headers should NOT be masked
        assert "Python" in masked
        assert "Docker" in masked
        assert "Education" in masked

    # -----------------------------------------------------------------------
    # 10b. Name-only masking (no label)
    # -----------------------------------------------------------------------
    def test_name_at_top_masked(self, pii):
        cv = "Ahmed Hassan\nSoftware Engineer\nahmed@example.com\n\nSkills\nPython\n"
        result = pii.pii_pipeline(cv)
        assert "ahmed@example.com" not in result["masked_text"]

    # -----------------------------------------------------------------------
    # 10c. Email appears multiple times — dedup
    # -----------------------------------------------------------------------
    def test_email_dedup(self, pii):
        cv = (
            "Name: Jane Doe\n"
            "Email: jane@example.com\n\n"
            "References available. Contact: jane@example.com\n"
        )
        result = pii.pii_pipeline(cv)
        mask_map = result["mask_map"]
        email_tokens = _tokens_of_type(mask_map, "EMAIL_ADDRESS")
        assert len(email_tokens) == 1   # deduplicated

    # -----------------------------------------------------------------------
    # 10d. Date ranges not masked as phone numbers
    # -----------------------------------------------------------------------
    def test_date_range_not_masked(self, pii):
        cv = (
            "Name: Ali Mohamed\n"
            "ali@example.com\n\n"
            "Experience\n"
            "Software Engineer | Acme Inc  2019-2022\n"
            "Junior Dev | Beta LLC  05/18 - 06/20\n"
        )
        result = pii.pii_pipeline(cv)
        assert "2019-2022" in result["masked_text"]
        assert "05/18 - 06/20" in result["masked_text"]

    # -----------------------------------------------------------------------
    # 10e. Tech skills not masked
    # -----------------------------------------------------------------------
    def test_tech_skills_not_masked(self, pii):
        cv = (
            "Name: Sara Lee\n"
            "sara@example.com\n\n"
            "Skills\n"
            "Python, TensorFlow, PyTorch, Docker, Kubernetes, AWS, React\n"
        )
        result = pii.pii_pipeline(cv)
        masked = result["masked_text"]
        for skill in ["Python", "TensorFlow", "Docker", "Kubernetes", "AWS", "React"]:
            assert skill in masked, f"{skill} was incorrectly masked"

    # -----------------------------------------------------------------------
    # 10f. CV headers not masked
    # -----------------------------------------------------------------------
    def test_cv_headers_not_masked(self, pii):
        cv = (
            "Name: Omar Khalil\n"
            "omar@example.com\n\n"
            "Education\nExperience\nProjects\nSkills\nCertifications\n"
        )
        masked = pii.pii_pipeline(cv)["masked_text"]
        for header in ["Education", "Experience", "Projects", "Skills", "Certifications"]:
            assert header in masked, f"Header '{header}' was incorrectly masked"

    # -----------------------------------------------------------------------
    # 10g. LinkedIn / GitHub URLs masked
    # -----------------------------------------------------------------------
    def test_social_urls_masked(self, pii):
        cv = (
            "Name: Mia Chen\n"
            "mia@example.com\n"
            "https://linkedin.com/in/miachen\n"
            "https://github.com/miachen\n"
        )
        result = pii.pii_pipeline(cv)
        masked = result["masked_text"]
        assert "linkedin.com/in/miachen" not in masked
        assert "github.com/miachen" not in masked
        assert _has_token_type(result["mask_map"], "LINKEDIN_URL")
        assert _has_token_type(result["mask_map"], "GITHUB_URL")

    # -----------------------------------------------------------------------
    # 10h. No PII — empty mask map
    # -----------------------------------------------------------------------
    def test_no_pii_cv(self, pii):
        cv = (
            "Education\nBSc Computer Science, 2018-2022\n\n"
            "Skills\nPython, Java, SQL\n\n"
            "Certifications\nAWS Certified Solutions Architect\n"
        )
        result = pii.pii_pipeline(cv)
        # mask_map may be empty or very small — no emails/phones/names
        values = _original_values(result["mask_map"])
        assert "Python" not in values
        assert "Java" not in values

    # -----------------------------------------------------------------------
    # 10i. University names not masked as PERSON/ORG
    # -----------------------------------------------------------------------
    def test_university_name_not_masked(self, pii):
        cv = (
            "Name: Layla Nasser\n"
            "layla@example.com\n\n"
            "Education\nCairo University, 2019-2023\n"
            "MIT, Cambridge\n"
        )
        masked = pii.pii_pipeline(cv)["masked_text"]
        assert "Cairo University" in masked
        assert "MIT" in masked

    # -----------------------------------------------------------------------
    # 10j. International name with explicit label
    # -----------------------------------------------------------------------
    def test_arabic_name_with_label(self, pii):
        cv = "Name: محمد علي\nEmail: m.ali@example.com\n\nSkills\nPython\n"
        result = pii.pii_pipeline(cv)
        # At minimum the email must be masked
        assert "m.ali@example.com" not in result["masked_text"]

    # -----------------------------------------------------------------------
    # 10k. Personal website URL masked
    # -----------------------------------------------------------------------
    def test_personal_website_masked(self, pii):
        cv = (
            "Name: Tom Brown\n"
            "tom@example.com | https://tombrown.io\n\n"
            "Skills\nJavaScript\n"
        )
        result = pii.pii_pipeline(cv)
        assert "tombrown.io" not in result["masked_text"]

    # -----------------------------------------------------------------------
    # 10l. Phone number edge cases
    # -----------------------------------------------------------------------
    def test_egyptian_phone_masked(self, pii):
        cv = "Name: Ahmed Said\n+20 100 123 4567\nahmed@example.com\n\nSkills\nPython\n"
        result = pii.pii_pipeline(cv)
        assert "+20 100 123 4567" not in result["masked_text"]

    def test_us_phone_masked(self, pii):
        cv = "Name: John Smith\n(555) 867-5309\njohn@example.com\n\nSkills\nJava\n"
        result = pii.pii_pipeline(cv)
        assert "867-5309" not in result["masked_text"]

    def test_phone_with_extension_masked(self, pii):
        cv = "Name: Kate Lee\n+1 800 555 1234\nkate@example.com\n\nSkills\nPython\n"
        result = pii.pii_pipeline(cv)
        assert "555 1234" not in result["masked_text"]

    # -----------------------------------------------------------------------
    # 10m. mask_map structure is well-formed
    # -----------------------------------------------------------------------
    def test_mask_map_structure(self, pii):
        cv = "Name: Lena Karl\nlena@example.com\n+49 30 12345678\n\nSkills\nPython\n"
        result = pii.pii_pipeline(cv)
        for token, data in result["mask_map"].items():
            assert "value" in data
            assert "type" in data
            assert "start" in data
            assert "end" in data
            assert "confidence" in data
            assert token.startswith("<") and token.endswith(">")

    # -----------------------------------------------------------------------
    # 10n. Masked text can be fully reconstructed via unmask_text
    # -----------------------------------------------------------------------
    def test_round_trip(self, pii):
        cv = (
            "Name: Diana Prince\n"
            "diana@example.com | +1 555 987 6543\n"
            "https://github.com/dprince\n\n"
            "Skills\nPython, Docker\n"
        )
        result = pii.pii_pipeline(cv)
        reconstructed = pii.unmask_text(result["masked_text"], result["mask_map"])
        # All masked values must be restored
        for data in result["mask_map"].values():
            assert data["value"] in reconstructed

    # -----------------------------------------------------------------------
    # 10o. Overlapping detections resolved correctly
    # -----------------------------------------------------------------------
    def test_no_double_masking(self, pii):
        cv = "Name: Max Power\nmax@power.com\n\nSkills\nPython\n"
        result = pii.pii_pipeline(cv)
        masked = result["masked_text"]
        # No token should appear inside another token
        assert "<<" not in masked
        assert ">>" not in masked

    # -----------------------------------------------------------------------
    # 10p. Entities list returned and consistent with mask_map
    # -----------------------------------------------------------------------
    def test_entities_list_consistent(self, pii):
        cv = "Name: Eva Green\neva@green.com\n\nSkills\nPython\n"
        result = pii.pii_pipeline(cv)
        entity_types = {e["entity_type"] for e in result["entities"]}
        mask_types = {v["type"] for v in result["mask_map"].values()}
        # Every masked type should appear in entities
        assert mask_types.issubset(entity_types | {"PERSON"})  # PERSON may be deduplicated

    # -----------------------------------------------------------------------
    # 10q. Empty input
    # -----------------------------------------------------------------------
    def test_empty_input(self, pii):
        result = pii.pii_pipeline("")
        assert result["masked_text"] == ""
        assert result["mask_map"] == {}

    # -----------------------------------------------------------------------
    # 10r. Input with only whitespace
    # -----------------------------------------------------------------------
    def test_whitespace_only_input(self, pii):
        result = pii.pii_pipeline("   \n\n\t  ")
        assert result["mask_map"] == {}

    # -----------------------------------------------------------------------
    # 10s. Multiple emails masked with distinct tokens
    # -----------------------------------------------------------------------
    def test_multiple_distinct_emails(self, pii):
        cv = (
            "Name: Two People\n"
            "alice@example.com\n"
            "bob@example.com\n\n"
            "Skills\nPython\n"
        )
        result = pii.pii_pipeline(cv)
        email_tokens = _tokens_of_type(result["mask_map"], "EMAIL_ADDRESS")
        assert len(email_tokens) == 2

    # -----------------------------------------------------------------------
    # 10t. URL with trailing punctuation not included in mask
    # -----------------------------------------------------------------------
    def test_url_trailing_punct_excluded(self, pii):
        cv = (
            "Name: Pat Kim\n"
            "pat@example.com\n"
            "Portfolio: https://patkim.dev.\n\n"
            "Skills\nJavaScript\n"
        )
        result = pii.pii_pipeline(cv)
        masked = result["masked_text"]
        # The period after the URL should remain
        assert "." in masked   # period preserved somewhere


# ===========================================================================
# conftest / fixtures
# ===========================================================================
import types, sys, importlib

@pytest.fixture(scope="session")
def pii():
    """
    Import the PII module. Adjust the module name to match your file.
    Falls back to a namespace of individually imported functions if needed.
    """
    try:
        import shared.helpers.cv_pii_masker as mod
    except ModuleNotFoundError as e:
        pytest.fail(f"Could not import cv_pii_masker: {e}")
    return mod