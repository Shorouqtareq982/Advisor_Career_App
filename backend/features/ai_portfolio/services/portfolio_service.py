# app/services/portfolio_service.py

from datetime import datetime
import re

from features.ai_portfolio.services.render_service import RenderService

from ..models.portfolio_data import PortfolioData
from ..repositories.portfolio_repo import PortfolioRepository
from .export_service import export_service

portfolio_repo = PortfolioRepository()


class PortfolioService:

    @staticmethod
    async def preview_portfolio(portfolio_id: str):
        portfolio = await portfolio_repo.get_portfolio(portfolio_id)
        if not portfolio:
            return None
        rendered_html = RenderService.render_portfolio(
            portfolio=portfolio["data"],
            template_id=portfolio["template_index"],
        )

        return rendered_html

    @staticmethod
    async def create_portfolio(
        user_id: str,
        data: PortfolioData,
    ):
        payload = {
            "user_id": user_id,
            "title": f"{data.name} Portfolio" if data.name else "My Portfolio",
            "template_index": data.selected_template,
            "data": data.model_dump(),
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat(),
        }

        return await portfolio_repo.create_portfolio(payload)

    @staticmethod
    async def update_portfolio(
        portfolio_id: str,
        data: PortfolioData,
    ):
        payload = {
            "title": f"{data.name} Portfolio" if data.name else "My Portfolio",
            "template_index": data.selected_template,
            "data": data.model_dump(),
            "updated_at": datetime.utcnow().isoformat(),
        }

        updated_portfolio = await portfolio_repo.update_portfolio(portfolio_id, payload)
        if updated_portfolio["is_published"]:
            rendered_html = RenderService.render_portfolio(
                portfolio=updated_portfolio["data"],
                template_id=updated_portfolio["template_index"],
            )
            slug = updated_portfolio["public_slug"] if updated_portfolio["public_slug"] else PortfolioService.generate_slug(updated_portfolio["title"] if updated_portfolio["title"] else f"portfolio-{portfolio_id}")
            await export_service.export_to_cloudflare(rendered_html, slug)
    @staticmethod
    async def get_portfolio(portfolio_id: str):
        portfolio =  await portfolio_repo.get_portfolio(portfolio_id)
        if not portfolio:
            return None
        return portfolio

    @staticmethod
    async def get_user_portfolios(user_id: str):
        return await portfolio_repo.get_user_portfolios(user_id)

    @staticmethod
    async def delete_portfolio(portfolio_id: str):
        portfolio = await portfolio_repo.get_portfolio(portfolio_id)
        if not portfolio:
            return None
        if portfolio["is_published"]:
            await export_service.delete_from_cloudflare(portfolio["public_slug"])
        return await portfolio_repo.delete_portfolio(portfolio_id)

    @staticmethod
    async def publish_portfolio(portfolio_id: str):
        portfolio = await portfolio_repo.get_portfolio(portfolio_id)
        if not portfolio:
            return None
        rendered_html = RenderService.render_portfolio(
            portfolio=portfolio["data"],
            template_id=portfolio["template_index"],
        )
        slug = PortfolioService.generate_slug(portfolio["title"] if portfolio["title"] else f"portfolio-{portfolio_id}")
        url = await export_service.export_to_cloudflare(rendered_html, slug)
        result = await portfolio_repo.publish_portfolio(portfolio_id, slug)

        return url

    @staticmethod
    async def unpublish_portfolio(portfolio_id: str):
        portfolio = await portfolio_repo.get_portfolio(portfolio_id)
        if not portfolio:
            return None
        if portfolio["is_published"]:
            await export_service.delete_from_cloudflare(portfolio["public_slug"])
        return await portfolio_repo.unpublish_portfolio(portfolio_id)
    
    @staticmethod
    async def get_last_saved_portfolio_data(user_id: str):
        print("Fetching last saved portfolio data for user:", user_id)
        return await portfolio_repo.get_last_saved_portfolio_data(user_id)
    
    @staticmethod
    def generate_slug(name: str):

        slug = name.lower()
        slug = re.sub(r'[^a-z0-9]+', '-', slug)
        slug = slug.strip("-")

        return slug