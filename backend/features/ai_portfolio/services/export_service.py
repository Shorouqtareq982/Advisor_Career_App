
import asyncio
from core.config import settings
from features.ai_portfolio.repositories.portfolio_repo import portfolio_repo
from features.ai_portfolio.services.render_service import RenderService
from shared.providers.storage.cloudinary import get_cloudinary_provider
from io import BytesIO
from git import Repo
from github import Github
from playwright.sync_api import sync_playwright

class ExportService:
    def __init__(self):
        self.GITHUB_TOKEN=settings.PORTFOLIO_GITHUB_TOKEN
        self.REPO_NAME=settings.PORTFOLIO_REPO_NAME
        self.g = Github(self.GITHUB_TOKEN)


    async def export_to_cloudflare(self, html_content: str, slug: str):
        # Create a new repository
        user = self.g.get_user()
        repo = user.get_repo(self.REPO_NAME)

        # Add the rendered HTML as an index.html file in the repository
        repo.create_file(f"{slug}.html", "Add portfolio HTML file", html_content)

        return f"https://growza-portfolios.pages.dev/{slug}"
    
    async def update_cloudflare(self, html_content: str, slug: str):
        user = self.g.get_user()
        repo = user.get_repo(self.REPO_NAME)

        # Find the file in the repository
        contents = repo.get_contents(f"{slug}.html")
        repo.update_file(contents.path, "Update portfolio HTML file", html_content, contents.sha)

    async def delete_from_cloudflare(self, slug: str):
        user = self.g.get_user()
        repo = user.get_repo(self.REPO_NAME)

        # Find the file in the repository
        contents = repo.get_contents(f"{slug}.html")
        repo.delete_file(contents.path, "Delete portfolio HTML file", contents.sha)
        

    @staticmethod
    def _generate_pdf_bytes_sync(rendered_html: str) -> bytes:
        """Generate PDF using Playwright sync API to avoid asyncio subprocess limitations."""
        with sync_playwright() as p:
            browser = p.chromium.launch()
            page = browser.new_page()
            page.set_content(rendered_html)
            # Wait for fonts/images to finish loading before snapshotting.
            page.wait_for_timeout(2000)
            pdf_bytes = page.pdf(format="A3", print_background=True)
            browser.close()
            return pdf_bytes
    
    async def export_portfolio_as_pdf(self, portfolio_id: str):
        portfolio = await portfolio_repo.get_portfolio(portfolio_id)
        if not portfolio:
            return None

        rendered_html = RenderService.render_portfolio(
            portfolio=portfolio["data"],
            template_id=portfolio["template_index"],
        )

        pdf_bytes = await asyncio.to_thread(self._generate_pdf_bytes_sync, rendered_html)

        # Upload PDF bytes to Cloudinary and return the file URL.
        cloudinary_provider = get_cloudinary_provider()
        pdf_file = BytesIO(pdf_bytes)
        result = cloudinary_provider.upload_file(
            file=pdf_file,
            folder="portfolio_pdfs",
            filename=f"{portfolio['title']}.pdf"
        )
        return result['url']

export_service = ExportService()