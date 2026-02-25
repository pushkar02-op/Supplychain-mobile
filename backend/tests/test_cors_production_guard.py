"""
Tests for CORS production guard.
Verifies that wildcard CORS is blocked in production but allowed in development.
"""

import pytest

from app.core.config import settings


def test_production_wildcard_cors_fails_startup(monkeypatch):
    """ENVIRONMENT=production + CORS_ORIGINS='*' must raise RuntimeError."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "CORS_ORIGINS", "*")

    import importlib

    import app.main

    with pytest.raises(RuntimeError, match="Wildcard CORS not allowed in production"):
        importlib.reload(app.main)


def test_production_specific_origin_allowed(monkeypatch):
    """ENVIRONMENT=production + specific origin must not raise."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "CORS_ORIGINS", "https://example.com")

    import importlib

    import app.main

    # Should not raise
    importlib.reload(app.main)


def test_development_allows_wildcard(monkeypatch):
    """ENVIRONMENT=development + CORS_ORIGINS='*' must not raise."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    monkeypatch.setattr(settings, "CORS_ORIGINS", "*")

    import importlib

    import app.main

    # Should not raise
    importlib.reload(app.main)
