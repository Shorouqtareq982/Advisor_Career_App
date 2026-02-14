import os
from supabase import create_client, Client
from dotenv import load_dotenv
from pathlib import Path

# المسار الثابت لمجلد backend
backend_dir = Path(__file__).parent.parent.parent.parent  # 4 parents = backend/
env_path = backend_dir / '.env'

print(f"🔍 Loading .env from: {env_path}")
print(f"📁 File exists? {env_path.exists()}")

load_dotenv(dotenv_path=env_path)


class SupabaseClient:
    """
    Supabase client – loads credentials from .env and establishes connection.
    """

    def __init__(self):
        self.url = os.getenv("SUPABASE_URL")
        self.anon_key = os.getenv("SUPABASE_ANON_KEY")
        self.service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

        print(f"🔑 SUPABASE_URL: {'✅' if self.url else '❌'}")
        print(f"🔑 SUPABASE_ANON_KEY: {'✅' if self.anon_key else '❌'}")
        print(f"🔑 SUPABASE_SERVICE_ROLE_KEY: {'✅' if self.service_role_key else '❌'}")
        if not self.url or not self.anon_key:
            raise ValueError(
                "❌ Supabase credentials not found in .env file. "
                "Make sure SUPABASE_URL and SUPABASE_ANON_KEY are set."
            )

        try:
            self.client: Client = create_client(self.url, self.service_role_key or self.anon_key)
            print("✅ Supabase client initialized successfully.")
        except Exception as e:
            print(f"❌ Failed to connect to Supabase: {e}")
            raise

    def get_client(self) -> Client:
        return self.client

    def test_connection(self) -> bool:
        """Test connection by fetching one record from profiles table."""
        try:
            self.client.table("profiles").select("id").limit(1).execute()
            return True
        except Exception as e:
            print(f"⚠️ Connection test failed: {e}")
            return False


# Singleton instance
supabase_client = SupabaseClient()