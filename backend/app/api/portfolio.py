from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPBearer

from features.ai_portfolio.models.portfolio_data import PortfolioData
from features.ai_portfolio.services.export_service import export_service
from features.ai_portfolio.services.portfolio_service import PortfolioService
from features.ai_portfolio.services.template_service import TemplateService
from shared.providers.storage.cloudinary import CloudinaryProvider, get_cloudinary_provider

router = APIRouter(
    prefix="/portfolio",
    tags=["Portfolio"],
    dependencies=[Depends(HTTPBearer())],
)


def _get_current_user_id(request: Request) -> str:
    user = request.state.user
    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return user["sub"]


# Templates
@router.get("/templates")
async def get_templates():
    templates = TemplateService.get_templates()
    return {
        "templates": [template.model_dump() for template in templates]
    }


@router.get("/preview_template/{template_id}")
async def get_template(template_id: int):
    template = TemplateService.preview_template_by_id(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    return HTMLResponse(content=template)


# Media
@router.post("/upload-image")
async def upload_image(
    image: UploadFile = File(...),
    storage: CloudinaryProvider = Depends(get_cloudinary_provider),
):
    result = storage.upload_file(image.file, image.filename, folder="portfolio_images")
    return {
        "file_url": result.get("url"),
        "public_id": result.get("public_id"),
    }


# Preview
@router.get("/preview/{portfolio_id}")
async def preview_portfolio(portfolio_id: str):
    rendered_html = await PortfolioService.preview_portfolio(portfolio_id)
    if not rendered_html:
        raise HTTPException(status_code=404, detail="Portfolio not found")

    return HTMLResponse(content=rendered_html)


# CRUD
@router.post("/")
async def create_portfolio(request: Request, data: PortfolioData):
    user_id = _get_current_user_id(request)
    portfolio = await PortfolioService.create_portfolio(user_id=user_id, data=data)
    return portfolio


@router.put("/{portfolio_id}")
async def update_portfolio(portfolio_id: str, data: PortfolioData):
    portfolio = await PortfolioService.update_portfolio(portfolio_id=portfolio_id, data=data)
    return portfolio


@router.get("/user/")
async def get_user_portfolios(request: Request):
    user_id = _get_current_user_id(request)
    portfolios = await PortfolioService.get_user_portfolios(user_id)
    return portfolios


@router.get("/last_saved_data")
async def get_last_saved_portfolio_data(request: Request):
    user_id = _get_current_user_id(request)
    data = await PortfolioService.get_last_saved_portfolio_data(user_id)
    if not data:
        raise HTTPException(status_code=404, detail="No saved portfolio data found for this user")

    return data


@router.get("/{portfolio_id}")
async def get_portfolio(portfolio_id: str):
    portfolio = await PortfolioService.get_portfolio(portfolio_id)
    if not portfolio:
        raise HTTPException(status_code=404, detail="Portfolio not found")

    return portfolio


@router.delete("/{portfolio_id}")
async def delete_portfolio(portfolio_id: str):
    await PortfolioService.delete_portfolio(portfolio_id)
    return {
        "success": True,
        "message": "Portfolio deleted successfully",
    }


# Publishing
@router.post("/{portfolio_id}/publish")
async def publish_portfolio(portfolio_id: str):
    result = await PortfolioService.publish_portfolio(portfolio_id)
    return result


@router.post("/{portfolio_id}/unpublish")
async def unpublish_portfolio(portfolio_id: str):
    await PortfolioService.unpublish_portfolio(portfolio_id)
    return {
        "success": True,
        "message": "Portfolio unpublished",
    }


@router.post("/{portfolio_id}/export/pdf")
async def export_portfolio_as_pdf(portfolio_id: str):
    pdf_url = await export_service.export_portfolio_as_pdf(portfolio_id)
    if not pdf_url:
        raise HTTPException(status_code=404, detail="Portfolio not found")

    return {
        "pdf_url": pdf_url
    }