from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.models.user_warehouse_access import UserWarehouseAccess
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


def _create_warehouse(
    db_session, name: str, code: str, is_active: bool = True
) -> Warehouse:
    warehouse = Warehouse(name=name, code=code, is_active=is_active)
    db_session.add(warehouse)
    db_session.commit()
    db_session.refresh(warehouse)
    return warehouse


def _assign_warehouse(db_session, user_id: int, warehouse_id: int) -> None:
    db_session.add(UserWarehouseAccess(user_id=user_id, warehouse_id=warehouse_id))
    db_session.commit()


def test_my_access_requires_authentication():
    with TestClient(app) as client:
        response = client.get("/v1/warehouses/my-access")
    assert response.status_code == 401


def test_owner_gets_all_active_warehouses(db_session):
    active_a = _create_warehouse(db_session, "Alpha Warehouse", "ALPHA")
    active_b = _create_warehouse(db_session, "Bravo Warehouse", "BRAVO")
    _create_warehouse(db_session, "Inactive Warehouse", "INACT", is_active=False)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user_id=900, username="owner_scope"
    )
    try:
        with TestClient(app) as client:
            response = client.get("/v1/warehouses/my-access")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    ids = [row["id"] for row in response.json()]
    assert active_a.id in ids
    assert active_b.id in ids
    assert len(response.json()) == len(
        db_session.query(Warehouse).filter(Warehouse.is_active.is_(True)).all()
    )


def test_manager_gets_only_assigned_warehouses(db_session):
    manager = _create_user(db_session, "manager_access", Role.MANAGER)
    allowed = _create_warehouse(db_session, "Manager Allowed", "MALW")
    _create_warehouse(db_session, "Manager Denied", "MDNW")
    _assign_warehouse(db_session, manager.id, allowed.id)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER, user_id=manager.id, username=manager.username
    )
    try:
        with TestClient(app) as client:
            response = client.get("/v1/warehouses/my-access")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [
        {"id": allowed.id, "name": allowed.name, "code": allowed.code}
    ]


def test_worker_gets_only_assigned_warehouses(db_session):
    worker = _create_user(db_session, "worker_access", Role.WORKER)
    allowed = _create_warehouse(db_session, "Worker Allowed", "WALW")
    _create_warehouse(db_session, "Worker Denied", "WDNW")
    _assign_warehouse(db_session, worker.id, allowed.id)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.WORKER, user_id=worker.id, username=worker.username
    )
    try:
        with TestClient(app) as client:
            response = client.get("/v1/warehouses/my-access")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [
        {"id": allowed.id, "name": allowed.name, "code": allowed.code}
    ]


def test_inactive_warehouse_is_excluded_for_assigned_user(db_session):
    manager = _create_user(db_session, "manager_inactive", Role.MANAGER)
    active = _create_warehouse(db_session, "Manager Active", "MACT")
    inactive = _create_warehouse(
        db_session, "Manager Inactive", "MINA", is_active=False
    )
    _assign_warehouse(db_session, manager.id, active.id)
    _assign_warehouse(db_session, manager.id, inactive.id)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER, user_id=manager.id, username=manager.username
    )
    try:
        with TestClient(app) as client:
            response = client.get("/v1/warehouses/my-access")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [
        {"id": active.id, "name": active.name, "code": active.code}
    ]


def test_unassigned_user_gets_empty_list(db_session):
    worker = _create_user(db_session, "worker_unassigned", Role.WORKER)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.WORKER, user_id=worker.id, username=worker.username
    )
    try:
        with TestClient(app) as client:
            response = client.get("/v1/warehouses/my-access")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == []
