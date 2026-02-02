# GROWZA Career Advisor - Backend

A FastAPI-based backend for an AI-powered career advisor platform.

## 🏗️ Project Structure

```
backend/
├── app/                          # Application entry point
│   ├── main.py                   # FastAPI app factory
│   └── routers.py                # (Optional) app-level router aggregation
│
├── core/                         # Core configuration
│   ├── config.py                 # Settings management (.env)
│   ├── dependencies.py           # Shared DI helpers (FastAPI dependencies)
│   └── security.py               # Auth utilities (e.g., token verification)
│
├── features/                     # Feature modules (vertical slices)
│   ├── ai_portfolio/             # Portfolio generation (ML)
│   ├── career_builder/           # Career planning
│   ├── cv_optimization/          # CV analysis & optimization
│   ├── job_matching/             # Job recommendations
│   ├── market_insights/          # Market analytics
│   └── mock_interview/           # Interview simulation
│       ├── routers/              # FastAPI endpoints (APIRouter) 
│       ├── schemas/              # Pydantic request/response contracts
│       ├── services/             # Business logic & orchestration
│       ├── repositories/         # CRUD operations
│       └── ml_models/            # ML-specific code/models 
│
├── users/                        # User module 
│   ├── schemas/                  # Pydantic request/response contracts
│   ├── services/                 # Business logic
│   └── repositories/                # Domain/persistence models
│
├── integrations/                 # External services
│   ├── firebase/                 # Firebase Admin integration (token verification, etc.)
│   ├── providers/                # APIs/LLM providers
│   ├── storage/                  # Storage abstraction (Azure, Cloudinary, etc.)
│   ├── supabase/                 # Supabase client (DB + Auth + Storage)
│   ├── azure_blob/               # Azure Blob client
│   └── cloudinary/               # Cloudinary client
│
├── shared/                       # Shared utilities
│   ├── helpers/                  # Common helpers 
│   ├── repositories/             # Shared data-access/repositories 
│   ├── schemas/                  # Shared Pydantic schemas 
│   └── providers/                # Shared providers 
│
└── tests/                        # Test suite
    ├── conftest.py               # Test fixtures
    └── test_*.py                 # Test files
```

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Supabase project (URL + Key)
- Firebase project (if using Firebase Auth)
- Docker (optional)

### Installation

1. **Clone and navigate to backend:**
   ```bash
   cd Advisor_Career_App/backend
   ```

2. **Create virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # Linux/Mac
   venv\Scripts\activate     # Windows
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

5. **Start development server:**
   ```bash
   uvicorn app.main:app --reload
   ```

### Docker Setup

```bash
cd ../infra/docker
docker-compose up -d
```

Access:
- API: http://localhost:8000
- Docs: http://localhost:8000/api/v1/docs

Note: If you are using Supabase as your only database, you typically do not need local Postgres or Alembic migrations.

## 📚 API Documentation

- **Swagger UI**: `/api/v1/docs`
- **ReDoc**: `/api/v1/redoc`
- **OpenAPI JSON**: `/api/v1/openapi.json`

## 🧪 Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific test file
pytest tests/test_users.py
```

## 🔧 Development

### Code Style
```bash
# Format code
black .
isort .

# Lint
flake8
mypy .
```

### Database / Persistence
This project is structured to work with Supabase. If you later choose to manage schema migrations, use Supabase's tooling/workflows.

## 📦 Features

| Feature | Description |
|---------|-------------|
| **Users** | Authentication, profiles, settings |
| **CV Optimization** | ATS analysis, keyword optimization |
| **Job Matching** | AI-powered job recommendations |
| **Mock Interview** | Interview simulation with feedback |
| **Career Builder** | Career path planning |
| **Market Insights** | Salary & skill trends |
| **AI Portfolio** | AI-generated portfolios |

## 🔐 Environment Variables

See `.env.example` for all available configuration options.

## 📄 License

MIT License - See LICENSE file for details.
