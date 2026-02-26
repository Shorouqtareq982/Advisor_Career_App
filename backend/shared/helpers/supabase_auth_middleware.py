from fastapi import Request
from jose import JWTError
import jwt
from starlette.middleware.base import BaseHTTPMiddleware
from core.config import settings

class SupabaseAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        auth_header = request.headers.get("Authorization")

        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            try:
                payload = self.verify_token(token)
                request.state.user = payload
            except Exception as e:
                print(f"Token verification failed: {e}")
                request.state.user = None
        else:
            request.state.user = None

        response = await call_next(request)
        return response

    def verify_token(self, token: str):
        """Verify and decode JWT token using Supabase's JWT secret."""
        try:
            payload = jwt.decode(
                token, settings.SUPABASE_JWT_SECRET, algorithms=[settings.ALGORITHM], audience="authenticated"
            )
            return payload
        except JWTError:
            return None