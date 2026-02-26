"""
Tests for startup configuration validation.
Verifies that invalid config causes RuntimeError at import time.
"""

import importlib

import pytest

from app.core.config import settings


def test_missing_database_url_fails_startup(monkeypatch):
    """DATABASE_URL=None must raise RuntimeError."""
    monkeypatch.setattr(settings, "DATABASE_URL", None)
    monkeypatch.setattr(settings, "JWT_SECRET_KEY", "a" * 32)

    import app.main

    with pytest.raises(RuntimeError, match="DATABASE_URL is not set"):
        importlib.reload(app.main)


def test_short_jwt_secret_fails_startup(monkeypatch):
    """JWT_SECRET_KEY shorter than 32 chars must raise RuntimeError."""
    monkeypatch.setattr(settings, "JWT_SECRET_KEY", "tooshort")

    import app.main

    with pytest.raises(RuntimeError, match="JWT_SECRET_KEY too short"):
        importlib.reload(app.main)


def test_invalid_file_upload_limit_fails_startup(monkeypatch):
    """FILE_UPLOAD_MAX_MB <= 0 must raise RuntimeError."""
    monkeypatch.setattr(settings, "FILE_UPLOAD_MAX_MB", 0)

    import app.main

    with pytest.raises(RuntimeError, match="FILE_UPLOAD_MAX_MB must be > 0"):
        importlib.reload(app.main)


def test_production_wildcard_cors_fails_startup(monkeypatch):
    """ENVIRONMENT=production + CORS_ORIGINS='*' must raise RuntimeError."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "CORS_ORIGINS", "*")

    import app.main

    with pytest.raises(RuntimeError, match="Wildcard CORS not allowed in production"):
        importlib.reload(app.main)
