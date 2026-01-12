"""
Phase 3: Reconciliation & Dispute Handling Tests
Verifies REC-001, REC-002, REC-003, REC-004
"""

from datetime import datetime, timedelta
from decimal import Decimal
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.batch import Batch
from app.db.models.stock_entry import StockEntry
from app.db.models.reconciliation_mismatch import (
    ReconciliationMismatch,
    MismatchType,
    MismatchStatus,
)
from app.services.reconciliation import run_invoice_reconciliation, resolve_mismatch
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base


def get_session():
    """In-memory SQLite for isolation."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    return Session()


def test_mismatch_classification():
    """Test that different mismatch types are correctly classified."""
    db = get_session()

    # Setup UOM & Item
    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item = Item(name="Rice", default_uom_id=uom.id)
    db.add(item)

    mart = Mart(name="Test Mart", company_name="Test Co")
    db.add(mart)
    db.commit()

    # Setup MartBill with resolved item
    mart_bill = MartBill(
        invoice_date=datetime.utcnow().date(),
        file_path="test.pdf",
        file_hash="hash001",
        total_amount=1000.0,
        mart_id=mart.id,
    )
    db.add(mart_bill)
    db.flush()

    bill_item = MartBillItem(
        mart_bill_id=mart_bill.id,
        item_id=item.id,  # Resolved
        item_name="Rice",
        item_code="RICE-001",
        quantity=100.0,
        uom="kg",
        price=10.0,
        total=1000.0,
        invoice_date=mart_bill.invoice_date,
        store_name="Test Store",
    )
    db.add(bill_item)
    db.commit()

    # Run reconciliation (no stock entry = MISSING_ENTRY)
    results = run_invoice_reconciliation(db, mart_bill.id)

    assert len(results) == 1
    assert results[0]["type"] == MismatchType.MISSING_ENTRY.value
    print("PASS: Mismatch Classification (MISSING_ENTRY)")


def test_quantity_mismatch():
    """Test quantity mismatch detection."""
    db = get_session()

    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item = Item(name="Wheat", default_uom_id=uom.id)
    db.add(item)

    mart = Mart(name="Mart B", company_name="Co B")
    db.add(mart)
    db.commit()

    # Create Batch & StockEntry
    batch = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("50.0"),
        received_at=datetime.utcnow().date(),
    )
    db.add(batch)
    db.flush()

    stock = StockEntry(
        item_id=item.id,
        batch_id=batch.id,
        received_date=datetime.utcnow().date(),
        quantity=50.0,
        unit="kg",
        price_per_unit=10.0,
        total_cost=500.0,
    )
    db.add(stock)

    # Create MartBill with DIFFERENT quantity
    mart_bill = MartBill(
        invoice_date=datetime.utcnow().date(),
        file_path="test2.pdf",
        file_hash="hash002",
        total_amount=600.0,
        mart_id=mart.id,
    )
    db.add(mart_bill)
    db.flush()

    bill_item = MartBillItem(
        mart_bill_id=mart_bill.id,
        item_id=item.id,
        item_name="Wheat",
        item_code="WHEAT-001",
        quantity=60.0,  # Different from stock (50)
        uom="kg",
        price=10.0,
        total=600.0,
        invoice_date=mart_bill.invoice_date,
        store_name="Store B",
    )
    db.add(bill_item)
    db.commit()

    results = run_invoice_reconciliation(db, mart_bill.id)

    assert len(results) == 1
    assert results[0]["type"] == MismatchType.QUANTITY.value
    print("PASS: Quantity Mismatch Detected")


def test_dispute_resolution():
    """Test admin dispute resolution workflow."""
    db = get_session()

    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item = Item(name="Sugar", default_uom_id=uom.id)
    db.add(item)

    mart = Mart(name="Mart C", company_name="Co C")
    db.add(mart)
    db.commit()

    mart_bill = MartBill(
        invoice_date=datetime.utcnow().date(),
        file_path="test3.pdf",
        file_hash="hash003",
        total_amount=100.0,
        mart_id=mart.id,
    )
    db.add(mart_bill)
    db.flush()

    bill_item = MartBillItem(
        mart_bill_id=mart_bill.id,
        item_id=None,  # UNRESOLVED
        item_name="Unknown Sugar",
        item_code=None,
        quantity=10.0,
        uom="kg",
        price=10.0,
        total=100.0,
        invoice_date=mart_bill.invoice_date,
        store_name="Store C",
    )
    db.add(bill_item)
    db.commit()

    # Run reconciliation (creates IDENTITY mismatch)
    results = run_invoice_reconciliation(db, mart_bill.id)
    assert results[0]["type"] == MismatchType.IDENTITY.value

    mismatch_id = results[0]["mismatch_id"]

    # Resolve as SYSTEM
    resolution = resolve_mismatch(
        db, mismatch_id, "SYSTEM", "admin_user", "Test resolution"
    )

    assert resolution["new_status"] == MismatchStatus.RESOLVED_SYSTEM.value
    print("PASS: Dispute Resolution Workflow")


if __name__ == "__main__":
    try:
        test_mismatch_classification()
        test_quantity_mismatch()
        test_dispute_resolution()
        print("\n=== ALL PHASE 3 TESTS PASSED ===")
    except Exception as e:
        import traceback

        traceback.print_exc()
