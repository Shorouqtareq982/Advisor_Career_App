"""
Plan Feedback Mapper
Maps user-selected feedback intents to strong LLM instructions.
"""

from enum import Enum
from typing import List, Dict, Any


class PlanFeedbackIntent(str, Enum):
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
        "intent": "Increase technical depth",
        "instruction": (
            "CRITICAL: Increase technical depth significantly.\n"
            "• Use deeper concepts, advanced patterns, edge cases, and real-world complexity.\n"
            "• Avoid shallow explanations and generic beginner-only topics.\n"
            "• Add optimization, debugging, architecture, and production concerns where relevant.\n"
            "• Keep target levels valid; do not label beginner targets as advanced, but make the work richer."
        ),
        "priority": 1,
    },
    PlanFeedbackIntent.MORE_PRACTICAL: {
        "intent": "More hands-on",
        "instruction": (
            "CRITICAL: Make the plan strongly hands-on.\n"
            "• Each week must include coding/application tasks.\n"
            "• Prefer exercises, notebooks, GitHub projects, real datasets, and implementation work.\n"
            "• Reduce passive reading and increase practical execution.\n"
            "• Study guides should include concrete actions, not vague study advice."
        ),
        "priority": 2,
    },
    PlanFeedbackIntent.MORE_PROJECTS: {
        "intent": "More projects",
        "instruction": (
            "CRITICAL: Increase project-based learning.\n"
            "• Each week should include at least one project-style deliverable.\n"
            "• Prefer portfolio-worthy tasks and real-world mini projects.\n"
            "• Resource focus should prioritize GitHub projects, case studies, and build-along resources.\n"
            "• Do not replace projects with articles or generic tutorials."
        ),
        "priority": 3,
    },
    PlanFeedbackIntent.LESS_REPETITION: {
        "intent": "Less repetition",
        "instruction": (
            "CRITICAL: Reduce repetition aggressively.\n"
            "• Do not repeat the same skill/topic in the same way.\n"
            "• If a skill appears again, it must progress to a new subtopic or harder application.\n"
            "• Avoid duplicate resources, duplicate descriptions, and repeated study-guide wording.\n"
            "• Make every week clearly distinct."
        ),
        "priority": 4,
    },
    PlanFeedbackIntent.FASTER_PROGRESS: {
        "intent": "Faster progress",
        "instruction": (
            "CRITICAL: Apply faster progress as a REAL structural change, not wording only.\n"
            "• Combine 2-3 compatible skills per week when possible.\n"
            "• Avoid spending full weeks on isolated fundamentals unless absolutely necessary.\n"
            "• Move to applied/intermediate work earlier, starting from week 1 or week 2.\n"
            "• Each week should cover more ground than the original plan.\n"
            "• Prefer integrated topics like 'Model Evaluation + Pandas applied workflow'.\n"
            "• Reduce repeated setup/basic explanation and focus on execution.\n"
            "• Add challenging weekly deliverables.\n"
            "• Even with faster progress, each week must still include docs, practice, project, and youtube resources."
        ),
        "priority": 5,
    },
    PlanFeedbackIntent.SIMPLER_BASICS: {
        "intent": "Simpler basics",
        "instruction": (
            "CRITICAL: Make the plan clearer and more beginner-friendly.\n"
            "• Break concepts into smaller steps.\n"
            "• Use simple language and define technical terms.\n"
            "• Add more foundational explanation before advanced application.\n"
            "• Prefer beginner-friendly resources and guided exercises."
        ),
        "priority": 6,
    },
    PlanFeedbackIntent.MORE_THEORY: {
        "intent": "More theory",
        "instruction": (
            "CRITICAL: Strengthen conceptual and theoretical understanding.\n"
            "• Explain why concepts work, not only how to use them.\n"
            "• Add mathematical, architectural, or conceptual foundations where relevant.\n"
            "• Prefer official docs, conceptual guides, papers, and deep explanations.\n"
            "• Balance theory with at least one practical application per week."
        ),
        "priority": 7,
    },
    PlanFeedbackIntent.BETTER_STRUCTURE: {
        "intent": "Better structure",
        "instruction": (
            "CRITICAL: Improve the logical flow of the plan.\n"
            "• Reorder weeks so prerequisites come first.\n"
            "• Group related concepts together.\n"
            "• Build from simple to complex.\n"
            "• Make each week naturally depend on the previous one."
        ),
        "priority": 8,
    },
    PlanFeedbackIntent.MORE_EXAMPLES: {
        "intent": "More examples",
        "instruction": (
            "CRITICAL: Add concrete examples and case studies.\n"
            "• Every week should include real examples, sample tasks, or case studies.\n"
            "• Use real datasets, realistic scenarios, and practical outputs.\n"
            "• Avoid abstract explanations without examples."
        ),
        "priority": 9,
    },
    PlanFeedbackIntent.FOCUS_SELECTED: {
        "intent": "Focus selected skills only",
        "instruction": (
            "CRITICAL: Focus mainly on explicitly selected skills.\n"
            "• Reduce unrelated owned/core skills unless they directly support selected targets.\n"
            "• Keep the plan narrow and deep.\n"
            "• Do not add unrelated skills just to fill weeks."
        ),
        "priority": 10,
    },
}


