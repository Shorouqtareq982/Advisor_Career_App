"""
abbreviation_detector.py
------------------------
A Python library for detecting abbreviations in text.

Detects:
  - Uppercase abbreviations         : NASA, FBI, CIA
  - Dotted abbreviations            : U.S.A., e.g., i.e., etc.
  - Mixed-case acronyms             : PhD, MSc, IoT, WiFi
  - Title abbreviations             : Mr., Dr., Prof., St.
  - Numeric abbreviations           : 1st, 2nd, Fig.1, No.5
  - Domain-specific abbreviations   : via a custom dictionary

Usage:
    from abbreviation_detector import AbbreviationDetector

    detector = AbbreviationDetector()
    results = detector.detect("NASA and the FBI work with the U.S.A. govt.")
    for abbr in results:
        print(abbr)
"""

import re
from dataclasses import dataclass
from typing import Optional


# ---------------------------------------------------------------------------
# Built-in dictionary of known abbreviations
# ---------------------------------------------------------------------------
KNOWN_ABBREVIATIONS: dict[str, str] = {
    # General
    "etc": "et cetera",
    "eg": "for example",
    "ie": "that is",
    "vs": "versus",
    "approx": "approximately",
    "dept": "department",
    "govt": "government",
    "mgmt": "management",
    "qty": "quantity",
    "ref": "reference",
    "est": "established / estimated",
    "max": "maximum",
    "min": "minimum",
    "avg": "average",
    "asap": "as soon as possible",
    "fyi": "for your information",
    "tbd": "to be determined",
    "tba": "to be announced",
    "rsvp": "répondez s'il vous plaît",
    "aka": "also known as",
    "diy": "do it yourself",
    "eta": "estimated time of arrival",
    "imo": "in my opinion",
    "imho": "in my humble opinion",
    "atm": "at the moment",
    "btw": "by the way",
    "faq": "frequently asked questions",
    # Titles
    "mr": "mister",
    "mrs": "missus",
    "ms": "miss",
    "dr": "doctor",
    "prof": "professor",
    "sr": "senior",
    "jr": "junior",
    "rev": "reverend",
    "st": "saint / street",
    "ave": "avenue",
    "blvd": "boulevard",
    # Government & organisations
    "nasa": "National Aeronautics and Space Administration",
    "fbi": "Federal Bureau of Investigation",
    "cia": "Central Intelligence Agency",
    "un": "United Nations",
    "who": "World Health Organization",
    "nato": "North Atlantic Treaty Organization",
    "ngo": "non-governmental organization",
    "ceo": "Chief Executive Officer",
    "cfo": "Chief Financial Officer",
    "cto": "Chief Technology Officer",
    "hr": "Human Resources",
    "it": "Information Technology",
    "pr": "Public Relations",
    "roi": "Return on Investment",
    "kpi": "Key Performance Indicator",
    # Countries & places
    "usa": "United States of America",
    "uk": "United Kingdom",
    "uae": "United Arab Emirates",
    "eu": "European Union",
    # Science & technology
    "ai": "Artificial Intelligence",
    "ml": "Machine Learning",
    "nlp": "Natural Language Processing",
    "api": "Application Programming Interface",
    "ui": "User Interface",
    "ux": "User Experience",
    "iot": "Internet of Things",
    "wifi": "Wireless Fidelity",
    "html": "HyperText Markup Language",
    "css": "Cascading Style Sheets",
    "sql": "Structured Query Language",
    "os": "Operating System",
    "cpu": "Central Processing Unit",
    "gpu": "Graphics Processing Unit",
    "ram": "Random Access Memory",
    "dna": "Deoxyribonucleic Acid",
    "rna": "Ribonucleic Acid",
    # Academic
    "phd": "Doctor of Philosophy",
    "msc": "Master of Science",
    "bsc": "Bachelor of Science",
    "mba": "Master of Business Administration",
    "gpa": "Grade Point Average",
    # Medical
    "er": "Emergency Room",
    "icu": "Intensive Care Unit",
    "bp": "Blood Pressure",
    "bmi": "Body Mass Index",
    "ecg": "Electrocardiogram",
    "mri": "Magnetic Resonance Imaging",
    # Units & measurements
    "km": "kilometre",
    "cm": "centimetre",
    "mm": "millimetre",
    "kg": "kilogram",
    "mg": "milligram",
    "ml": "millilitre",
    "hz": "hertz",
    "mhz": "megahertz",
    "ghz": "gigahertz",
    "gb": "gigabyte",
    "tb": "terabyte",
    "mb": "megabyte",
    "kb": "kilobyte",
}


# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------

# Dotted abbreviations: U.S.A.  e.g.  i.e.  etc.  Fig.1
_DOTTED = re.compile(
    r"\b(?:[A-Za-z]\.){2,}[A-Za-z]?\.?"   # U.S.A. or U.S.A
    r"|\b[A-Za-z]{1,5}\.\s*(?=[A-Z0-9])"  # Fig. 1, No. 5, St. John
)

# Uppercase abbreviations 2–7 letters: NASA, FBI, HTML, CPU
_UPPERCASE = re.compile(r"\b[A-Z]{2,7}\b")

# Mixed-case acronyms: PhD, MSc, IoT, WiFi, iPhone (capital + lowercase mix)
_MIXED = re.compile(r"\b[A-Z][a-z]{0,3}[A-Z][A-Za-z]{0,5}\b")

# Numeric abbreviations: 1st, 2nd, 3rd, 4th, Fig.1, No.5
_NUMERIC = re.compile(r"\b\d+(?:st|nd|rd|th)\b|\b(?:Fig|No|Vol|Sec|Ch)\.\s*\d+")

