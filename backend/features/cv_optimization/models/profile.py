from typing import Optional, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field


class Profile(BaseModel):
    id: Optional[UUID] = None
    email: Optional[str] = None
    username: str
    display_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    provider: str = "email"
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    full_name: Optional[str] = None