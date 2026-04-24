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
            "Increase technical depth significantly. "
            "Use intermediate to advanced concepts, avoid basic explanations, "
            "and include real-world scenarios, optimization techniques, and deeper analysis."
        ),
        "priority": 1,
    },

    PlanFeedbackIntent.MORE_PRACTICAL: {
        "intent": "More hands-on",
        "instruction": (
            "Prioritize hands-on learning. "
            "Each week must include real coding tasks, applied exercises, and practical implementation. "
            "Reduce theoretical explanations and focus on doing."
        ),
        "priority": 2,
    },

    PlanFeedbackIntent.MORE_PROJECTS: {
        "intent": "More projects",
        "instruction": (
            "Increase the number of projects. "
            "Ensure each week includes at least one real-world project or GitHub-based task. "
            "Projects should be meaningful and portfolio-worthy."
        ),
        "priority": 3,
    },

    PlanFeedbackIntent.LESS_REPETITION: {
        "intent": "Less repetition",
        "instruction": (
            "Avoid repeating previously covered topics. "
            "Ensure each week introduces new concepts or builds progressively. "
            "Do not reuse similar explanations or duplicate content."
        ),
        "priority": 4,
    },

    PlanFeedbackIntent.FASTER_PROGRESS: {
        "intent": "Faster pace",
        "instruction": (
            "CRITICAL: Apply faster progress as a REAL structural change, not wording only.\n"
            "• Compress the plan by combining 2-3 related skills per week when possible\n"
            "• Avoid spending full weeks on isolated fundamentals unless absolutely necessary\n"
            "• Move to applied/intermediate work earlier, starting from week 1 or week 2\n"
            "• Each week should cover more ground than the original plan\n"
            "• Prefer integrated weekly topics like 'Model Evaluation + Pandas applied workflow'\n"
            "• Reduce repeated setup/basic explanation and focus on execution\n"
            "• Add challenging weekly deliverables\n"
            "• If duration is short, prioritize dense practical progression over slow foundations\n"
            "IMPORTANT: Even when applying faster_progress:\n"
            "• Each week MUST still include:\n"
            "  - 1 docs\n"
            "  - 1 practice\n"
            "  - 1 project\n"
            "  - 1 youtube\n"
        ),
        "priority": 5,
    },
}


class PlanFeedbackMapper:

    @staticmethod
    def validate_intents(intents: List[Any]) -> List[PlanFeedbackIntent]:
        """
        Handles:
        - "more_advanced"
        - "MORE_ADVANCED"
        - PlanFeedbackIntent.MORE_ADVANCED
        - "planfeedbackintent.more_advanced"
        """

        if not intents:
            return []

        cleaned = []

        for intent in intents:
            # extract value safely
            if isinstance(intent, PlanFeedbackIntent):
                value = intent.value
            elif hasattr(intent, "value"):
                value = str(intent.value)
            else:
                value = str(intent or "")

            value = value.strip()

            # remove prefix if exists
            if "." in value:
                value = value.split(".")[-1]

            value = value.strip().lower()

            # handle enum names like MORE_ADVANCED
            if value.upper() in PlanFeedbackIntent.__members__:
                value = PlanFeedbackIntent[value.upper()].value

            cleaned.append(value)

        try:
            return [PlanFeedbackIntent(v) for v in cleaned]
        except ValueError:
            valid = ", ".join(i.value for i in PlanFeedbackIntent)
            raise ValueError(f"Invalid feedback intent. Valid values: {valid}")

    @staticmethod
    def map_intents_to_instruction(intents: List[PlanFeedbackIntent]) -> str:
        if not intents:
            return ""

        intents = sorted(intents, key=lambda x: CLASS_INSTRUCTION_MAP.get(x, {}).get("priority", 99))

        instructions = []
        for intent in intents:
            entry = CLASS_INSTRUCTION_MAP.get(intent)
            if entry:
                instructions.append(entry["instruction"])

        return "\n".join(instructions)