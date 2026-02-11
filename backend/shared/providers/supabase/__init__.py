# backend/shared/providers/supabase/__init__.py
from .client import supabase_client
from .database import db

__all__ = ['supabase_client', 'db']