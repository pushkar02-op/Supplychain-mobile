from datetime import datetime, timedelta
from types import SimpleNamespace

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.audit_log import AuditLog
from app.db.models.user import User
from app.main import app


def _override_user(role: Role, user_id: int):
    return lambda: SimpleNamespace(
        id=user_id,
        username=f"{role.value.lower()}_{user_id}",
        full_name=f"{role.value.title()} User",
        role=role,
        is_active=True,
        is_admin=role == Role.OWNER,
    )


def _create_user(db_session, *, user_id: int, role: Role) -> User:
    user = User(
        id=user_id,
        username=f"{role.value.lower()}_{user_id}",
        full_name=f"{role.value.title()} User",
        hashed_password="hashed",
        role=role,
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _create_log(
    db_session,
    *,
    actor_user_id: int,
    warehouse_id: int | None,
    created_at: datetime,
) -> AuditLog:
    entry = AuditLog(
        actor_user_id=actor_user_id,
        action_type="TEST",
        entity_type="Order",
        entity_id=1,
        warehouse_id=warehouse_id,
        created_at=created_at,
    )
    db_session.add(entry)
    db_session.commit()
    db_session.refresh(entry)
    return entry


def test_audit_logs_filter_and_pagination(client, db_session):
    user = _create_user(db_session, user_id=201, role=Role.OWNER)
    app.dependency_overrides[get_current_user] = _override_user(Role.OWNER, user.id)

    now = datetime.utcnow()
    log_new = _create_log(
        db_session,
        actor_user_id=user.id,
        warehouse_id=1,
        created_at=now,
    )
    log_old = _create_log(
        db_session,
        actor_user_id=user.id,
        warehouse_id=1,
        created_at=now - timedelta(minutes=1),
    )
    _create_log(
        db_session,
        actor_user_id=user.id,
        warehouse_id=2,
        created_at=now - timedelta(minutes=2),
    )

    response = client.get(
        "/v1/audit-logs",
        params={"warehouse_id": 1, "limit": 10, "offset": 0},
    )
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 2

    response = client.get(
        "/v1/audit-logs",
        params={"warehouse_id": 1, "limit": 1, "offset": 1},
    )
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["id"] == log_old.id
    assert log_new.id != log_old.id

    app.dependency_overrides.clear()


def test_audit_logs_manager_access(client, db_session):
    user = _create_user(db_session, user_id=202, role=Role.MANAGER)
    app.dependency_overrides[get_current_user] = _override_user(Role.MANAGER, user.id)
    _create_log(
        db_session,
        actor_user_id=user.id,
        warehouse_id=1,
        created_at=datetime.utcnow(),
    )

    response = client.get("/v1/audit-logs", params={"limit": 1, "offset": 0})

    assert response.status_code == 200
    assert isinstance(response.json(), list)

    app.dependency_overrides.clear()
