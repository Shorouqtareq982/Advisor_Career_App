# backend/shared/providers/__init__.py
from .supabase.client import supabase_client
from .supabase.database import db

__all__ = ['supabase_client', 'db']