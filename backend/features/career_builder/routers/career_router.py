from fastapi import APIRouter, HTTPException
from features.career_builder.services.career_service import CareerBuilderService
from features.career_builder.schemas import CareerPlanCreateSchema

router = APIRouter(prefix="/career", tags=["Career Builder"])
service = CareerBuilderService()

@router.get("/tracks")
async def get_tracks():
    """Fetch all available learning tracks"""
    tracks = service.get_all_tracks()
    return {"success": True, "tracks": tracks}

@router.post("/plans")
async def create_plan(plan_data: CareerPlanCreateSchema):
    """Create a new career development plan"""
    plan = service.create_plan(plan_data)
    return {"success": True, "plan": plan}

@router.get("/plans/{user_id}")
async def get_plan(user_id: str):
    """Fetch a user's career plan"""
    plan = service.get_plan(user_id)
    if not plan:
        raise HTTPException(status_code=404, detail="No career plan found")
    return {"success": True, "plan": plan}

@router.post("/plans/{user_id}/save")
async def save_plan(user_id: str):
    """Save the career plan"""
    updated = service.save_plan(user_id)
    if not updated:
        raise HTTPException(status_code=404, detail="Plan not found")
    return {"success": True, "plan": updated}

@router.post("/skills/select")
async def select_skill(user_id: str, plan_id: int, skill_id: int):
    """Select a skill from the plan"""
    result = service.select_skill(user_id, plan_id, skill_id)
    return {"success": True, "skill": result}