class PlanFeedbackMapper:
    @staticmethod
    def validate_intents(intents: List[Any]) -> List[PlanFeedbackIntent]:
        if not intents:
            return []

        cleaned = []

        for intent in intents:
            if isinstance(intent, PlanFeedbackIntent):
                value = intent.value
            elif hasattr(intent, "value"):
                value = str(intent.value)
            else:
                value = str(intent or "")

            value = value.strip()

            if "." in value:
                value = value.split(".")[-1]

            value = value.strip().lower()

            if value.upper() in PlanFeedbackIntent.__members__:
                value = PlanFeedbackIntent[value.upper()].value

            cleaned.append(value)

        try:
            return [PlanFeedbackIntent(v) for v in cleaned]
        except ValueError as e:
            valid = ", ".join(i.value for i in PlanFeedbackIntent)
            raise ValueError(f"Invalid feedback intent. Valid values: {valid}") from e

    @staticmethod
    def map_intents_to_instruction(intents: List[PlanFeedbackIntent]) -> str:
        if not intents:
            return ""

        sorted_intents = sorted(
            intents,
            key=lambda x: CLASS_INSTRUCTION_MAP[x]["priority"]
        )

        instructions = ["Apply these user feedback changes meaningfully:\n"]

        for idx, intent in enumerate(sorted_intents, 1):
            entry = CLASS_INSTRUCTION_MAP[intent]
            instructions.append(
                f"{idx}. {entry['intent']}:\n{entry['instruction']}"
            )

        instructions.append(
            "\nEnsure the changes affect topics, weekly structure, study guides, and resource focus — not wording only."
        )

        return "\n\n".join(instructions)

    @staticmethod
    def get_intent_display_name(intent: PlanFeedbackIntent) -> str:
        display_map = {
            PlanFeedbackIntent.MORE_ADVANCED: "📈 More Advanced & Deep",
            PlanFeedbackIntent.MORE_PRACTICAL: "🛠️ More Practical & Hands-on",
            PlanFeedbackIntent.LESS_REPETITION: "✨ Remove Repetition",
            PlanFeedbackIntent.FOCUS_SELECTED: "🎯 Focus Selected Skills Only",
            PlanFeedbackIntent.FASTER_PROGRESS: "⚡ Faster Progress",
            PlanFeedbackIntent.SIMPLER_BASICS: "📚 Simpler Basics",
            PlanFeedbackIntent.MORE_PROJECTS: "🚀 More Projects",
            PlanFeedbackIntent.MORE_THEORY: "🧠 More Theory",
            PlanFeedbackIntent.BETTER_STRUCTURE: "🏗️ Better Structure",
            PlanFeedbackIntent.MORE_EXAMPLES: "📖 More Examples",
        }
        return display_map.get(intent, intent.value)

    @staticmethod
    def get_all_intents_for_ui() -> List[Dict[str, str]]:
        return [
            {
                "value": intent.value,
                "display": PlanFeedbackMapper.get_intent_display_name(intent),
                "description": CLASS_INSTRUCTION_MAP[intent]["intent"],
            }
            for intent in PlanFeedbackIntent
        ]