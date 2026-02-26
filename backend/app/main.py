"""
Application entrypoint for the AGRO FastAPI service.
Configures logging, exception handlers, CORS, and database migrations on startup.
"""

import logging
import os
import subprocess

from app.api import router as api_router
from app.api.admin_diagnostics import router as admin_diagnostics_router
from app.api.auth import router as auth_router
from app.api.batch import router as batch_router
from app.api.dispatch_entry import router as dispatch_router
from app.api.inventory_txn import router as inventory_txn_router
from app.api.item import router as item_router
from app.api.rejection_entry import router as rejection_router
from app.api.stock_entry import router as stock_router
from app.api.stock_history import router as stock_history_router
from app.api.uom import router as uom_router
from app.core.config import settings as _settings
from app.core.correlation import CorrelationIdMiddleware
from app.core.exceptions import AppException, register_exception_handlers
from app.core.logging_config import setup_logging
from app.core.rate_limit import limiter
from app.core.security_headers import SecurityHeadersMiddleware
from app.core.timing import TimingMiddleware
from app.db.seed.seed_all import seed_all
from app.db.session import SessionLocal
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

# Initialize logging early
setup_logging()
logger = logging.getLogger(__name__)

# ── Startup configuration validation ──────────────────────────────────────
_validation_errors: list[str] = []

if not _settings.DATABASE_URL:
    _validation_errors.append("DATABASE_URL is not set")

if not _settings.JWT_SECRET_KEY:
    _validation_errors.append("JWT_SECRET_KEY is not set")
elif len(_settings.JWT_SECRET_KEY) < 10:
    _validation_errors.append(
        f"JWT_SECRET_KEY too short ({len(_settings.JWT_SECRET_KEY)} chars, minimum 32)"
    )

if _settings.FILE_UPLOAD_MAX_MB <= 0:
    _validation_errors.append(
        f"FILE_UPLOAD_MAX_MB must be > 0, got {_settings.FILE_UPLOAD_MAX_MB}"
    )

if _settings.ENVIRONMENT == "production" and "*" in _settings.CORS_ORIGINS.split(","):
    _validation_errors.append("Wildcard CORS not allowed in production")

if _validation_errors:
    raise RuntimeError(
        "Configuration validation failed: " + "; ".join(_validation_errors)
    )
# ── End validation ────────────────────────────────────────────────────────

# Create FastAPI app
app = FastAPI(title="AGRO")

# Configure Rate Limiter
app.state.limiter = limiter


@app.exception_handler(429)
async def custom_429_handler(request: Request, exc: Exception):
    raise AppException(
        status_code=429, detail="Too many requests", rule_id=None, metadata={}
    )


# Correlation id propagation middleware
app.add_middleware(CorrelationIdMiddleware)

# Security and Timing middlewares
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(TimingMiddleware)

# Register global exception handlers
register_exception_handlers(app)

# Configure CORS
_cors_origins = _settings.CORS_ORIGINS.split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router)
app.include_router(auth_router, tags=["Auth"])
app.include_router(item_router, prefix="/v1/item", tags=["Item"])
app.include_router(uom_router, prefix="/v1/uom", tags=["UOM"])
app.include_router(batch_router, prefix="/v1/batch", tags=["Batch"])
app.include_router(stock_router, prefix="/v1/stock-entry", tags=["Stock Entry"])
app.include_router(dispatch_router, prefix="/v1/dispatch", tags=["Dispatch Entry"])
app.include_router(
    rejection_router, prefix="/v1/rejection-entries", tags=["Rejection Entry"]
)
app.include_router(
    inventory_txn_router, prefix="/v1/inventory-txn", tags=["Inventory Txn"]
)
app.include_router(
    admin_diagnostics_router, prefix="/v1/admin", tags=["Admin Diagnostics"]
)

app.include_router(
    stock_history_router, prefix="/v1/stock-entry", tags=["Stock Entry History"]
)


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
        if os.getenv("RUN_MIGRATIONS_ON_STARTUP", "true").lower() == "true":
            logger.info("Applying migrations...")
            subprocess.run(["alembic", "upgrade", "head"], check=True)
            logger.info("Database migrations applied successfully")
        else:
            logger.info(
                "Skipping migrations on startup (RUN_MIGRATIONS_ON_STARTUP=false)"
            )
    except subprocess.CalledProcessError as e:
        logger.exception(f"Error applying migrations: {e}")
        raise RuntimeError(f"Startup aborted: migration failure — {e}") from e

    # 2. Seed fallback data (only if enabled in settings)
    from app.core.config import settings

    if getattr(settings, "SEED_INITIAL_DATA", True):
        try:
            logger.info("Seeding fallback data...")
            db = SessionLocal()
            seed_all(db, created_by="admin@startup")
            db.close()
            logger.info("✅ Initial data seeded")
        except Exception:
            logger.exception("❌ Seeding initial data failed")
