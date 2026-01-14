import pytest
from decimal import Decimal
from sqlalchemy.orm import Session
from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.reconciliation_record import ReconciliationRecord, DriftStatus
from app.services.reconciliation import (
    check_batch_drift,
    create_drift_record,
    resolve_drift,
)


def test_severity_logic_standardization(db_session: Session):
    # Setup: Item and Batch
    uom = UOM(name="Unit", code="UNT", is_base=True)
    db_session.add(uom)
    db_session.commit()

    item = Item(name="Test Item", item_code="TI1", default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()

    # Batch with 100 units (State)
    batch = Batch(
        item_id=item.id, quantity=Decimal("100.0"), unit="UNT", received_at="2024-01-01"
    )
    db_session.add(batch)
    db_session.commit()

    # Case 1: Healthy (Ledger 100, State 100)
    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
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
    uom = UOM(name="Unit", code="UNT", is_base=True)
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
