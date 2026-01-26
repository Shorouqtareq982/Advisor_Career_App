from fastapi import FastAPI, APIRouter, Depends
import os
from helpers.config import get_settings, Settings

router = APIRouter()

@router.get("/")
async def welcome(app_settings: Settings = Depends(get_settings)):

    app_name = app_settings.APP_NAME

    return {
        "message": f"Welcome to {app_name} API!"
    }