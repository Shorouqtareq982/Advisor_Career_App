"""
Plan Feedback Mapper
Maps user-selected feedback intents to LLM instructions.

This replaces free-text feedback with structured, predefined intents
that are more reliable and consistent.
"""

from enum import Enum
from typing import List, Dict, Any


class PlanFeedbackIntent(str, Enum):
    """User-selectable feedback intents for plan regeneration"""
    MORE_ADVANCED = "more_advanced"
    MORE_PRACTICAL = "more_practical"
    LESS_REPETITION = "less_repetition"
    FOCUS_SELECTED = "focus_selected_skills"
    FASTER_PROGRESS = "faster_progress"
    SIMPLER_BASICS = "simpler_basics"
    MORE_PROJECTS = "more_projects"
    MORE_THEORY = "more_theory"
    BETTER_STRUCTURE = "better_structure"
    MORE_EXAMPLES = "more_examples"


CLASS_INSTRUCTION_MAP = {
    PlanFeedbackIntent.MORE_ADVANCED: {
        "intent": "Increase technical depth and rigor",
        "instruction": (
            "CRITICAL: Increase technical depth significantly without changing target levels.\n"
            "• Focus on advanced patterns, architectural decisions, and industry best practices\n"
            "• For beginner weeks: add 'intermediate patterns' and edge cases\n"
            "• For intermediate weeks: add performance optimization, design patterns, production concerns\n"
            "• For advanced weeks: add cutting-edge techniques and complex architectures\n"
            "• Use precise technical terminology and reference official specs/RFCs\n"
            "• Include debugging strategies, performance analysis, and system design trade-offs\n"
            "• Do NOT label beginner targets as advanced, but make them more sophisticated\n"
            "• Add technical challenges: 'implement X using advanced technique Y'"
        ),
        "priority": 1,
    },
    PlanFeedbackIntent.MORE_PRACTICAL: {
        "intent": "Maximize hands-on and project-based learning",
        "instruction": (
            "CRITICAL: Make the plan extremely practical and hands-on (70% coding, 30% learning).\n"
            "• Replace passive content with active coding exercises and real-world scenarios\n"
            "• Include mini-projects every 1-2 weeks that build on each other\n"
            "• Add debugging scenarios: 'fix this broken code' and 'optimize this slow function'\n"
            "• Emphasize portfolio-building: what would you show an employer?\n"
            "• Use real datasets and real-world problems from industry\n"
            "• Every learning outcome must have a concrete deliverable (code, working example)\n"
            "• Prefer 'hands-on projects' over 'study guides' in resource queries\n"
            "• Include implementation milestones and checkpoints"
        ),
        "priority": 2,
    },
    PlanFeedbackIntent.LESS_REPETITION: {
        "intent": "Eliminate topic repetition and maximize variety",
        "instruction": (
            "CRITICAL: Reduce repetition to almost zero.\n"
            "• Ensure EVERY WEEK covers completely new material or a different aspect\n"
            "• If a skill appears in multiple weeks, each week MUST use different:\n"
            "  - Subtopic focus (not the same concept from different angle)\n"
            "  - Learning method (one week = reading, next = hands-on, next = project)\n"
            "  - Complexity level (building on previous week, not repeating it)\n"
            "• Do NOT cover the same skill twice with similar depth in same mode\n"
            "• Mix resources: some weeks focus on theory, others on practice, others on projects\n"
            "• Vary instructional approach: tutorials, hands-on labs, documentation reading, live-coding\n"
            "• Track what was covered each week and build logically on it"
        ),
        "priority": 3,
    },
    PlanFeedbackIntent.FOCUS_SELECTED: {
        "intent": "Concentrate ONLY on selected skills, ignore owned skills",
        "instruction": (
            "CRITICAL: Focus exclusively on selected learning targets.\n"
            "• Remove or drastically reduce any weeks about owned skills or core skills\n"
            "• Allocate 90%+ of time to explicitly selected targets\n"
            "• Do NOT add weeks for strengthening existing skills\n"
            "• Do NOT broaden the scope with related skills\n"
            "• Keep plan narrow and deep, not wide and shallow\n"
            "• Every week should progress ONE of the selected skills\n"
            "• If selected skills can share practice: combine them, don't separate"
        ),
        "priority": 4,
    },
    PlanFeedbackIntent.FASTER_PROGRESS: {
        "intent": "Accelerate pace dramatically and cover more ground",
        "instruction": (
            "CRITICAL: Speed up significantly. Compress time-intensive foundational work.\n"
            "• Move from fundamentals to practical application 40% faster\n"
            "• Condense prerequisite weeks: assume the user can learn foundations quickly\n"
            "• Increase learning density: cover more concepts per week\n"
            "• Jump to interesting applications earlier (by week 2-3, not week 5)\n"
            "• Reduce hand-holding and explanatory detail; get to implementation faster\n"
            "• Use more advanced resources earlier (skip beginner content if possible)\n"
            "• Focus on key concepts only, not exhaustive coverage"
        ),
        "priority": 5,
    },
    PlanFeedbackIntent.SIMPLER_BASICS: {
        "intent": "Focus on clear fundamentals and accessible explanations",
        "instruction": (
            "CRITICAL: Make everything beginner-friendly and accessible.\n"
            "• Use simple, clear language; avoid jargon or explain every technical term\n"
            "• Extend foundational weeks: spend more time on basics\n"
            "• Break concepts into smaller, digestible pieces\n"
            "• Include more foundational weeks before any applications\n"
            "• Provide extra examples and analogies for complex concepts\n"
            "• Ensure strong prerequisites before moving to next topic\n"
            "• Prefer 'beginner-friendly' resources and step-by-step tutorials"
        ),
        "priority": 6,
    },
    PlanFeedbackIntent.MORE_PROJECTS: {
        "intent": "Emphasize large project-based learning",
        "instruction": (
            "CRITICAL: Shift toward project-based learning (building things).\n"
            "• Introduce a capstone project or major project by week 2-3\n"
            "• Have 1-2 weeks per skill dedicated to project milestones\n"
            "• Projects should be realistic and portfolio-worthy\n"
            "• Break projects into weekly deliverables with concrete outputs\n"
            "• Each project uses skills from multiple weeks combined\n"
            "• Include project planning weeks: architecture, design, implementation phases\n"
            "• Prioritize 'project' resource types (GitHub, project templates, case studies)"
        ),
        "priority": 7,
    },
    PlanFeedbackIntent.MORE_THEORY: {
        "intent": "Increase theoretical understanding and foundational knowledge",
        "instruction": (
            "CRITICAL: Strengthen theoretical foundation and conceptual understanding.\n"
            "• Add weeks for understanding algorithms, data structures, system design principles\n"
            "• Include architectural patterns, design principles, and trade-offs\n"
            "• Explain the 'why' behind techniques, not just the 'how'\n"
            "• Add academic/research perspectives on the topics\n"
            "• Include mathematical foundations where relevant\n"
            "• Prioritize documentation and research papers over quick tutorials\n"
            "• Focus on deep understanding over quick application\n"
            "• Each skill should include conceptual foundations before implementation"
        ),
        "priority": 8,
    },
    PlanFeedbackIntent.BETTER_STRUCTURE: {
        "intent": "Improve logical flow and prerequisite progression",
        "instruction": (
            "CRITICAL: Reorganize for better logical flow and prerequisites.\n"
            "• Reorder weeks so prerequisites come BEFORE dependent skills\n"
            "• Group related skills together instead of interleaving\n"
            "• Build complexity gradually: simple → moderate → complex\n"
            "• Ensure each week can reference and build on previous weeks\n"
            "• Make connections explicit between related skills\n"
            "• Remove or reorder any disconnected or out-of-sequence topics\n"
            "• Create a clear narrative arc through the plan"
        ),
        "priority": 9,
    },
    PlanFeedbackIntent.MORE_EXAMPLES: {
        "intent": "Include concrete examples and case studies",
        "instruction": (
            "CRITICAL: Add concrete, real-world examples throughout.\n"
            "• Include specific, detailed examples in every topic\n"
            "• Add case studies from real companies/projects\n"
            "• Use actual datasets, code samples, and screenshots\n"
            "• Show before/after examples and common mistakes\n"
            "• Include worked examples in each learning outcome\n"
            "• Reference public code repositories and real implementations\n"
            "• Provide concrete output/deliverable examples for each week"
        ),
        "priority": 10,
    },
}


