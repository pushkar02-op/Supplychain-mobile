import os
import tempfile
import pytest
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from fastapi.testclient import TestClient

from app.main import app
from app.db.base import Base
from app.db.session import get_db
from app.core.auth import get_current_active_admin
from app.db.models import (
    User,
    Item,
    Batch,
    StockEntry,
    RejectionEntry,
    DispatchEntry,
    InventoryTxn,
    UOM,
    Mart,
)
from app.db.models.reconciliation_record import ReconciliationRecord, DriftStatus
from app.db.models.mart_item_alias import MartItemAlias
from app.domain.drift_policy import classify_drift_ratio

from app.services.reconciliation import (
    check_batch_drift,
    create_drift_record,
    resolve_drift,
)


@pytest.fixture(scope="function")
def db_session():
    # Use a temporary file for SQLite to ensure all connections see the same data
    db_fd, db_path = tempfile.mkstemp()
    db_url = f"sqlite:///{db_path}"
    engine = create_engine(db_url, connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # We MUST ensure the DB URL in dependencies results in a connection to THIS file
    # But since we override get_db to return this session, we don't need to change URL.

    yield session

    session.close()
    engine.dispose()
    os.close(db_fd)
    if os.path.exists(db_path):
        os.unlink(db_path)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def admin_token_headers():
    # Mocking admin token behavior
    from app.db.models.user import User

    mock_admin = User(
        id=1,
        username="admin",
        full_name="Admin User",
        hashed_password="pw",
        is_active=True,
        is_admin=True,
    )

    def override_get_admin():
        return mock_admin

    app.dependency_overrides[get_current_active_admin] = override_get_admin
    return {"Authorization": "Bearer test-admin-token"}


def test_severity_logic_standardization(db_session: Session):
    # Setup: Item and Batch
    uom = UOM(description="Unit", code="UNT")
    db_session.add(uom)
    db_session.commit()

    item = Item(name="Test Item", item_code="TI1", default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()

    # Batch with 100 units (State)
    batch = Batch(
        item_id=item.id,
        quantity=Decimal("100.0"),
        unit="UNT",
        received_at=date(2024, 1, 1),
    )
    db_session.add(batch)
    db_session.commit()

    # Case 1: Healthy (Ledger 100, State 100)
    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("100.0"),
            raw_unit="UNT",
            base_qty=Decimal("100.0"),
            base_unit="UNT",
        )
    )
    db_session.commit()

    drift_report = check_batch_drift(db_session, batch.id)
    assert drift_report["severity"] == "NONE"
    assert drift_report["status"] == "healthy"
    assert drift_report["drift"] == 0

    # Case 2: Major Drift (e.g. 2% drift)
    # Ledger is 100. State is 100. Let's make Ledger 102.
    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("2.0"),
            raw_unit="UNT",
            base_qty=Decimal("2.0"),
            base_unit="UNT",
        )
    )
    db_session.commit()

    drift_report = check_batch_drift(db_session, batch.id)
    # Ledger 102, State 100. Drift = -2. 2/102 ~= 1.9%. Should be MAJOR (< 5%)
    assert drift_report["severity"] == "MAJOR"
    assert drift_report["drift"] == -2

    # Case 3: Critical Drift (e.g. 10% drift)
    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("10.0"),
            raw_unit="UNT",
            base_qty=Decimal("10.0"),
            base_unit="UNT",
        )
    )
    db_session.commit()
    # Ledger 112, State 100. Drift = -12. 12/112 ~= 10.7%. Should be CRITICAL (> 5%)
    drift_report = check_batch_drift(db_session, batch.id)
    assert drift_report["severity"] == "CRITICAL"


