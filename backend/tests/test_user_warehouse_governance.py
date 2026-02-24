from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.models.warehouse import Warehouse
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


def _create_warehouse(db_session, name: str, code: str) -> Warehouse:
    warehouse = Warehouse(name=name, code=code, is_active=True)
    db_session.add(warehouse)
    db_session.commit()
    db_session.refresh(warehouse)
    return warehouse


def test_owner_assign_list_remove_user_warehouses(db_session):
    worker = _create_user(db_session, "worker_scope", Role.WORKER)
    w1 = _create_warehouse(db_session, "Scope Warehouse 1", "SC1")
    w2 = _create_warehouse(db_session, "Scope Warehouse 2", "SC2")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user_id=500, username="owner"
    )
    try:
        with TestClient(app) as client:
            assign_1 = client.post(
                f"/v1/users/{worker.id}/assign-warehouse",
                params={"warehouse_id": w1.id},
            )
            assign_2 = client.post(
                f"/v1/users/{worker.id}/assign-warehouse",
                params={"warehouse_id": w2.id},
            )
            listed = client.get(f"/v1/users/{worker.id}/warehouses")
            remove = client.delete(
                f"/v1/users/{worker.id}/remove-warehouse",
                params={"warehouse_id": w2.id},
            )
            listed_after_remove = client.get(f"/v1/users/{worker.id}/warehouses")
    finally:
        app.dependency_overrides.clear()

    assert assign_1.status_code == 200
    assert assign_2.status_code == 200
    assert listed.status_code == 200
    assert len(listed.json()) == 2
    assert remove.status_code == 204
    assert listed_after_remove.status_code == 200
    assert len(listed_after_remove.json()) == 1


def test_cannot_remove_last_warehouse_from_active_user(db_session):
    worker = _create_user(db_session, "worker_last_warehouse", Role.WORKER)
    w1 = _create_warehouse(db_session, "Last Warehouse", "LS1")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user_id=501, username="owner"
    )
    try:
        with TestClient(app) as client:
            assign_response = client.post(
                f"/v1/users/{worker.id}/assign-warehouse",
                params={"warehouse_id": w1.id},
            )
            remove_response = client.delete(
                f"/v1/users/{worker.id}/remove-warehouse",
                params={"warehouse_id": w1.id},
            )
    finally:
        app.dependency_overrides.clear()

    assert assign_response.status_code == 200
    assert remove_response.status_code == 400
    assert "last warehouse" in remove_response.json()["detail"].lower()


def test_owner_cannot_assign_or_remove_owner_warehouse(db_session):
    owner_target = _create_user(db_session, "owner_target", Role.OWNER)
    w1 = _create_warehouse(db_session, "Owner Warehouse", "OW1")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user_id=502, username="owner"
    )
    try:
        with TestClient(app) as client:
            assign_response = client.post(
                f"/v1/users/{owner_target.id}/assign-warehouse",
                params={"warehouse_id": w1.id},
            )
            remove_response = client.delete(
                f"/v1/users/{owner_target.id}/remove-warehouse",
                params={"warehouse_id": w1.id},
            )
    finally:
        app.dependency_overrides.clear()

    assert assign_response.status_code == 400
    assert remove_response.status_code == 400


def test_non_owner_cannot_manage_user_warehouses(db_session):
    worker = _create_user(db_session, "worker_non_owner", Role.WORKER)
    w1 = _create_warehouse(db_session, "Manager Scope Warehouse", "MS1")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER, user_id=503, username="manager"
    )
    try:
        with TestClient(app) as client:
            response = client.post(
                f"/v1/users/{worker.id}/assign-warehouse",
                params={"warehouse_id": w1.id},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403
    assert response.json()["rule_id"] == "AUT-001"
