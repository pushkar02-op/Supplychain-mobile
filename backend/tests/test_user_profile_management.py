from types import SimpleNamespace

from app.core.auth import get_current_user
from app.core.security import hash_password, verify_password
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.models.user_warehouse_access import UserWarehouseAccess
from app.db.models.warehouse import Warehouse
from app.main import app


def _override_user(role: Role, user_id: int, username: str):
    return lambda: SimpleNamespace(
        id=user_id,
        username=username,
        full_name=f"{role.value.title()} User",
        role=role,
        is_active=True,
        is_admin=role == Role.OWNER,
    )


def _create_user(db_session, *, user_id: int, username: str, role: Role) -> User:
    user = User(
        id=user_id,
        username=username,
        full_name=f"{role.value.title()} User",
        hashed_password=hash_password("old-password"),
        role=role,
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _assign_warehouse(db_session, *, user_id: int, warehouse_id: int) -> None:
    db_session.add(UserWarehouseAccess(user_id=user_id, warehouse_id=warehouse_id))
    db_session.commit()


def _create_warehouse(
    db_session, *, warehouse_id: int, name: str, code: str
) -> Warehouse:
    warehouse = Warehouse(id=warehouse_id, name=name, code=code, is_active=True)
    db_session.add(warehouse)
    db_session.commit()
    db_session.refresh(warehouse)
    return warehouse


def test_get_me_returns_assigned_warehouses(client, db_session):
    user = _create_user(
        db_session, user_id=201, username="manager_201", role=Role.MANAGER
    )
    warehouse = _create_warehouse(
        db_session, warehouse_id=301, name="Secondary", code="SEC"
    )
    _assign_warehouse(db_session, user_id=user.id, warehouse_id=warehouse.id)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER, user.id, user.username
    )

    response = client.get("/v1/users/me")

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == user.id
    assert body["warehouses"] == [
        {"id": warehouse.id, "name": warehouse.name, "code": warehouse.code}
    ]


def test_get_me_returns_implicit_owner_warehouses(client, db_session):
    user = _create_user(db_session, user_id=206, username="owner_206", role=Role.OWNER)
    first = _create_warehouse(db_session, warehouse_id=302, name="Alpha", code="ALPHA")
    second = _create_warehouse(db_session, warehouse_id=303, name="Beta", code="BETA")
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user.id, user.username
    )

    response = client.get("/v1/users/me")

    assert response.status_code == 200
    warehouses = response.json()["warehouses"]
    assert {"id": first.id, "name": first.name, "code": first.code} in warehouses
    assert {"id": second.id, "name": second.name, "code": second.code} in warehouses


def test_patch_me_updates_full_name(client, db_session):
    user = _create_user(
        db_session, user_id=202, username="worker_202", role=Role.WORKER
    )
    app.dependency_overrides[get_current_user] = _override_user(
        Role.WORKER, user.id, user.username
    )

    response = client.patch("/v1/users/me", json={"full_name": "Updated Name"})

    assert response.status_code == 200
    assert response.json()["full_name"] == "Updated Name"
    db_session.refresh(user)
    assert user.full_name == "Updated Name"


def test_change_password_updates_hash(client, db_session):
    user = _create_user(db_session, user_id=203, username="owner_203", role=Role.OWNER)
    previous_hash = user.hashed_password
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user.id, user.username
    )

    response = client.post(
        "/v1/users/change-password",
        json={"old_password": "old-password", "new_password": "new-password-1"},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "password_updated"}
    db_session.refresh(user)
    assert user.hashed_password != previous_hash
    assert verify_password("new-password-1", user.hashed_password)


def test_change_password_fails_for_incorrect_old_password(client, db_session):
    user = _create_user(
        db_session, user_id=204, username="worker_204", role=Role.WORKER
    )
    app.dependency_overrides[get_current_user] = _override_user(
        Role.WORKER, user.id, user.username
    )

    response = client.post(
        "/v1/users/change-password",
        json={"old_password": "wrong-password", "new_password": "new-password-2"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Current password is incorrect"


def test_change_password_validation_rules(client, db_session):
    user = _create_user(
        db_session, user_id=205, username="worker_205", role=Role.WORKER
    )
    app.dependency_overrides[get_current_user] = _override_user(
        Role.WORKER, user.id, user.username
    )

    short_response = client.post(
        "/v1/users/change-password",
        json={"old_password": "old-password", "new_password": "short"},
    )
    assert short_response.status_code == 400
    assert (
        short_response.json()["detail"]
        == "New password must be at least 8 characters long"
    )

    same_response = client.post(
        "/v1/users/change-password",
        json={"old_password": "old-password", "new_password": "old-password"},
    )
    assert same_response.status_code == 400
    assert (
        same_response.json()["detail"]
        == "New password must be different from the current password"
    )
