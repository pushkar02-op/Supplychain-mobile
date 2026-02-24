from datetime import date, datetime
from decimal import Decimal
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.reconciliation_record import DriftStatus, ReconciliationRecord
from app.db.models.uom import UOM
from app.db.models.user import User
from app.db.models.warehouse import Warehouse
from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.db.schemas.mart_bill import MartBillUpdate
from app.db.schemas.rejection_entry import RejectionEntryCreate
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.session import get_db
from app.main import app
from app.services.cost_control import upsert_labour_cost
from app.services.dispatch_entry import create_dispatch_entry
from app.services.financial_lock import set_financial_lock
from app.services.mart_bill import update_mart_bill
from app.services.rejection_entry import create_rejection_entry
from app.services.stock_entry import create_stock_entry


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


def _ensure_warehouse(db_session, code: str, name: str) -> Warehouse:
    existing = db_session.query(Warehouse).filter(Warehouse.code == code).first()
    if existing:
        return existing
    warehouse = Warehouse(name=name, code=code, is_active=True)
    db_session.add(warehouse)
    db_session.commit()
    db_session.refresh(warehouse)
    return warehouse


def _ensure_uom(db_session, code: str = "kg") -> UOM:
    uom = db_session.query(UOM).filter(UOM.code == code).first()
    if uom:
        return uom
    uom = UOM(code=code, description=f"{code} unit")
    db_session.add(uom)
    db_session.commit()
    db_session.refresh(uom)
    return uom


