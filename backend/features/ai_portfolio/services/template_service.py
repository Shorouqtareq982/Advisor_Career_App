from pydantic import BaseModel

from features.ai_portfolio.models.portfolio_data import EducationItem, ExperienceItem, PortfolioData, ProjectItem
from .render_service import RenderService

class TemplateService:
    class Template(BaseModel):
        id: int
        name: str
        description: str
        thumbnail_url: str
        file_path: str    
        content: str | None = None    

    @staticmethod
    def get_default_data():
        data = PortfolioData(
            name= "John Doe",
            title= "Software Engineer",
            about= "Passionate software engineer with experience in building web applications.",
            email= "john.doe@example.com",
            phone= "+1 234 567 890",
            location= "San Francisco, CA",
            github= "https://github.com/johndoes",
            linkedin= "https://linkedin.com/in/johndoes",
            twitter= "https://twitter.com/johndoes",
            selected_template= 1,
            skills= ["Python", "JavaScript", "React", "Django"],
            languages= ["English", "Spanish"],
            experiences = [
                ExperienceItem(
                    job_title="Software Engineer",
                    company="Tech Company",
                    location="San Francisco, CA",
                    period="Jan 2020 - Present",
                    description="Working on developing and maintaining web applications."
                ),
                ExperienceItem(
                    job_title="Intern",
                    company="Startup Inc.",
                    location="San Francisco, CA",
                    period="Jun 2019 - Aug 2019",
                    description="Assisted in developing a mobile application for e-commerce."
                )
            ],
            education = [
                EducationItem(
                    degree="Bachelor of Science",
                    field="Computer Science",
                    institution="University of Technology",
                    location="San Francisco, CA",
                    period="2016 - 2020",
                    description="Studied computer science with a focus on software development."
                )
            ],
            projects = [
                ProjectItem(
                    name="Personal Portfolio Website",
                    description="A personal portfolio website built with React and Django.",
                    technologies="React, Django, PostgreSQL",
                    link="https://github.com/johndoe/personal-portfolio"
                ),
                ProjectItem(
                    name="E-commerce Mobile App",
                    description="A mobile application for e-commerce built with React Native.",
                    technologies="React Native, Node.js, MongoDB",
                    link="https://github.com/johndoe/e-commerce-mobile-app"
                )
            ],
            profile_image_url= "https://res.cloudinary.com/dyntjyjqn/image/private/s--P6w0phtM--/v1777156589/portfolio_images/0abdcb4d595060b1.png",
        )
        return data

        
    @staticmethod
    def get_templates():
        # In a real implementation, this could fetch templates from a database or filesystem
        templates = [
            TemplateService.Template(
                id=1,
                name="Personal Modern",
                description="A clean and modern template for personal portfolios.",
                thumbnail_url="/static/templates/personal_modern/thumbnail.png",
                file_path="personal_modern"
            ),
            TemplateService.Template(
                id=2,
                name="IPortfolio",
                description="A sleek and professional template designed for showcasing projects and experience.",
                thumbnail_url="/static/templates/personal_modern/thumbnail.png",
                file_path="iportfolio"
            ),
            TemplateService.Template(
                id=3,
                name="Clean Minimalist",
                description="A minimalist template with a focus on content and simplicity.",
                thumbnail_url="/static/templates/personal_modern/thumbnail.png",
                file_path="clean_minimal"
            ),
            TemplateService.Template(
                id=4,
                name="Creative Dark",
                description="A bold and creative template with a dark theme.",
                thumbnail_url="/static/templates/creative_dark/thumbnail.png",
                file_path="creative_dark"
            ),

        ]
        return templates
    
    @staticmethod
    def preview_template_by_id(template_id: int):
        templates = TemplateService.get_templates()
        render_service = RenderService()
        for template in templates:
            if template.id == template_id:
                data = TemplateService.get_default_data()
                return render_service.render_portfolio(data, template.id)

        return None
    
    @staticmethod
    async def get_template_path(template_id: int):
        templates = TemplateService.get_templates()
        for template in templates:
            if template.id == template_id:
                return template.file_path
        return None