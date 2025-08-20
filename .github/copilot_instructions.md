# Copilot Instructions for SupplyChain-Mobile Repository

## Repository Overview

This repository is a supply chain management system designed to support multi-company and multi-mart operations. It includes a FastAPI backend for API services and a Flutter-based mobile frontend. The backend integrates with PostgreSQL for data storage and uses Alembic for database migrations. The mobile app is cross-platform, targeting Android, iOS, and desktop environments.

### Key Technologies

- **Backend**: FastAPI, SQLAlchemy, Alembic, PostgreSQL
- **Frontend**: Flutter, Dart
- **Infrastructure**: Docker, Terraform
- **Testing**: Pytest

## Build and Validation Instructions

### Backend

1. **Environment Setup**:

   - Install Python 3.11+.
   - Create and activate a virtual environment:
     ```powershell
     python -m venv venv
     & "venv\Scripts\Activate.ps1"
     ```
   - Install dependencies:
     ```powershell
     pip install -r backend/requirements.txt
     ```

2. **Database Setup**:

   - Ensure Docker is installed and running.
   - Start the database service:
     ```powershell
     docker-compose up db
     ```
   - Apply migrations:
     ```powershell
     docker-compose exec backend alembic upgrade head
     ```

3. **Run the Backend**:

   - Start the FastAPI server:
     ```powershell
     uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
     ```

4. **Run Tests**:
   - Execute tests using Pytest:
     ```powershell
     pytest
     ```

### Frontend

1. **Environment Setup**:

   - Install Flutter (latest stable version).
   - Run `flutter doctor` to verify the setup.

2. **Build and Run**:

   - For Android:
     ```powershell
     flutter build apk --release
     flutter install
     ```
   - For iOS:
     ```bash
     flutter build ios --release
     ```
   - For Web:
     ```powershell
     flutter build web
     ```

3. **Run Tests**:
   - Execute Flutter widget tests:
     ```powershell
     flutter test
     ```

## Project Layout

### Backend

- **Main Application**: `backend/app/main.py`
- **API Endpoints**: `backend/app/api/`
- **Database Models**: `backend/app/db/models/`
- **Services**: `backend/app/services/`
- **Utilities**: `backend/app/utils/`
- **Migrations**: `backend/alembic/`

### Frontend

- **Main Entry Point**: `mobile/lib/main.dart`
- **Screens**: `mobile/lib/screens/`
- **Services**: `mobile/lib/services/`
- **Widgets**: `mobile/lib/widgets/`

### Infrastructure

- **Docker Configuration**: `docker-compose.yml`
- **Terraform Modules**: `terraform/modules/`

## GitHub Workflows

- **EC2 Deployment**: `.github/workflows/ec2-deploy.yml`

## Notes for AI Agents

- Always ensure the database service is running before backend operations.
- Use the provided `docker-compose.yml` for consistent environment setup.
- Follow the project layout to locate relevant files for changes.
- Validate changes by running tests and ensuring no errors in the CI pipeline.
- Trust these instructions unless explicitly incomplete or incorrect.
- Prefer **async endpoints** but synchronous DB calls via SQLAlchemy.
- Stick to snake_case for Python, camelCase for JSON response fields.
- Keep code modular: routes → services → models/schemas.

## Coding Guidelines

1. Always use **FastAPI routers** under `app/api/v1/`.
2. Database models are in `app/db/models/`, schemas in `app/db/schemas/`, services in `app/services/`.
3. Use **Pydantic schemas** for request/response validation.
4. Every major table must include auditing fields: `created_at`, `created_by`, `updated_at`, `updated_by`.
5. Database credentials and secrets must always come from `.env`, never hardcoded.
6. Use **Alembic migrations** for schema changes.
7. API routes must be versioned (e.g., `/v1/stock/`).
