from datetime import date
from decimal import Decimal
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.dispatch_reversal import DispatchReversal
from app.db.models.item import Item
from app.db.models.labour_cost_daily import LabourCostDaily
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.order import Order
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.stock_entry import StockEntry
from app.db.models.transport_cost_daily import TransportCostDaily
from app.db.models.uom import UOM
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


def _seed_kpi_data(db_session, w1: Warehouse, w2: Warehouse) -> None:
    uom = UOM(code="kg", description="Kilogram")
    item = Item(name="Kpi Item", default_uom=uom)
    mart = Mart(name="Kpi Mart", company_name="Kpi Co")
    db_session.add_all([uom, item, mart])
    db_session.flush()

    order_1 = Order(
        item_id=item.id,
        mart_id=mart.id,
        warehouse_id=w1.id,
        order_date=date(2026, 2, 1),
        quantity_ordered=Decimal("20.000"),
        quantity_dispatched=Decimal("5.000"),
        status="Partially Completed",
        unit="kg",
    )
    order_2 = Order(
        item_id=item.id,
        mart_id=mart.id,
        warehouse_id=w2.id,
        order_date=date(2026, 2, 2),
        quantity_ordered=Decimal("30.000"),
        quantity_dispatched=Decimal("9.000"),
        status="Partially Completed",
        unit="kg",
    )
    db_session.add_all([order_1, order_2])
    db_session.flush()

    batch_1 = Batch(
        item_id=item.id,
        warehouse_id=w1.id,
        quantity=Decimal("15.000"),
        unit="kg",
        received_at=date(2026, 2, 2),
    )
    batch_2 = Batch(
        item_id=item.id,
        warehouse_id=w2.id,
        quantity=Decimal("25.000"),
        unit="kg",
        received_at=date(2026, 2, 2),
    )
    db_session.add_all([batch_1, batch_2])
    db_session.flush()

    stock_1 = StockEntry(
        item_id=item.id,
        batch_id=batch_1.id,
        warehouse_id=w1.id,
        received_date=date(2026, 2, 2),
        source="seed",
        price_per_unit=Decimal("10.000000"),
        total_cost=Decimal("150.000000"),
        quantity=Decimal("15.000"),
        unit="kg",
        is_active=True,
    )
    stock_2 = StockEntry(
        item_id=item.id,
        batch_id=batch_2.id,
        warehouse_id=w2.id,
        received_date=date(2026, 2, 2),
        source="seed",
        price_per_unit=Decimal("12.000000"),
        total_cost=Decimal("300.000000"),
        quantity=Decimal("25.000"),
        unit="kg",
        is_active=True,
    )
    db_session.add_all([stock_1, stock_2])
    db_session.flush()

    dispatch_1 = DispatchEntry(
        batch_id=batch_1.id,
        item_id=item.id,
        warehouse_id=w1.id,
        dispatch_date=date(2026, 2, 3),
        mart_id=mart.id,
        quantity=Decimal("5.000"),
        unit="kg",
        order_id=order_1.id,
    )
    dispatch_2 = DispatchEntry(
        batch_id=batch_2.id,
        item_id=item.id,
        warehouse_id=w2.id,
        dispatch_date=date(2026, 2, 3),
        mart_id=mart.id,
        quantity=Decimal("9.000"),
        unit="kg",
        order_id=order_2.id,
    )
    db_session.add_all([dispatch_1, dispatch_2])
    db_session.flush()

    db_session.add(
        DispatchReversal(
            dispatch_entry_id=dispatch_1.id,
            quantity=Decimal("1.000"),
            reason="seed",
        )
    )

    db_session.add(
        RejectionEntry(
            item_id=item.id,
            batch_id=batch_1.id,
            warehouse_id=w1.id,
            quantity=Decimal("2.000"),
            reason="seed",
            rejection_date=date(2026, 2, 3),
            unit="kg",
            is_active=True,
        )
    )

    db_session.add_all(
        [
            MartBill(
                mart_id=mart.id,
                warehouse_id=w1.id,
                invoice_date=date(2026, 2, 3),
                file_path="/tmp/w1.pdf",
                file_hash="w1-hash",
                total_amount=Decimal("500.000000"),
                status="VERIFIED",
            ),
            MartBill(
                mart_id=mart.id,
                warehouse_id=w2.id,
                invoice_date=date(2026, 2, 3),
                file_path="/tmp/w2.pdf",
                file_hash="w2-hash",
                total_amount=Decimal("900.000000"),
                status="VERIFIED",
            ),
            LabourCostDaily(
                warehouse_id=w1.id,
                date=date(2026, 2, 3),
                total_cost=Decimal("50.000000"),
            ),
            LabourCostDaily(
                warehouse_id=w2.id,
                date=date(2026, 2, 3),
                total_cost=Decimal("75.000000"),
            ),
            TransportCostDaily(
                warehouse_id=w1.id,
                date=date(2026, 2, 3),
                total_cost=Decimal("20.000000"),
            ),
            TransportCostDaily(
                warehouse_id=w2.id,
                date=date(2026, 2, 3),
                total_cost=Decimal("30.000000"),
            ),
        ]
    )
    db_session.commit()