# Lowercase known abbreviations with period: etc. e.g. i.e. approx.
_LOWERCASE_DOT = re.compile(
    r"\b(etc|eg|ie|approx|dept|govt|mgmt|qty|ref|est|max|min|avg|asap|fyi|tbd|tba"
    r"|aka|diy|eta|imo|imho|atm|btw|faq|vs|mr|mrs|ms|dr|prof|sr|jr|rev|st|ave|blvd)\.",
    re.IGNORECASE,
)


# ---------------------------------------------------------------------------
# Data class for a detected abbreviation
# ---------------------------------------------------------------------------

@dataclass
class Abbreviation:
    text: str           # The abbreviation as found in text
    start: int          # Character start index
    end: int            # Character end index
    category: str       # Detection category
    definition: Optional[str] = None  # Known expansion, if any

    def __str__(self) -> str:
        defn = f' → "{self.definition}"' if self.definition else ""
        return f"[{self.category}] '{self.text}' (pos {self.start}–{self.end}){defn}"

    def to_dict(self) -> dict:
        return {
            "text": self.text,
            "start": self.start,
            "end": self.end,
            "category": self.category,
            "definition": self.definition,
        }


# ---------------------------------------------------------------------------
# Main detector class
# ---------------------------------------------------------------------------

class AbbreviationDetector:
    """
    Detects abbreviations in input text.

    Parameters
    ----------
    custom_dict : dict, optional
        Extra abbreviation → definition pairs to merge with the built-in dict.
    use_builtin_dict : bool
        Whether to use the built-in abbreviation dictionary (default True).
    min_length : int
        Minimum character length for an abbreviation to be reported (default 2).
    """

    def __init__(
        self,
        custom_dict: Optional[dict[str, str]] = None,
        use_builtin_dict: bool = True,
        min_length: int = 2,
    ):
        self.min_length = min_length
        self._dict: dict[str, str] = {}

        if use_builtin_dict:
            self._dict.update(KNOWN_ABBREVIATIONS)
        if custom_dict:
            self._dict.update({k.lower(): v for k, v in custom_dict.items()})

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def detect(self, text: str) -> list[Abbreviation]:
        """
        Detect all abbreviations in *text*.

        Returns a list of :class:`Abbreviation` objects sorted by position.
        Overlapping matches are deduplicated (longest match wins).
        """
        candidates: list[Abbreviation] = []

        for pattern, category in [
            (_DOTTED,       "dotted"),
            (_UPPERCASE,    "uppercase"),
            (_MIXED,        "mixed-case"),
            (_NUMERIC,      "numeric"),
            (_LOWERCASE_DOT,"lowercase-dot"),
        ]:
            for m in pattern.finditer(text):
                raw = m.group().strip()
                if len(raw) < self.min_length:
                    continue
                defn = self._lookup(raw)
                candidates.append(
                    Abbreviation(
                        text=raw,
                        start=m.start(),
                        end=m.end(),
                        category=category,
                        definition=defn,
                    )
                )

        return self._deduplicate(candidates)

    def detect_unique(self, text: str) -> list[Abbreviation]:
        """
        Like :meth:`detect` but returns only unique abbreviation texts
        (case-insensitive), keeping the first occurrence.
        """
        seen: set[str] = set()
        unique: list[Abbreviation] = []
        for abbr in self.detect(text):
            key = abbr.text.lower().strip(".")
            if key not in seen:
                seen.add(key)
                unique.append(abbr)
        return unique

    def summary(self, text: str) -> dict:
        """
        Return a summary dict with:
          - total_found
          - unique_count
          - by_category  (category → list of texts)
          - abbreviations (full Abbreviation objects)
        """
        all_abbrs = self.detect(text)
        unique = self.detect_unique(text)

        by_category: dict[str, list[str]] = {}
        for a in unique:
            by_category.setdefault(a.category, []).append(a.text)

        return {
            "total_found": len(all_abbrs),
            "unique_count": len(unique),
            "by_category": by_category,
            "abbreviations": all_abbrs,
        }

    def add_abbreviations(self, mapping: dict[str, str]) -> None:
        """Add or overwrite abbreviations in the detector's dictionary."""
        self._dict.update({k.lower(): v for k, v in mapping.items()})

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _lookup(self, text: str) -> Optional[str]:
        """Look up an abbreviation in the dictionary (case-insensitive)."""
        key = text.lower().rstrip(".")
        return self._dict.get(key)

    @staticmethod
    def _deduplicate(candidates: list[Abbreviation]) -> list[Abbreviation]:
        """Remove overlapping matches; prefer longer spans."""
        candidates.sort(key=lambda a: (a.start, -(a.end - a.start)))
        result: list[Abbreviation] = []
        last_end = -1
        for abbr in candidates:
            if abbr.start >= last_end:
                result.append(abbr)
                last_end = abbr.end
        return result


# ---------------------------------------------------------------------------
def detect_abbreviations(text: str, custom_dict: Optional[dict[str, str]] = None) -> list[str]:
    """
    Convenience function to detect abbreviations in a single call.

    Parameters
    ----------
    text : str
        The input text to analyze.
    custom_dict : dict, optional
        Extra abbreviation → definition pairs to merge with the built-in dict.

    Returns
    -------
    list of str
        A list of detected abbreviation texts.
    """
    detector = AbbreviationDetector(custom_dict=custom_dict)
    abbreviations = [abbr.text for abbr in detector.detect_unique(text)]
    return abbreviations