"""
Application entrypoint for the AGRO FastAPI service.
Configures logging, exception handlers, CORS, and database migrations on startup.
"""

import logging
import subprocess
from app.db.session import SessionLocal
from app.db.seed.seed_all import seed_all
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.logging_config import setup_logging
from app.core.exceptions import register_exception_handlers
from app.api import router as api_router

# Initialize logging early
setup_logging()
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(title="AGRO")

# Register global exception handlers
register_exception_handlers(app)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: restrict origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router)


@app.on_event("startup")
def startup() -> None:
    """
    Startup event handler.
    Runs database migrations automatically.
    """
    # Generate new migration file (if needed)
    try:
        logger.info("🔄 Autogenerating migration...")
        # Uncomment the line below to enable auto-migration generation
        # subprocess.run(["alembic", "revision", "--autogenerate", "-m", "Auto migration"], check=True)
        logger.debug("Auto-migration generation step completed (skipped comment)")
    except subprocess.CalledProcessError as e:
        logger.warning(
            f"No migration changes detected or error during auto-generation: {e}"
        )

    # Apply migrations
    try:
        logger.info("⬆️  Applying migrations...")
        subprocess.run(["alembic", "upgrade", "head"], check=True)
        logger.info("Database migrations applied successfully")
    except subprocess.CalledProcessError as e:
        logger.exception(f"Error applying migrations: {e}")
        # Depending on your needs, you might want to stop the app if migrations fail:
        # raise

    # 2. Seed fallback data (only if enabled in settings)
    from app.core.config import settings

    if getattr(settings, "SEED_INITIAL_DATA", True):
        try:
            logger.info("Seeding fallback data...")
            db = SessionLocal()
            seed_all(db, created_by="admin@startup")
            db.close()
            logger.info("✅ Initial data seeded")
        except Exception as e:
            logger.exception("❌ Seeding initial data failed")
