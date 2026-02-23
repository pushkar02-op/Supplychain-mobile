from datetime import date
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


def _override_user(user_id: int, role: Role, username: str = "user"):
    return lambda: SimpleNamespace(
        id=user_id,
        username=username,
        full_name=username,
        role=role,
        is_active=True,
        is_admin=(role == Role.OWNER),
    )


def _ensure_warehouse(db_session, code: str, name: str) -> Warehouse:
    existing = db_session.query(Warehouse).filter(Warehouse.code == code).first()
    if existing:
        return existing
    warehouse = Warehouse(name=name, code=code, is_active=True)
    db_session.add(warehouse)
    db_session.commit()
    db_session.refresh(warehouse)
    return warehouse


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


def _assign_user_warehouse(db_session, user_id: int, warehouse_id: int) -> None:
    existing = (
        db_session.query(UserWarehouseAccess)
        .filter(
            UserWarehouseAccess.user_id == user_id,
            UserWarehouseAccess.warehouse_id == warehouse_id,
        )
        .first()
    )
    if existing:
        return
    db_session.add(UserWarehouseAccess(user_id=user_id, warehouse_id=warehouse_id))
    db_session.commit()


def test_worker_cannot_create_cost_entry(db_session):
    main = _ensure_warehouse(db_session, "MAIN", "Main Warehouse")
    worker = _create_user(db_session, "cost_worker", Role.WORKER)
    _assign_user_warehouse(db_session, worker.id, main.id)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        worker.id, Role.WORKER, worker.username
    )
    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/cost/labour",
                json={
                    "warehouse_id": main.id,
                    "date": date.today().isoformat(),
                    "total_cost": 125.5,
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403
    assert response.json()["rule_id"] == "AUT-001"


def test_manager_cannot_access_unassigned_warehouse_for_cost(db_session):
    main = _ensure_warehouse(db_session, "MAIN", "Main Warehouse")
    secondary = _ensure_warehouse(db_session, "SEC", "Secondary Warehouse")
    manager = _create_user(db_session, "cost_manager", Role.MANAGER)
    _assign_user_warehouse(db_session, manager.id, main.id)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        manager.id, Role.MANAGER, manager.username
    )
    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/cost/transport",
                json={
                    "warehouse_id": secondary.id,
                    "date": date.today().isoformat(),
                    "total_cost": 99.0,
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403
    assert response.json()["rule_id"] == "AUT-004"


def test_owner_must_specify_warehouse_for_cost_reads(db_session):
    owner = _create_user(db_session, "cost_owner", Role.OWNER)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        owner.id, Role.OWNER, owner.username
    )
    try:
        with TestClient(app) as client:
            response = client.get(
                "/v1/cost/labour",
                params={
                    "start_date": "2026-01-01",
                    "end_date": "2026-01-31",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 400
    assert response.json()["detail"] == "warehouse_id is required"