def _create_item(db_session, code: str, name: str) -> Item:
    uom = _ensure_uom(db_session)
    item = Item(name=name, item_code=code, default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()
    db_session.refresh(item)
    return item


def _create_mart(db_session, name: str) -> Mart:
    mart = Mart(name=name, company_name=f"{name} Pvt")
    db_session.add(mart)
    db_session.commit()
    db_session.refresh(mart)
    return mart


def _create_batch(
    db_session, item_id: int, warehouse_id: int, quantity: Decimal, unit: str = "kg"
) -> Batch:
    batch = Batch(
        item_id=item_id,
        warehouse_id=warehouse_id,
        quantity=quantity,
        unit=unit,
        received_at=date(2026, 1, 10),
        created_by="test",
        updated_by="test",
    )
    db_session.add(batch)
    db_session.commit()
    db_session.refresh(batch)
    return batch


def _set_lock(db_session, warehouse_id: int, lock_date: date, owner: User) -> None:
    set_financial_lock(
        db=db_session, warehouse_id=warehouse_id, lock_date=lock_date, actor_user=owner
    )


def test_owner_can_set_lock_via_api(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKA", "Lock Warehouse A")
    owner = _create_user(db_session, "lock_owner_api", Role.OWNER)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        owner.id, Role.OWNER, owner.username
    )
    try:
        with TestClient(app) as client:
            response = client.post(
                f"/v1/warehouses/{warehouse.id}/lock",
                json={"lock_date": "2026-01-15"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["warehouse_id"] == warehouse.id
    assert response.json()["financial_lock_date"] == "2026-01-15"


def test_manager_and_worker_cannot_set_lock_via_api(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKB", "Lock Warehouse B")
    manager = _create_user(db_session, "lock_manager_api", Role.MANAGER)
    worker = _create_user(db_session, "lock_worker_api", Role.WORKER)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        manager.id, Role.MANAGER, manager.username
    )
    try:
        with TestClient(app) as client:
            manager_response = client.post(
                f"/v1/warehouses/{warehouse.id}/lock",
                json={"lock_date": "2026-01-15"},
            )
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        worker.id, Role.WORKER, worker.username
    )
    try:
        with TestClient(app) as client:
            worker_response = client.post(
                f"/v1/warehouses/{warehouse.id}/lock",
                json={"lock_date": "2026-01-15"},
            )
    finally:
        app.dependency_overrides.clear()

    assert manager_response.status_code == 403
    assert manager_response.json()["rule_id"] == "AUT-001"
    assert worker_response.status_code == 403
    assert worker_response.json()["rule_id"] == "AUT-001"


def test_cannot_move_lock_backward(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKC", "Lock Warehouse C")
    owner = _create_user(db_session, "lock_owner_backward", Role.OWNER)
    _set_lock(db_session, warehouse.id, date(2026, 1, 20), owner)

    with pytest.raises(AppException) as exc:
        _set_lock(db_session, warehouse.id, date(2026, 1, 19), owner)

    assert exc.value.status_code == 400
    assert exc.value.rule_id == "AUT-007"


def test_cannot_lock_with_open_drift_on_or_before_lock_date(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKD", "Lock Warehouse D")
    owner = _create_user(db_session, "lock_owner_drift_before", Role.OWNER)
    item = _create_item(db_session, "DRIFT-BEFORE", "Drift Before")
    batch = _create_batch(db_session, item.id, warehouse.id, Decimal("10.000"))

    record = ReconciliationRecord(
        batch_id=batch.id,
        warehouse_id=warehouse.id,
        observed_ledger_qty=Decimal("8.000"),
        observed_state_qty=Decimal("10.000"),
        drift_amount=Decimal("2.000"),
        status=DriftStatus.OPEN,
        detected_at=datetime(2026, 1, 15, 9, 0, 0),
    )
    db_session.add(record)
    db_session.commit()

    with pytest.raises(AppException) as exc:
        _set_lock(db_session, warehouse.id, date(2026, 1, 15), owner)

    assert exc.value.status_code == 400
    assert exc.value.rule_id == "AUT-006"


def test_can_lock_when_open_drift_is_after_lock_date(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKE", "Lock Warehouse E")
    owner = _create_user(db_session, "lock_owner_drift_after", Role.OWNER)
    item = _create_item(db_session, "DRIFT-AFTER", "Drift After")
    batch = _create_batch(db_session, item.id, warehouse.id, Decimal("10.000"))

    record = ReconciliationRecord(
        batch_id=batch.id,
        warehouse_id=warehouse.id,
        observed_ledger_qty=Decimal("8.000"),
        observed_state_qty=Decimal("10.000"),
        drift_amount=Decimal("2.000"),
        status=DriftStatus.OPEN,
        detected_at=datetime(2026, 1, 16, 9, 0, 0),
    )
    db_session.add(record)
    db_session.commit()

    warehouse_after = set_financial_lock(
        db=db_session,
        warehouse_id=warehouse.id,
        lock_date=date(2026, 1, 15),
        actor_user=owner,
    )
    assert warehouse_after.financial_lock_date == date(2026, 1, 15)


def test_dispatch_blocked_by_financial_lock(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKF", "Lock Warehouse F")
    owner = _create_user(db_session, "lock_owner_dispatch", Role.OWNER)
    item = _create_item(db_session, "DSP-LOCK", "Dispatch Lock Item")
    _create_batch(db_session, item.id, warehouse.id, Decimal("20.000"))
    mart = _create_mart(db_session, "Lock Mart Dispatch")
    _set_lock(db_session, warehouse.id, date(2026, 1, 15), owner)

    entry = DispatchEntryCreate(
        item_id=item.id,
        batch_id=1,
        warehouse_id=warehouse.id,
        mart_name=mart.name,
        dispatch_date=date(2026, 1, 15),
        quantity=Decimal("1.000"),
        unit="kg",
        remarks="blocked",
    )

    with pytest.raises(AppException) as exc:
        create_dispatch_entry(
            db_session,
            entry=entry,
            created_by=owner.username,
            warehouse_id=warehouse.id,
        )
    assert exc.value.status_code == 400
    assert exc.value.rule_id == "AUT-007"


def test_labour_cost_blocked_by_financial_lock(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKG", "Lock Warehouse G")
    owner = _create_user(db_session, "lock_owner_labour", Role.OWNER)
    _set_lock(db_session, warehouse.id, date(2026, 1, 15), owner)

    with pytest.raises(AppException) as exc:
        upsert_labour_cost(
            db=db_session,
            warehouse_id=warehouse.id,
            date=date(2026, 1, 15),
            total_cost=Decimal("100.00"),
            user_id=owner.id,
        )
    assert exc.value.status_code == 400
    assert exc.value.rule_id == "AUT-007"


def test_mart_bill_mutation_blocked_by_financial_lock(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKH", "Lock Warehouse H")
    owner = _create_user(db_session, "lock_owner_mart_bill", Role.OWNER)
    mart = _create_mart(db_session, "Lock Mart Bill")
    _set_lock(db_session, warehouse.id, date(2026, 1, 15), owner)

    bill = MartBill(
        mart_id=mart.id,
        warehouse_id=warehouse.id,
        invoice_date=date(2026, 1, 15),
        file_path="invoices/test.pdf",
        file_hash="mart-bill-lock-hash",
        total_amount=Decimal("10.000000"),
        status="NEEDS_REVIEW",
        created_by="test",
        updated_by="test",
    )
    db_session.add(bill)
    db_session.commit()
    db_session.refresh(bill)

    with pytest.raises(AppException) as exc:
        update_mart_bill(
            db_session,
            invoice_id=bill.id,
            data=MartBillUpdate(remarks="should fail"),
            warehouse_id=warehouse.id,
        )
    assert exc.value.status_code == 400
    assert exc.value.rule_id == "AUT-007"


def test_rejection_blocked_by_financial_lock(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKI", "Lock Warehouse I")
    owner = _create_user(db_session, "lock_owner_rejection", Role.OWNER)
    item = _create_item(db_session, "REJ-LOCK", "Rejection Lock Item")
    batch = _create_batch(db_session, item.id, warehouse.id, Decimal("20.000"))
    _set_lock(db_session, warehouse.id, date(2026, 1, 15), owner)

    entry = RejectionEntryCreate(
        batch_id=batch.id,
        warehouse_id=warehouse.id,
        quantity=Decimal("1.000"),
        unit="kg",
        reason="blocked",
        rejection_date=date(2026, 1, 15),
        rejected_by="tester",
    )

    with pytest.raises(AppException) as exc:
        create_rejection_entry(
            db=db_session,
            entry=entry,
            created_by=owner.username,
            warehouse_id=warehouse.id,
        )
    assert exc.value.status_code == 400
    assert exc.value.rule_id == "AUT-007"


def test_stock_entry_blocked_by_financial_lock(db_session):
    warehouse = _ensure_warehouse(db_session, "LOCKJ", "Lock Warehouse J")
    owner = _create_user(db_session, "lock_owner_stock", Role.OWNER)
    item = _create_item(db_session, "STK-LOCK", "Stock Lock Item")
    _set_lock(db_session, warehouse.id, date(2026, 1, 15), owner)

    entry = StockEntryCreate(
        item_id=item.id,
        warehouse_id=warehouse.id,
        received_date=date(2026, 1, 15),
        price_per_unit=Decimal("10.000000"),
        total_cost=Decimal("10.000000"),
        source="test",
        quantity=Decimal("1.000"),
        unit="kg",
    )

    with pytest.raises(AppException) as exc:
        create_stock_entry(
            db=db_session,
            entry=entry,
            created_by=owner.id,
            warehouse_id=warehouse.id,
        )
    assert exc.value.status_code == 400
    assert exc.value.rule_id == "AUT-007"


def test_cross_warehouse_lock_isolation(db_session):
    warehouse_a = _ensure_warehouse(db_session, "LOCKK", "Lock Warehouse K")
    warehouse_b = _ensure_warehouse(db_session, "LOCKL", "Lock Warehouse L")
    owner = _create_user(db_session, "lock_owner_isolation", Role.OWNER)
    _set_lock(db_session, warehouse_a.id, date(2026, 1, 15), owner)

    record = upsert_labour_cost(
        db=db_session,
        warehouse_id=warehouse_b.id,
        date=date(2026, 1, 15),
        total_cost=Decimal("25.000000"),
        user_id=owner.id,
    )

    assert record.warehouse_id == warehouse_b.id
    assert record.date == date(2026, 1, 15)
