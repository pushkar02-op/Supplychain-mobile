import pytest


def test_security_headers_present(client_instance):
    """Test that basic security headers are present in responses."""
    response = client_instance.get("/v1/health")
    assert response.status_code == 200

    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("Referrer-Policy") == "no-referrer"
    # Not production, so HSTS shouldn't be there
    assert "Strict-Transport-Security" not in response.headers


def test_hsts_header_in_production(monkeypatch):
    """Test that HSTS header is present ONLY when ENVIRONMENT=production."""
    from app.core.config import settings

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")

    # We need a new TestClient to reflect the patched settings when the middleware executes
    # But because middleware is bound at startup, monkeypatching `settings.ENVIRONMENT`
    # works if the middleware reads it per request, but in our SecurityHeadersMiddleware
    # it reads from `app.core.config.settings` inside `dispatch()`.
    import app.main
    from fastapi.testclient import TestClient

    test_client = TestClient(app.main.app)

    response = test_client.get("/v1/health")
    assert response.status_code == 200
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert (
        response.headers.get("Strict-Transport-Security")
        == "max-age=31536000; includeSubDomains"
    )


@pytest.fixture
def client_instance():
    from app.main import app
    from fastapi.testclient import TestClient

    return TestClient(app)
