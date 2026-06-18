"""Deterministic CV section analysis helpers."""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional


def _as_dict(data: Any) -> Dict[str, Any]:
	if data is None:
		return {}
	if isinstance(data, dict):
		return data
	if hasattr(data, "model_dump"):
		return data.model_dump(mode="json", exclude_none=True)
	return {}


def _flatten_text(value: Any) -> str:
	if value is None:
		return ""
	if isinstance(value, str):
		return value
	if isinstance(value, dict):
		return " ".join(_flatten_text(v) for v in value.values() if v is not None)
	if isinstance(value, (list, tuple, set)):
		return " ".join(_flatten_text(item) for item in value if item is not None)
	return str(value)


def _is_present(value: Any) -> bool:
	if value is None:
		return False
	if isinstance(value, str):
		return bool(value.strip() and value.strip().lower() not in {"n/a", "na", "none", "null", "unknown"})
	if isinstance(value, (list, tuple, set, dict)):
		return len(value) > 0
	return True

def _is_valid_email(email):
        if not email:
            return False
        return re.fullmatch(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", str(email).strip()) is not None

    
def _is_valid_phone(phone):
	digits = re.sub(r"\D", "", str(phone or ""))
	return len(digits) >= 7


def _section_pass_fail_notes(passed: bool, notes: str, pass_message: str, fail_prefix: str) -> Dict[str, Any]:
	if passed:
		return {"Pass": True, "Notes": pass_message}
	joined = notes if notes else fail_prefix
	return {"Pass": False, "Notes": joined[:250]}


def _append_note(current_notes: str, message: str) -> str:
	if not message:
		return current_notes
	if not current_notes:
		return message
	return f"{current_notes}; {message}"


def _extract_jd_keywords(job_description: Any) -> List[str]:
	text = _flatten_text(job_description).lower()
	if not text:
		return []

	seeds = {
		"certification", "certifications", "project", "projects", "award", "awards",
		"volunteer", "publication", "publications", "docker", "kubernetes", "aws", "azure",
		"gcp", "cloud", "ci/cd", "scrum", "agile", "python", "java", "javascript",
		"typescript", "react", "node", "sql", "power bi", "tableau", "machine learning",
	}

	found = []
	for keyword in sorted(seeds, key=len, reverse=True):
		if keyword in text and keyword not in found:
			found.append(keyword)
	return found


def _section_relevance_hint(section_text: str, jd_keywords: List[str]) -> bool:
	text = section_text.lower()
	return any(keyword in text for keyword in jd_keywords)


def analyze_section_analysis(parsed_cv: Any, parsed_jd: Optional[Any] = None) -> Dict[str, Any]:
	from ..helpers.content_quality_checker import check_quantifiable_impact

	cv = _as_dict(parsed_cv)
	jd_keywords = _extract_jd_keywords(parsed_jd)

	name = cv.get("name")
	email = cv.get("email")
	phone = cv.get("phone")
	location = cv.get("location")

	contact_notes = ""
	if not _is_present(name):
		contact_notes = _append_note(contact_notes, "Add your full name to make it easy for recruiters to identify your resume.")
	if not _is_valid_email(email):
		contact_notes = _append_note(contact_notes, "We couldn’t find a valid email address. Add a professional email so recruiters can reach you easily.")
	if not _is_valid_phone(phone):
		contact_notes = _append_note(contact_notes, "A valid phone number is missing or not detected. Including one improves your chances of being contacted.")
	if not _is_present(location):
		contact_notes = _append_note(contact_notes, "Consider adding your city and country to provide location information to employers.")
	if _is_present(location):
		contact_pass_message = "Name, email, phone, and location are present and readable."
	else:
		contact_pass_message = "Name, email, and phone are present and readable."

	work_experience = cv.get("work_experience") or []
	work_notes = ""
	work_pass = bool(work_experience)

	quant_impact = check_quantifiable_impact(cv)
	measurable_count = quant_impact.get("count", 0)

	if not work_experience:
		work_notes = _append_note(
			work_notes,
			"Work experience section is not included. Add your past roles to showcase your professional background."
		)
	else:
		for index, role in enumerate(work_experience, start=1):
			role_dict = _as_dict(role)
			role_missing = []

			for field_name, label in (
				("company", "company name"),
				("role", "job title"),
				("from_date", "start date"),
				("to_date", "end date"),
				("location", "work location"),
			):
				if not _is_present(role_dict.get(field_name)):
					role_missing.append(label)

			descriptions = role_dict.get("description") or []
			if not descriptions:
				role_missing.append("job responsibilities or bullet points")

			if role_missing:
				work_notes = _append_note(
					work_notes,
					f"Work entry {index} is incomplete. Consider adding: {', '.join(role_missing)}."
				)

		if measurable_count < 5:
			work_notes = _append_note(
				work_notes,
				f"Only {measurable_count} measurable achievement(s) were detected. Aim for at least 5 quantified results (e.g., revenue impact, time saved, or performance improvements)."
			)

		work_pass = not work_notes


	education = cv.get("education") or []
	education_notes = ""
	education_pass = bool(education)

	if not education:
		education_notes = _append_note(
			education_notes,
			"Education section is not included. Add your academic background to strengthen your profile."
		)
	else:
		for index, item in enumerate(education, start=1):
			item_dict = _as_dict(item)
			missing = []

			if not _is_present(item_dict.get("degree")):
				missing.append("degree or qualification")
			if not _is_present(item_dict.get("university")):
				missing.append("institution name")
			if not _is_present(item_dict.get("from_date")):
				missing.append("start date")
			if not _is_present(item_dict.get("to_date")):
				missing.append("end date")

			if missing:
				education_notes = _append_note(
					education_notes,
					f"Education entry {index} is incomplete. Missing: {', '.join(missing)}."
				)

		education_pass = not education_notes


	skill_sections = cv.get("skill_section") or []
	all_skills: List[str] = []
	grouped_sections = 0

	for section in skill_sections:
		section_dict = _as_dict(section)
		skills = section_dict.get("skills") or []

		if skills:
			grouped_sections += 1

		for skill in skills:
			skill_text = _flatten_text(skill).strip()
			if skill_text:
				all_skills.append(skill_text)

	unique_skills = {skill.lower() for skill in all_skills}
	skills_notes = ""

	if not skill_sections:
		skills_notes = _append_note(
			skills_notes,
			"Skills section is not included. Add a dedicated skills section to highlight your expertise."
		)
	else:
		if grouped_sections == 0:
			skills_notes = _append_note(
				skills_notes,
				"Skills are not organized into categories. Grouping them (e.g., Technical, Tools, Soft Skills) improves readability."
			)

		if len(unique_skills) < 5:
			skills_notes = _append_note(
				skills_notes,
				f"Only {len(unique_skills)} relevant skill(s) detected. Consider listing at least 5 key skills relevant to your target role."
			)

	skills_pass = not skills_notes


	projects = cv.get("projects") or []
	certifications = cv.get("certifications") or []
	achievements = cv.get("achievements") or []
	additional_notes = ""

	additional_sections_present = False
	relevant_sections = []

	if projects:
		additional_sections_present = True
		project_text = _flatten_text(projects)

		if jd_keywords and not _section_relevance_hint(project_text, jd_keywords):
			additional_notes = _append_note(
				additional_notes,
				"Projects are included, but they are not clearly aligned with the job requirements."
			)
		else:
			relevant_sections.append("Projects")

	if certifications:
		additional_sections_present = True
		cert_text = _flatten_text(certifications)

		if jd_keywords and not _section_relevance_hint(cert_text, jd_keywords):
			additional_notes = _append_note(
				additional_notes,
				"Certifications are present, but they do not strongly support the target role."
			)
		else:
			relevant_sections.append("Certifications")

	if achievements:
		additional_sections_present = True
		achievement_text = _flatten_text(achievements)

		if jd_keywords and not _section_relevance_hint(achievement_text, jd_keywords):
			additional_notes = _append_note(
				additional_notes,
				"Achievements are included, but they are not clearly connected to the job description."
			)
		else:
			relevant_sections.append("Achievements")

	if not additional_sections_present:
		additional_notes = _append_note(
			additional_notes,
			"No additional sections detected. Consider adding Projects, Certifications, or Awards to strengthen your CV."
		)

	if jd_keywords and additional_sections_present and not relevant_sections:
		additional_notes = _append_note(
			additional_notes,
			"Additional sections are present, but they do not clearly match the target job requirements."
		)

	additional_pass = not additional_notes

	return {
		"Contact_Info": _section_pass_fail_notes(
			passed=not contact_notes,
			notes=contact_notes,
			pass_message=contact_pass_message,
			fail_prefix="Missing required contact information",
		),
		"Work_Experience": _section_pass_fail_notes(
			passed=work_pass,
			notes=work_notes,
			pass_message="Work experience section includes required fields, bullet points, and measurable achievements.",
			fail_prefix="Work experience section is incomplete",
		),
		"Education": _section_pass_fail_notes(
			passed=education_pass,
			notes=education_notes,
			pass_message="Education section includes degree, institution, and dates.",
			fail_prefix="Education section is incomplete",
		),
		"Skills": _section_pass_fail_notes(
			passed=skills_pass,
			notes=skills_notes,
			pass_message="Skills section has enough relevant skills and is ATS-friendly.",
			fail_prefix="Skills section is incomplete",
		),
		"Additional_Sections": _section_pass_fail_notes(
			passed=additional_pass,
			notes=additional_notes,
			pass_message="Additional sections are present and add value to the candidacy.",
			fail_prefix="Additional sections are missing or weak",
		),
	}