class PlanFeedbackMapper:
    """Maps user feedback intents to consistent LLM instructions"""

    @staticmethod
    def map_intents_to_instruction(intents: List[PlanFeedbackIntent]) -> str:
        """
        Convert a list of user-selected feedback intents into a coherent LLM instruction.
        Handles combining multiple intents intelligently.
        """
        if not intents:
            return ""

        if len(intents) == 1:
            intent = intents[0]
            return CLASS_INSTRUCTION_MAP[intent]["instruction"]

        # Multiple intents: combine them intelligently
        return PlanFeedbackMapper._combine_multiple_intents(intents)

    @staticmethod
    def _combine_multiple_intents(intents: List[PlanFeedbackIntent]) -> str:
        """
        Combine multiple intents into a single coherent instruction.
        Handles conflicts and ensures consistency.
        """
        sorted_intents = sorted(
            intents,
            key=lambda x: CLASS_INSTRUCTION_MAP[x]["priority"]
        )

        combined = "Apply the following modifications to the plan:\n\n"

        for idx, intent in enumerate(sorted_intents, 1):
            entry = CLASS_INSTRUCTION_MAP[intent]
            combined += f"{idx}. {entry['intent']}: {entry['instruction']}\n\n"

        combined += (
            "Ensure all modifications work together harmoniously. "
            "If any modifications conflict, prioritize user experience and plan coherence."
        )

        return combined

    @staticmethod
    def get_intent_display_name(intent: PlanFeedbackIntent) -> str:
        """Get user-friendly display name for an intent"""
        display_map = {
            PlanFeedbackIntent.MORE_ADVANCED: "📈 More Advanced & Deep",
            PlanFeedbackIntent.MORE_PRACTICAL: "🛠️ More Practical & Hands-on",
            PlanFeedbackIntent.LESS_REPETITION: "✨ Remove Repetition",
            PlanFeedbackIntent.FOCUS_SELECTED: "🎯 Focus Selected Skills Only",
            PlanFeedbackIntent.FASTER_PROGRESS: "⚡ Accelerate Progress",
            PlanFeedbackIntent.SIMPLER_BASICS: "📚 Simpler & Clearer",
            PlanFeedbackIntent.MORE_PROJECTS: "🚀 More Projects & Building",
            PlanFeedbackIntent.MORE_THEORY: "🧠 More Theory & Concepts",
            PlanFeedbackIntent.BETTER_STRUCTURE: "🏗️ Better Organization",
            PlanFeedbackIntent.MORE_EXAMPLES: "📖 More Examples & Case Studies",
        }
        return display_map.get(intent, intent.value)

    @staticmethod
    def get_all_intents_for_ui() -> List[Dict[str, str]]:
        """Get all intents formatted for UI display"""
        return [
            {
                "value": intent.value,
                "display": PlanFeedbackMapper.get_intent_display_name(intent),
                "description": CLASS_INSTRUCTION_MAP[intent]["intent"],
            }
            for intent in PlanFeedbackIntent
        ]

    @staticmethod
    def validate_intents(intents: List[str]) -> List[PlanFeedbackIntent]:
        """
        Validate and convert string intents to PlanFeedbackIntent enums.
        Raises ValueError if invalid intent is provided.
        """
        try:
            return [PlanFeedbackIntent(intent) for intent in intents]
        except ValueError as e:
            valid_values = ", ".join(i.value for i in PlanFeedbackIntent)
            raise ValueError(
                f"Invalid feedback intent. Valid values: {valid_values}"
            ) from e
