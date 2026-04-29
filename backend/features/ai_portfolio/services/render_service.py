# app/services/render_service.py

from fastapi import UploadFile
from jinja2 import Environment, FileSystemLoader, select_autoescape

from ..models.portfolio_data import PortfolioData


env = Environment(
    loader=FileSystemLoader("features/ai_portfolio/templates"),
    autoescape=select_autoescape(["html", "xml"]),
)


class RenderService:

    @staticmethod
    def render_portfolio(
        portfolio: PortfolioData,
        template_id: int = 1,
    ):
        template_paths = {
            1: "personal_modern",
            2: "iportfolio",
            3: "clean_minimal",
            4: "creative_dark",
        }
        template_path = template_paths.get(template_id, "personal_modern")

        template = env.get_template(
            f"{template_path}/index.html"
        )

        html = template.render(
            portfolio=portfolio,
        )

        return html