"""
Application entrypoint for the AGRO FastAPI service.
Configures logging, exception handlers, CORS, and database migrations on startup.
"""

import asyncio
import logging

from app.api import router as api_router
from app.core.config import settings as _settings
from app.core.correlation import CorrelationIdMiddleware
from app.core.exceptions import AppException, register_exception_handlers
from app.core.logging_config import setup_logging
from app.core.rate_limit import limiter
from app.core.security_headers import SecurityHeadersMiddleware
from app.core.timing import TimingMiddleware
from app.db.seed.seed_all import seed_all
from app.db.session import SessionLocal
from app.services.ledger_health_monitor import start_ledger_health_monitor
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
app.include_router(api_router, prefix="/v1")


@app.on_event("startup")
async def startup() -> None:
    """
    Startup event handler.
    Runs database migrations automatically.
    """
    # Seed fallback data (only if enabled in settings)
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

    app.state.ledger_health_monitor_task = asyncio.create_task(
        start_ledger_health_monitor()
    )
