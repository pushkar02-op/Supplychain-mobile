import logging
from datetime import date
from datetime import timedelta
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.session import get_db
from app.main import app
from app.services.audit import log_action


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


def _create_user(db_session, username: str, role: Role) -> User:
    user = User(
        username=username,
        full_name=username,
        hashed_password="hashed",
        role=role,
        is_active=True,
        created_by="test",
        updated_by="test",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def test_owner_can_view_audit_logs_and_filters_work(db_session):
    owner = _create_user(db_session, "audit_owner", Role.OWNER)
    actor_two = _create_user(db_session, "audit_actor_two", Role.MANAGER)

    log_action(
        db=db_session,
        actor_user_id=owner.id,
        action_type="user_created",
        entity_type="user",
        entity_id=101,
        metadata={"username": "x"},
    )
    log_action(
        db=db_session,
        actor_user_id=actor_two.id,
        action_type="warehouse_assigned",
        entity_type="user_warehouse_access",
        entity_id=102,
        metadata={"warehouse_id": 1},
    )
    db_session.commit()

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER,
        user_id=owner.id,
        username=owner.username,
    )
    try:
        with TestClient(app) as client:
            admin_response = client.get("/v1/admin/audit-log")
            legacy_response = client.get("/v1/audit-logs/")
            filtered_response = client.get(
                "/v1/admin/audit-log",
                params={
                    "start_date": (date.today() - timedelta(days=1)).isoformat(),
                    "end_date": (date.today() + timedelta(days=1)).isoformat(),
                    "actor_user_id": owner.id,
                    "entity_type": "user",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert admin_response.status_code == 200
    assert legacy_response.status_code == 200
    assert len(admin_response.json()) >= 2
    assert "metadata" in admin_response.json()[0]

    assert filtered_response.status_code == 200
    filtered = filtered_response.json()
    assert len(filtered) >= 1
    assert all(row["actor_user_id"] == owner.id for row in filtered)
    assert all(row["entity_type"] == "user" for row in filtered)


def test_non_owner_cannot_view_audit_logs(db_session):
    manager = _create_user(db_session, "audit_manager", Role.MANAGER)
    log_action(
        db=db_session,
        actor_user_id=manager.id,
        action_type="user_created",
        entity_type="user",
        entity_id=201,
        metadata={},
    )
    db_session.commit()

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER,
        user_id=manager.id,
        username=manager.username,
    )
    try:
        with TestClient(app) as client:
            admin_response = client.get("/v1/admin/audit-log")
            legacy_response = client.get("/v1/audit-logs/")
    finally:
        app.dependency_overrides.clear()

    assert admin_response.status_code == 403
    assert admin_response.json()["rule_id"] == "AUT-001"
    assert legacy_response.status_code == 403
    assert legacy_response.json()["rule_id"] == "AUT-001"


def test_audit_write_failure_logs_warning(db_session, monkeypatch, caplog):
    class _BrokenNested:
        def __enter__(self):
            raise RuntimeError("nested failure")

        def __exit__(self, exc_type, exc, tb):
            return False

    monkeypatch.setattr(db_session, "begin_nested", lambda: _BrokenNested())

    with caplog.at_level(logging.WARNING):
        result = log_action(
            db=db_session,
            actor_user_id=1,
            action_type="user_created",
            entity_type="user",
            entity_id=1,
            metadata={},
        )

    assert result is None
    assert "Audit write failed action_type=user_created entity_type=user" in caplog.text
