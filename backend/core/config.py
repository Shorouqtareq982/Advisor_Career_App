"""
Application Configuration Settings
"""
from typing import List, Optional
from pathlib import Path
from pydantic import Field
from pydantic_settings import BaseSettings
from functools import lru_cache

# Get the backend directory (parent of core/)
BACKEND_DIR = Path(__file__).parent.parent
ENV_FILE = BACKEND_DIR / ".env"


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    PROJECT_NAME: str = "GROWZA Career Advisor"
    VERSION: str = "1.0.0"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"

    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production"
    SUPABASE_JWT_SECRET: str = ""
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ALGORITHM: str = "HS256"

    # CORS
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8000"]

    # Database
    DATABASE_URL: str = ""

    # Supabase
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # Azure Blob Storage
    AZURE_STORAGE_CONNECTION_STRING: str = ""
    AZURE_CONTAINER_NAME: str = ""
    AZURE_AUDIO_CONTAINER_NAME: str = ""
    STORAGE_ACCOUNT_NAME: str = ""
    STORAGE_ACCOUNT_KEY: str = ""

    # Cloudinary
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # AI/ML Services
    LLM_PROVIDER: str = ""
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = ""
    GEMINI_EMBEDDING_MODEL: str = ""
    GEMINI_REQUEST_DELAY_SECONDS: float = 2.0
    ASSEMBLYAI_API_KEY: str = Field(default="", validation_alias="AssemblyAI_API_KEY")
    ELEVENLABS_API_KEY: str = Field(default="", validation_alias="ElevenLabs_API_KEY")
    OPENAI_API_KEY: str = ""
    MISTRAL_API_KEY: Optional[str] = None
    MISTRAL_MODEL: Optional[str] = None
    #GitHub
    GITHUB_TOKEN: Optional[str] = None
    PORTFOLIO_GITHUB_TOKEN: Optional[str] = None
    PORTFOLIO_REPO_NAME: Optional[str] = None
    # Resource APIs
    YOUTUBE_API_KEY: Optional[str] = None
    SERPAPI_API_KEY: Optional[str] = None
    TAVILY_API_KEY: Optional[str] = None
    OPENROUTER_API_KEY: Optional[str] = None
    OPENROUTER_MODEL: Optional[str] = None
    # External APIs
    JOB_API_BASE_URL: str = ""
    JOB_API_KEY: str = ""

    # Celery
    CELERY_BROKER_URL: str = ""
    CELERY_RESULT_BACKEND: str = ""
    
    
    class Config:
        env_file = str(ENV_FILE)
        env_file_encoding = "utf-8"
        case_sensitive = True
        extra = "ignore"


def get_settings() -> Settings:
    """Get settings instance (fresh read from .env each time)."""
    return Settings()


# Don't cache settings - reload from .env on each call
settings = get_settings()