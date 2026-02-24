from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.session import get_db
from app.main import app


def _override_db(db_session):
    def _get_db():
        try:
            yield db_session
        finally:
            pass

    return _get_db


def _override_user(role: Role, user_id: int, username: str):
    return lambda: SimpleNamespace(
        id=user_id,
        username=username,
        full_name=username,
        role=role,
        is_active=True,
        is_admin=(role == Role.OWNER),
    )


def test_owner_can_create_manager_and_worker(db_session):
    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER,
        user_id=100,
        username="owner",
    )
    try:
        with TestClient(app) as client:
            manager_response = client.post(
                "/v1/users/",
                json={
                    "username": "managed_manager",
                    "full_name": "Managed Manager",
                    "password": "secret",
                    "role": "MANAGER",
                },
            )
            worker_response = client.post(
                "/v1/users/",
                json={
                    "username": "managed_worker",
                    "full_name": "Managed Worker",
                    "password": "secret",
                    "role": "WORKER",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert manager_response.status_code == 200
    assert manager_response.json()["role"] == "MANAGER"
    assert worker_response.status_code == 200
    assert worker_response.json()["role"] == "WORKER"


def test_manager_can_create_worker_only(db_session):
    manager = User(
        username="manager_creator",
        full_name="Manager Creator",
        hashed_password="hashed",
        role=Role.MANAGER,
        is_active=True,
        created_by="test",
        updated_by="test",
    )
    db_session.add(manager)
    db_session.commit()
    db_session.refresh(manager)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER,
        user_id=manager.id,
        username=manager.username,
    )
    try:
        with TestClient(app) as client:
            worker_response = client.post(
                "/v1/users/",
                json={
                    "username": "manager_created_worker",
                    "full_name": "Manager Worker",
                    "password": "secret",
                    "role": "WORKER",
                },
            )
            manager_response = client.post(
                "/v1/users/",
                json={
                    "username": "manager_created_manager",
                    "full_name": "Manager Manager",
                    "password": "secret",
                    "role": "MANAGER",
                },
            )
            owner_response = client.post(
                "/v1/users/",
                json={
                    "username": "manager_created_owner",
                    "full_name": "Manager Owner",
                    "password": "secret",
                    "role": "OWNER",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert worker_response.status_code == 200
    assert worker_response.json()["role"] == "WORKER"
    assert manager_response.status_code == 403
    assert manager_response.json()["rule_id"] == "AUT-001"
    assert owner_response.status_code == 403
    assert owner_response.json()["rule_id"] == "AUT-001"


def test_worker_cannot_create_users(db_session):
    worker = User(
        username="worker_creator",
        full_name="Worker Creator",
        hashed_password="hashed",
        role=Role.WORKER,
        is_active=True,
        created_by="test",
        updated_by="test",
    )
    db_session.add(worker)
    db_session.commit()
    db_session.refresh(worker)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.WORKER,
        user_id=worker.id,
        username=worker.username,
    )
    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/users/",
                json={
                    "username": "worker_attempt",
                    "full_name": "Worker Attempt",
                    "password": "secret",
                    "role": "WORKER",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403
    assert response.json()["rule_id"] == "AUT-001"