def test_drift_record_creation_and_resolution(db_session: Session):
    # Setup
    uom = UOM(description="Unit", code="UNT")
    db_session.add(uom)
    db_session.commit()
    item = Item(name="Sync Item", item_code="SI1", default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()

    # State = 100
    batch = Batch(item_id=item.id, quantity=Decimal("100.0"), unit="UNT")
    db_session.add(batch)
    db_session.commit()

    # Ledger = 110 (Drift of -10)
    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("110.0"),
            raw_unit="UNT",
            base_qty=Decimal("110.0"),
            base_unit="UNT",
        )
    )
    db_session.commit()

    # Create Drift Record
    record = create_drift_record(db_session, batch.id)
    assert record is not None
    assert record.drift_amount == Decimal("-10.0")
    assert record.status == DriftStatus.OPEN

    # Resolve Drift (Adjust Ledger by +10 to match state? Or Adjust Ledger by -10?)
    # If Ledger is 110 and State is 100. Ledger is "Ahead".
    # We want Ledger to match State (100). So we subtract 10 from Ledger.
    # resolve_drift creates an ADJUST txn.

    result = resolve_drift(
        db_session,
        record.id,
        adjustment_qty=Decimal("-10.0"),
        user_id=1,
        apply_to_batch=False,
    )
    assert result["status"] == "success"

    db_session.refresh(record)
    assert record.status == DriftStatus.RESOLVED
    assert record.resolution_txn_id is not None

    # Verify Ledger now matches State
    drift_after = check_batch_drift(db_session, batch.id)
    assert drift_after["drift"] == 0
    assert drift_after["severity"] == "NONE"


def test_create_drift_record_is_idempotent_for_open_record(db_session: Session):
    uom = UOM(description="Unit", code="UNT")
    db_session.add(uom)
    db_session.commit()

    item = Item(name="Idempotent Item", item_code="IDM1", default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()

    batch = Batch(item_id=item.id, quantity=Decimal("100.0"), unit="UNT")
    db_session.add(batch)
    db_session.commit()

    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("110.0"),
            raw_unit="UNT",
            base_qty=Decimal("110.0"),
            base_unit="UNT",
        )
    )
    db_session.commit()

    first_record = create_drift_record(db_session, batch.id)
    second_record = create_drift_record(db_session, batch.id)

    assert first_record is not None
    assert second_record is not None
    assert first_record.id == second_record.id

    open_records = (
        db_session.query(ReconciliationRecord)
        .filter(
            ReconciliationRecord.batch_id == batch.id,
            ReconciliationRecord.status == DriftStatus.OPEN,
        )
        .all()
    )
    assert len(open_records) == 1


def test_resolve_drift_second_attempt_returns_error(db_session: Session):
    uom = UOM(description="Unit", code="UNT")
    db_session.add(uom)
    db_session.commit()

    item = Item(name="Resolve Once Item", item_code="RS1", default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()

    batch = Batch(item_id=item.id, quantity=Decimal("100.0"), unit="UNT")
    db_session.add(batch)
    db_session.commit()

    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("110.0"),
            raw_unit="UNT",
            base_qty=Decimal("110.0"),
            base_unit="UNT",
        )
    )
    db_session.commit()

    record = create_drift_record(db_session, batch.id)
    assert record is not None

    first_result = resolve_drift(
        db_session,
        record.id,
        adjustment_qty=Decimal("-10.0"),
        user_id=1,
        apply_to_batch=False,
    )
    assert first_result["status"] == "success"

    second_result = resolve_drift(
        db_session,
        record.id,
        adjustment_qty=Decimal("-10.0"),
        user_id=1,
        apply_to_batch=False,
    )
    assert second_result["error"] == "Record is not open"


def test_drift_ratio_policy_preserves_threshold_behavior():
    assert classify_drift_ratio(Decimal("0.0500")) == "MAJOR"
    assert classify_drift_ratio(Decimal("0.0501")) == "CRITICAL"


def test_admin_ledger_api_truth(client, admin_token_headers):
    # This requires a real app client. We assume 'client' is a TestClient.
    # We'll just verify the endpoint structure matches the Phase 5 requirement.
    response = client.get("/v1/admin/ledger/health", headers=admin_token_headers)
    assert response.status_code == 200
    data = response.json()
    assert "drifted_batches" in data
    assert "negative_stock_batches" in data
    assert "total_batches" in data

    response = client.get(
        "/v1/reports/inventory/reconciliation", headers=admin_token_headers
    )
    assert response.status_code == 200
    items = response.json()
    if items:
        # Check standardized keys
        assert "ledger_qty" in items[0]
        assert "state_qty" in items[0]
        assert "drift" in items[0]
        assert "severity" in items[0]
