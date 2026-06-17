import re
from datetime import datetime, timedelta
from typing import Optional, Tuple


def normalize_date(text: str) -> Optional[str]:
    """Normalize date strings to YYYY-MM-DD format."""
    if not text:
        return None

    text = str(text).lower().strip()

    match = re.search(r"\d{4}-\d{2}-\d{2}", text)
    if match:
        return match.group(0)

    try:
        if "t" in text:
            return datetime.fromisoformat(text.replace("z", "")).strftime("%Y-%m-%d")
    except:
        pass

    today = datetime.today()

    if "hour" in text or "minute" in text or "just" in text:
        return today.strftime("%Y-%m-%d")

    match = re.search(r"(\d+)\s*(day|days|week|weeks|month|months)", text)
    if match:
        value = int(match.group(1))
        unit = match.group(2)

        if "week" in unit:
            delta = timedelta(weeks=value)
        elif "month" in unit:
            delta = timedelta(days=value * 30)
        else:
            delta = timedelta(days=value)

        return (today - delta).strftime("%Y-%m-%d")

    return None


def extract_experience(text: str) -> Tuple[Optional[int], Optional[int], Optional[float]]:
    """Extract experience range from text."""
    text = str(text)

    match = re.search(r"(\d+)\s*-\s*(\d+)", text)
    if match:
        mn = int(match.group(1))
        mx = int(match.group(2))
        return mn, mx, (mn + mx) / 2

    match = re.search(r"(\d+)\+", text)
    if match:
        v = int(match.group(1))
        return v, v, float(v)

    return None, None, None


def get_experience_level(raw_exp: str, avg_exp: Optional[float], title: str = "") -> str:
    """Determine experience level based on experience data."""
    txt = (raw_exp + " " + title).lower()

    if "entry" in txt or (avg_exp is not None and avg_exp <= 2):
        return "Entry Level"
    elif "junior" in txt or (avg_exp is not None and 1 <= avg_exp <= 3):
        return "Junior"
    elif "mid" in txt or (avg_exp is not None and 3 <= avg_exp <= 5):
        return "Mid Level"
    elif "senior" in txt or (avg_exp is not None and 5 <= avg_exp <= 10):
        return "Senior"
    elif "lead" in txt or "manager" in txt or (avg_exp is not None and avg_exp > 10):
        return "Expert"
    else:
        return "Not Specified"


def extract_governorate(location_text: str) -> str:
    """Extract governorate from location text."""
    parts = [p.strip() for p in str(location_text).split(",")]
    if len(parts) >= 2:
        return parts[-2]
    return parts[0]


# Translation dictionary for Egyptian governorates
GOV_TRANSLATION = {
    "القاهرة": "Cairo",
    "الجيزة": "Giza",
    "الإسكندرية": "Alexandria",
    "اسكندرية": "Alexandria",
    "الدقهلية": "Dakahlia",
    "الشرقية": "Sharqia",
    "الغربية": "Gharbia",
    "المنوفية": "Monufia",
    "القليوبية": "Qalyubia",
    "البحيرة": "Beheira",
    "بورسعيد": "Port Said",
    "السويس": "Suez",
    "الاسماعيلية": "Ismailia",
    "الإسماعيلية": "Ismailia",
    "أسيوط": "Asyut",
    "سوهاج": "Sohag",
    "قنا": "Qena",
    "الأقصر": "Luxor",
    "أسوان": "Aswan",
    "بني سويف": "Beni Suef",
    "الفيوم": "Faiyum",
    "مطروح": "Matrouh",
    "شمال سيناء": "North Sinai",
    "جنوب سيناء": "South Sinai",
    "المنيا": "Minya",
    "دمياط": "Damietta",
    "البحر الأحمر": "Red Sea",
    "البحر الاحمر": "Red Sea"
}


def normalize_governorate(gov: str) -> Optional[str]:
    """Normalize governorate name using translation dictionary."""
    if not gov:
        return None
    gov = gov.strip()
    return GOV_TRANSLATION.get(gov, gov)


def init_state(state: Optional[dict], sheet: str) -> dict:
    """Initialize crawler state for a sheet."""
    if state is None:
        state = {}

    if sheet not in state:
        state[sheet] = {}

    state[sheet]["wuzzuf"] = {
        "page": state[sheet].get("wuzzuf", {}).get("page", 0),
        "last_good_page": state[sheet].get("wuzzuf", {}).get("last_good_page", 0),
        "retry": state[sheet].get("wuzzuf", {}).get("retry", 0)
    }

    state[sheet]["adzuna"] = {
        "page": state[sheet].get("adzuna", {}).get("page", 1),
        "last_good_page": state[sheet].get("adzuna", {}).get("last_good_page", 1),
        "retry": state[sheet].get("adzuna", {}).get("retry", 0)
    }

    return state