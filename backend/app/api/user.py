
from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPBearer
from pydantic import BaseModel
from shared.providers.supabase import supabase_client

router = APIRouter(prefix="/user", tags=["User Management"])

class User(BaseModel):
    email: str
    password: str

class UserSignUpRequest(User):
    username: str
    phone:str


security = HTTPBearer()

@router.get("/me", dependencies=[Depends(security)])
async def read_current_user(request: Request):
    user = request.state.user
    if not user:
        return {"user": None}
    return {"user": user}

@router.post("/register")
async def register_user(user: UserSignUpRequest):
    client = supabase_client.get_client()
    response = client.auth.admin.create_user({
        "email": user.email,
        "password": user.password,
        "email_confirm": True,
        "user_metadata": {
            "username": user.username,
            "phone": user.phone
        }
    })
    
    return response

@router.post("/login")
async def login_user(user: User):
    client = supabase_client.get_client()
    response = client.auth.sign_in_with_password({
        "email": user.email,
        "password": user.password
    })

    return response