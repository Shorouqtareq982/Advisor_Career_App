from backend.helpers.config import get_settings
from supabase import create_client

settings = get_settings()

supabase = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_KEY
)
