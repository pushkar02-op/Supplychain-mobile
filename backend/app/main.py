from app.core.logging_config import setup_logging

setup_logging()
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import router as api_router
import subprocess
from app.core.exceptions import register_exception_handlers

app = FastAPI(title="AGRO")
register_exception_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or specify ["http://localhost:3000"] etc.
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods
    allow_headers=["*"],  # Allow all headers
)

app.include_router(api_router)


@app.on_event("startup")
def startup():
    try:
        print("🔄 Autogenerating migration...")
        # subprocess.run(["alembic", "revision", "--autogenerate", "-m", "Auto migration"], check=True)
    except subprocess.CalledProcessError:
        print("⚠️  No changes or error during auto migration")

    print("⬆️  Applying migrations...")
    subprocess.run(["alembic", "upgrade", "head"], check=True)
