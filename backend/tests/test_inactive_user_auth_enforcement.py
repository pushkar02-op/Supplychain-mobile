from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.security import hash_password
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.session import get_db
from app.main import app


def _create_user(db_session, username: str, password: str = "secret") -> User:
    user = User(
        username=username,
        full_name=username,
        hashed_password=hash_password(password),
        role=Role.WORKER,
        is_active=True,
        created_by="test",
        updated_by="test",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _override_db(db_session):
    def _get_db():
        try:
            yield db_session
        finally:
            pass

    return _get_db


def test_inactive_user_login_blocked(db_session):
    user = _create_user(db_session, "inactive_login_user")
    user.is_active = False
    db_session.commit()

    app.dependency_overrides[get_db] = _override_db(db_session)
    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/login",
                json={"username": "inactive_login_user", "password": "secret"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403
    assert response.json()["rule_id"] == "AUT-005"


def test_inactive_user_refresh_blocked(db_session, monkeypatch):
    user = _create_user(db_session, "inactive_refresh_user")
    monkeypatch.setattr(settings, "JWT_SECRET_KEY", "test-secret")

    app.dependency_overrides[get_db] = _override_db(db_session)
    try:
        with TestClient(app) as client:
            login_response = client.post(
                "/v1/login",
                json={"username": "inactive_refresh_user", "password": "secret"},
            )
            assert login_response.status_code == 200
            refresh_token = login_response.json()["refresh_token"]

            user.is_active = False
            db_session.commit()

            refresh_response = client.post(
                "/v1/refresh",
                json={"refresh_token": refresh_token},
            )
    finally:
        app.dependency_overrides.clear()

    assert refresh_response.status_code == 403
    assert refresh_response.json()["rule_id"] == "AUT-005"


def test_inactive_user_token_usage_blocked(db_session, monkeypatch):
    user = _create_user(db_session, "inactive_token_user")
    monkeypatch.setattr(settings, "JWT_SECRET_KEY", "test-secret")

    app.dependency_overrides[get_db] = _override_db(db_session)
    try:
        with TestClient(app) as client:
            login_response = client.post(
                "/v1/login",
                json={"username": "inactive_token_user", "password": "secret"},
            )
            assert login_response.status_code == 200
            access_token = login_response.json()["access_token"]

            user.is_active = False
            db_session.commit()

            protected_response = client.get(
                "/v1/item/with-available-batches",
                params={"warehouse_id": 1},
                headers={"Authorization": f"Bearer {access_token}"},
            )
    finally:
        app.dependency_overrides.clear()

    assert protected_response.status_code == 403
    assert protected_response.json()["rule_id"] == "AUT-005"
