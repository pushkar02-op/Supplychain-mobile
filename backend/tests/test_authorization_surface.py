from datetime import date
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.uom import UOM
from app.db.session import get_db
from app.main import app


def _override_db(db_session):
    def _get_db():
        try:
            yield db_session
        finally:
            pass

    return _get_db


def _seed_dispatch_prereqs(db_session):
    uom = UOM(code="kg", description="Kilogram")
    db_session.add(uom)
    db_session.flush()

    item = Item(name="Auth Surface Item", default_uom_id=uom.id, item_code="AUTH-ITM")
    mart = Mart(name="Auth Surface Mart", company_name="Auth Co")
    db_session.add_all([item, mart])
    db_session.flush()

    batch = Batch(
        item_id=item.id,
        quantity=Decimal("10.000"),
        unit="kg",
        received_at=date.today(),
    )
    db_session.add(batch)
    db_session.commit()
    db_session.refresh(item)
    db_session.refresh(mart)
    db_session.refresh(batch)
    return item, mart, batch


def test_admin_only_route_rejects_non_admin_user(db_session):
    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id=2,
        username="operator",
        full_name="Operator User",
        role=Role.WORKER,
        is_active=True,
    )

    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/batch/",
                json={
                    "item_id": 1,
                    "quantity": 1,
                    "unit": "kg",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403


def test_protected_mutation_rejects_unauthenticated_user(db_session):
    app.dependency_overrides[get_db] = _override_db(db_session)

    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/dispatch-entries/",
                json={
                    "item_id": 1,
                    "batch_id": 1,
                    "mart_name": "Any Mart",
                    "dispatch_date": str(date.today()),
                    "quantity": 1,
                    "unit": "kg",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 401


def test_previously_allowed_non_admin_dispatch_still_allowed(db_session):
    item, mart, batch = _seed_dispatch_prereqs(db_session)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id=2,
        username="operator",
        full_name="Operator User",
        role=Role.WORKER,
        is_active=True,
    )

    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/dispatch-entries/",
                json={
                    "item_id": item.id,
                    "batch_id": batch.id,
                    "mart_name": mart.name,
                    "dispatch_date": str(date.today()),
                    "quantity": 1.25,
                    "unit": "kg",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    payload = response.json()
    assert payload["batch_id"] == batch.id
    assert payload["item_id"] == item.id


def test_inline_admin_checks_removed_from_router_body():
    repo_backend_root = Path(__file__).resolve().parents[1]
    targets = [
        repo_backend_root / "app" / "api" / "batch.py",
        repo_backend_root / "app" / "api" / "dispatch_entry.py",
    ]

    for target in targets:
        source = target.read_text(encoding="utf-8")
        assert "if not current_user.is_admin" not in source
