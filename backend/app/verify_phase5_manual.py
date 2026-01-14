import traceback
from datetime import date
from decimal import Decimal

from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.reconciliation_record import DriftStatus
from app.db.models.uom import UOM
from app.services.reconciliation import (
    check_batch_drift,
    create_drift_record,
    resolve_drift,
)
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


def get_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, checkfirst=True)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # Pre-Seed Data
    uom_kg = UOM(code="kg", description="Kilogram")
    session.add(uom_kg)
    session.flush()

    item = Item(name="Test Item 1", item_code="ITEM001", default_uom_id=uom_kg.id)
    session.add(item)
    session.flush()

    # Batch (State) = 100kg
    batch = Batch(
        item_id=item.id,
        quantity=Decimal("100.0"),
        unit="kg",
        received_at=date(2025, 1, 1),
    )
    session.add(batch)
    session.commit()
    return session


def test_truth_standardization(db):
    print("Testing Truth Standardization...")
    batch = db.query(Batch).first()
    item = db.query(Item).first()

    # 1. Healthy Case: Ledger matches State
    db.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("100.0"),
            raw_unit="kg",
            base_qty=Decimal("100.0"),
            base_unit="kg",
        )
    )
    db.commit()

    report = check_batch_drift(db, batch.id)
    assert report["state_qty"] == 100.0
    assert report["ledger_qty"] == 100.0
    assert report["drift"] == 0.0
    assert report["severity"] == "NONE"
    assert report["status"] == "healthy"
    print("   ✓ Healthy Case Pass")

    # 2. Major Drift: Ledger is 104 (Drift = -4) -> 4% drift
    db.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("4.0"),
            raw_unit="kg",
            base_qty=Decimal("4.0"),
            base_unit="kg",
        )
    )
    db.commit()

    report = check_batch_drift(db, batch.id)
    assert report["drift"] == -4.0
    assert report["severity"] == "MAJOR"  # Drift < 5%
    print("   ✓ Major Drift Pass")

    # 3. Critical Drift: Ledger is 115 (Drift = -15) -> >5% drift
    db.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("11.0"),
            raw_unit="kg",
            base_qty=Decimal("11.0"),
            base_unit="kg",
        )
    )
    db.commit()

    report = check_batch_drift(db, batch.id)
    assert report["severity"] == "CRITICAL"
    print("   ✓ Critical Drift Pass")


def test_drift_mutation(db):
    print("Testing Drift Record Mutation...")
    batch = db.query(Batch).first()

    # Create Record
    record = create_drift_record(db, batch.id)
    assert record is not None
    assert record.status == DriftStatus.OPEN
    assert record.drift_amount == Decimal("-15.0")
    print("   ✓ Record Creation Pass")

    # Resolve Record
    result = resolve_drift(
        db, record.id, adjustment_qty=Decimal("-15.0"), user_id=1, apply_to_batch=False
    )
    assert result["status"] == "success"
    assert record.status == DriftStatus.RESOLVED
    print("   ✓ Record Resolution Pass")


if __name__ == "__main__":
    try:
        session = get_session()
        test_truth_standardization(session)
        test_drift_mutation(session)
        print("\nALL PHASE 5 MANUAL TESTS PASSED")
    except Exception:
        traceback.print_exc()
        exit(1)
