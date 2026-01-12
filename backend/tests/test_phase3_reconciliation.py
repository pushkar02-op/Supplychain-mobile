"""
Phase 3: Reconciliation Tests
Verifies ledger drift detection using check_batch_drift and get_ledger_health_report.
"""

from datetime import datetime
from decimal import Decimal
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item_conversion_map import ItemConversionMap
from app.services.reconciliation import check_batch_drift, get_ledger_health_report
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base


def get_session():
    """In-memory SQLite for isolation."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    return Session()


def test_healthy_batch():
    """Test that a batch with matching ledger and cached quantities is healthy."""
    db = get_session()

    # Setup UOM & Item
    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item = Item(name="Rice", default_uom_id=uom.id, default_uom_code="kg")
    db.add(item)
    db.flush()

    # Create Batch with 100kg
    batch = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("100.0"),
        received_at=datetime.utcnow().date(),
    )
    db.add(batch)
    db.flush()

    # Create matching ledger entry (IN)
    txn = InventoryTxn(
        item_id=item.id,
        batch_id=batch.id,
        txn_type="IN",
        raw_qty=100.0,
        raw_unit="kg",
        base_qty=100.0,
        base_unit="kg",
        ref_type="stock_entry",
        ref_id=1,
        remarks="Test stock",
    )
    db.add(txn)
    db.commit()

    # Check batch drift
    result = check_batch_drift(db, batch.id)

    assert result["status"] == "healthy"
    assert result["is_drifted"] is False
    assert abs(result["drift"]) < 0.01
    print("PASS: Healthy Batch Detection")


def test_drifted_batch():
    """Test that a batch with mismatched ledger and cached quantities is drifted."""
    db = get_session()

    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item = Item(name="Wheat", default_uom_id=uom.id, default_uom_code="kg")
    db.add(item)
    db.flush()

    # Create Batch with 100kg (cached)
    batch = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("100.0"),
        received_at=datetime.utcnow().date(),
    )
    db.add(batch)
    db.flush()

    # Create ledger entry with DIFFERENT quantity (only 80kg IN)
    txn = InventoryTxn(
        item_id=item.id,
        batch_id=batch.id,
        txn_type="IN",
        raw_qty=80.0,
        raw_unit="kg",
        base_qty=80.0,
        base_unit="kg",
        ref_type="stock_entry",
        ref_id=1,
        remarks="Test stock",
    )
    db.add(txn)
    db.commit()

    # Check batch drift (100 cached - 80 ledger = 20 drift)
    result = check_batch_drift(db, batch.id)

    assert result["status"] == "drifted"
    assert result["is_drifted"] is True
    assert result["drift"] == 20.0
    print("PASS: Drifted Batch Detection")


def test_ledger_health_report():
    """Test that health report includes drifted batches."""
    db = get_session()

    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item = Item(name="Sugar", default_uom_id=uom.id, default_uom_code="kg")
    db.add(item)
    db.flush()

    # Create healthy batch
    batch_healthy = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("50.0"),
        received_at=datetime.utcnow().date(),
    )
    db.add(batch_healthy)
    db.flush()

    txn_healthy = InventoryTxn(
        item_id=item.id,
        batch_id=batch_healthy.id,
        txn_type="IN",
        raw_qty=50.0,
        raw_unit="kg",
        base_qty=50.0,
        base_unit="kg",
        ref_type="stock_entry",
        ref_id=1,
        remarks="Healthy stock",
    )
    db.add(txn_healthy)

    # Create drifted batch
    batch_drifted = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("100.0"),
        received_at=datetime.utcnow().date(),
    )
    db.add(batch_drifted)
    db.flush()

    txn_drifted = InventoryTxn(
        item_id=item.id,
        batch_id=batch_drifted.id,
        txn_type="IN",
        raw_qty=50.0,  # Only 50 recorded but 100 cached
        raw_unit="kg",
        base_qty=50.0,
        base_unit="kg",
        ref_type="stock_entry",
        ref_id=2,
        remarks="Drifted stock",
    )
    db.add(txn_drifted)
    db.commit()

    # Get health report
    report = get_ledger_health_report(db)

    # Should include drifted batch only
    assert len(report) == 1
    assert report[0]["batch_id"] == batch_drifted.id
    assert report[0]["is_drifted"] is True
    print("PASS: Ledger Health Report")


if __name__ == "__main__":
    try:
        test_healthy_batch()
        test_drifted_batch()
        test_ledger_health_report()
        print("\n=== ALL PHASE 3 TESTS PASSED ===")
    except Exception as e:
        import traceback

        traceback.print_exc()
