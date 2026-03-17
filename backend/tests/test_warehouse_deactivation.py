from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
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


def _override_owner():
    return lambda: SimpleNamespace(
        id=1,
        username="owner_test",
        full_name="owner_test",
        role=Role.OWNER,
        is_active=True,
        is_admin=True,
    )


def _create_warehouse(
    db_session, name: str, code: str, is_active: bool = True
) -> Warehouse:
    warehouse = Warehouse(name=name, code=code, is_active=is_active)
    db_session.add(warehouse)
    db_session.commit()
    db_session.refresh(warehouse)
    return warehouse


def _payload(warehouse: Warehouse, *, is_active: bool) -> dict:
    return {
        "name": warehouse.name,
        "code": warehouse.code,
        "is_active": is_active,
        "financial_lock_date": None,
    }


def test_deactivate_active_session_warehouse_returns_409(db_session):
    warehouse = _create_warehouse(db_session, "Alpha", "ALPHA")
    _create_warehouse(db_session, "Bravo", "BRAVO")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_owner()
    try:
        with TestClient(app) as client:
            response = client.put(
                f"/v1/warehouses/{warehouse.id}",
                params={"current_session_warehouse": warehouse.id},
                json=_payload(warehouse, is_active=False),
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 409
    assert (
        response.json()["detail"] == "Cannot deactivate the currently active warehouse"
    )


def test_deactivate_last_active_warehouse_returns_409(db_session):
    warehouse = _create_warehouse(db_session, "Solo", "SOLO")
    for other in (
        db_session.query(Warehouse)
        .filter(Warehouse.id != warehouse.id, Warehouse.is_active.is_(True))
        .all()
    ):
        other.is_active = False
    db_session.commit()

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_owner()
    try:
        with TestClient(app) as client:
            response = client.put(
                f"/v1/warehouses/{warehouse.id}",
                json=_payload(warehouse, is_active=False),
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 409
    assert response.json()["detail"] == "At least one active warehouse must exist"


def test_deactivate_inactive_warehouse_is_allowed(db_session):
    warehouse = _create_warehouse(db_session, "Dormant", "DORM", is_active=False)
    _create_warehouse(db_session, "Fallback", "FALL")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_owner()
    try:
        with TestClient(app) as client:
            response = client.put(
                f"/v1/warehouses/{warehouse.id}",
                json=_payload(warehouse, is_active=False),
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["is_active"] is False


def test_reactivate_warehouse_succeeds(db_session):
    warehouse = _create_warehouse(db_session, "Recover", "RECV", is_active=False)
    _create_warehouse(db_session, "Fallback", "BACK")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_owner()
    try:
        with TestClient(app) as client:
            response = client.put(
                f"/v1/warehouses/{warehouse.id}",
                json=_payload(warehouse, is_active=True),
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["is_active"] is True