def test_manager_unassigned_warehouse_blocked_for_kpi(db_session):
    main = _ensure_warehouse(db_session, "MAIN", "Main Warehouse")
    secondary = _ensure_warehouse(db_session, "SEC", "Secondary Warehouse")
    manager = _create_user(db_session, "kpi_manager", Role.MANAGER)
    _assign_user_warehouse(db_session, manager.id, main.id)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        manager.id, Role.MANAGER, manager.username
    )
    try:
        with TestClient(app) as client:
            response = client.get(
                "/v1/reports/financial-kpi",
                params={
                    "warehouse_id": secondary.id,
                    "start_date": "2026-02-01",
                    "end_date": "2026-02-10",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403
    assert response.json()["rule_id"] == "AUT-004"


def test_owner_must_specify_warehouse_for_kpi(db_session):
    owner = _create_user(db_session, "kpi_owner", Role.OWNER)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        owner.id, Role.OWNER, owner.username
    )
    try:
        with TestClient(app) as client:
            response = client.get(
                "/v1/reports/financial-kpi",
                params={
                    "start_date": "2026-02-01",
                    "end_date": "2026-02-10",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 400
    assert response.json()["detail"] == "warehouse_id is required"


def test_kpi_date_range_required(db_session):
    owner = _create_user(db_session, "kpi_owner_dates", Role.OWNER)
    main = _ensure_warehouse(db_session, "MAIN", "Main Warehouse")

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        owner.id, Role.OWNER, owner.username
    )
    try:
        with TestClient(app) as client:
            response = client.get(
                "/v1/reports/operational-kpi",
                params={"warehouse_id": main.id},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422


def test_kpi_results_are_warehouse_scoped(db_session):
    main = _ensure_warehouse(db_session, "MAIN", "Main Warehouse")
    secondary = _ensure_warehouse(db_session, "SEC", "Secondary Warehouse")
    owner = _create_user(db_session, "kpi_owner_data", Role.OWNER)
    _seed_kpi_data(db_session, main, secondary)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        owner.id, Role.OWNER, owner.username
    )

    try:
        with TestClient(app) as client:
            financial_main = client.get(
                "/v1/reports/financial-kpi",
                params={
                    "warehouse_id": main.id,
                    "start_date": "2026-02-01",
                    "end_date": "2026-02-10",
                },
            )
            financial_secondary = client.get(
                "/v1/reports/financial-kpi",
                params={
                    "warehouse_id": secondary.id,
                    "start_date": "2026-02-01",
                    "end_date": "2026-02-10",
                },
            )
            operational_main = client.get(
                "/v1/reports/operational-kpi",
                params={
                    "warehouse_id": main.id,
                    "start_date": "2026-02-01",
                    "end_date": "2026-02-10",
                },
            )
            operational_secondary = client.get(
                "/v1/reports/operational-kpi",
                params={
                    "warehouse_id": secondary.id,
                    "start_date": "2026-02-01",
                    "end_date": "2026-02-10",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert financial_main.status_code == 200
    assert financial_secondary.status_code == 200
    assert operational_main.status_code == 200
    assert operational_secondary.status_code == 200

    main_financial_payload = financial_main.json()
    secondary_financial_payload = financial_secondary.json()
    main_operational_payload = operational_main.json()
    secondary_operational_payload = operational_secondary.json()

    assert main_financial_payload["revenue"] == 500.0
    assert secondary_financial_payload["revenue"] == 900.0
    assert main_financial_payload["labour_cost"] == 50.0
    assert secondary_financial_payload["labour_cost"] == 75.0

    assert main_operational_payload["total_inward_qty"] == 15.0
    assert secondary_operational_payload["total_inward_qty"] == 25.0
    assert main_operational_payload["total_dispatch_qty"] == 5.0
    assert secondary_operational_payload["total_dispatch_qty"] == 9.0
