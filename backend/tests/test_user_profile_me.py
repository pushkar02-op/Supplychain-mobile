from types import SimpleNamespace

from app.core.auth import get_current_user
from app.db.enums.role import Role
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


def test_me_endpoint_owner_can_read_self(client, db_session):
    user = _create_user(db_session, user_id=101, role=Role.OWNER)
    app.dependency_overrides[get_current_user] = _override_user(Role.OWNER, user.id)

    response = client.get("/v1/users/me")

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == user.id
    assert body["username"] == user.username
    assert body["full_name"] == user.full_name
    assert body["role"] == "OWNER"
    assert body["is_admin"] is True


def test_me_endpoint_manager_can_read_self(client, db_session):
    user = _create_user(db_session, user_id=102, role=Role.MANAGER)
    app.dependency_overrides[get_current_user] = _override_user(Role.MANAGER, user.id)

    response = client.get("/v1/users/me")

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == user.id
    assert body["role"] == "MANAGER"
    assert body["is_admin"] is False


def test_me_endpoint_worker_can_read_self(client, db_session):
    user = _create_user(db_session, user_id=103, role=Role.WORKER)
    app.dependency_overrides[get_current_user] = _override_user(Role.WORKER, user.id)

    response = client.get("/v1/users/me")

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == user.id
    assert body["role"] == "WORKER"
    assert body["is_admin"] is False
