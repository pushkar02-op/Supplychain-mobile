from unittest.mock import MagicMock

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_returns_ready_when_db_ok():
    response = client.get("/v1/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_ready_returns_503_when_db_fails():
    """Override get_db to yield a session whose execute() always raises."""

    def broken_db():
        mock_session = MagicMock(spec=Session)
        mock_session.execute.side_effect = Exception("DB down")
        yield mock_session

    app.dependency_overrides[get_db] = broken_db
    try:
        response = client.get("/v1/ready")
        assert response.status_code == 503
        assert response.json()["detail"] == "Service not ready"
    finally:
        app.dependency_overrides.pop(get_db, None)
