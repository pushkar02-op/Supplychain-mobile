import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from decimal import Decimal
from datetime import date

from app.db.base import Base
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.mart import Mart
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.models.batch import Batch
from app.db.models.order import Order
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.schemas.dispatch_entry import DispatchEntryCreate, DispatchEntryMultiCreate
from app.db.schemas.rejection_entry import RejectionEntryCreate
from app.services.stock_entry import (
    create_stock_entry,
    update_stock_entry,
    delete_stock_entry,
)
from app.services.dispatch_entry import (
    create_dispatch_entry,
    delete_dispatch_entry,
    create_dispatch_from_order,
)
from app.services.rejection_entry import create_rejection_entry
from app.core.exceptions import AppException


# Setup In-Memory DB
@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # Pre-Seed Data
    uom_kg = UOM(code="kg", name="Kilogram")
    uom_g = UOM(code="g", name="Gram")
    session.add_all([uom_kg, uom_g])
    session.flush()

    item = Item(name="Rice", default_uom_code="kg", default_uom_id=uom_kg.id)
    session.add(item)
    session.flush()

    # Conversion: g -> kg = 0.001
    conv = ItemConversionMap(
        item_id=item.id,
        source_unit="g",
        target_unit="kg",
        conversion_factor=0.001,
        created_by="test",
    )
    session.add(conv)

    mart = Mart(name="TestMart", district="D1")
    session.add(mart)
    session.commit()

    yield session
    session.close()


def test_stock_entry_canonicalization(db_session):
    item = db_session.query(Item).first()

    # 1. Create Stock Entry in 'g' (Non-Canonical)
    # Expected: Batch created in 'kg' (Canonical)
    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=500,  # 500g
        unit="g",
        received_date=date.today(),
        remarks="Test Stock",
    )

    stock_entry = create_stock_entry(db_session, entry_data, created_by=1)

    batch = db_session.query(Batch).filter(Batch.id == stock_entry.batch_id).first()

    # INV-005 Verification
    assert batch.unit == "kg"
    assert batch.quantity == Decimal("0.500")  # 500 * 0.001

    # Verify Ledger
    txn = (
        db_session.query(batch.inventory_txns[0].__class__)
        .filter_by(ref_id=stock_entry.id)
        .first()
    )
    assert txn.raw_qty == 500
    assert txn.raw_unit == "g"
    assert txn.base_qty == Decimal("0.500")
    assert txn.base_unit == "kg"


def test_dispatch_entry_canonicalization(db_session):
    item = db_session.query(Item).first()
    mart = db_session.query(Mart).first()

    # Setup: 1kg Batch
    entry_data = StockEntryCreate(
        item_id=item.id, quantity=1, unit="kg", received_date=date.today()
    )
    create_stock_entry(db_session, entry_data, created_by=1)
    batch = db_session.query(Batch).first()
    assert batch.quantity == Decimal("1.000")

    # Dispatch 200g
    dispatch_data = DispatchEntryCreate(
        item_id=item.id,
        batch_id=batch.id,
        mart_name=mart.name,
        dispatch_date=date.today(),
        quantity=200,
        unit="g",
        remarks="Sending samples",
    )

    # Need an Order first usually? dispatch_entry check: "If exists... if order..."
    # create_dispatch_entry updates order status IF it exists, but strict dependency?
    # No, it does `_update_order_after_dispatch`. If order not found, it returns (line ~368 in original, now ~375).
    # So we don't strictly need Order for create_dispatch_entry (Single).

    dispatch = create_dispatch_entry(db_session, dispatch_data, created_by="tester")

    db_session.refresh(batch)

    # Expect: 1.0 - (200 * 0.001) = 1.0 - 0.2 = 0.8
    assert batch.quantity == Decimal("0.800")
    assert batch.unit == "kg"

    # Verify Ledger
    txn = (
        db_session.query(batch.inventory_txns[0].__class__)
        .filter(batch.inventory_txns[0].__class__.ref_type == "dispatch_entry")
        .first()
    )
    assert txn.base_qty == Decimal("0.200")


def test_rejection_entry_canonicalization(db_session):
    item = db_session.query(Item).first()

    # Setup: 1kg Batch
    entry_data = StockEntryCreate(
        item_id=item.id, quantity=1, unit="kg", received_date=date.today()
    )
    create_stock_entry(db_session, entry_data, created_by=1)
    batch = db_session.query(Batch).first()

    # Reject 500g
    reject_data = RejectionEntryCreate(
        batch_id=batch.id, quantity=500, reason="Damaged", unit="g"
    )

    create_rejection_entry(db_session, reject_data, created_by="tester")

    db_session.refresh(batch)
    assert batch.quantity == Decimal("0.500")


def test_decimal_safety(db_session):
    item = db_session.query(Item).first()
    # Batch 10kg
    create_stock_entry(
        db_session,
        StockEntryCreate(
            item_id=item.id, quantity=10, unit="kg", received_date=date.today()
        ),
        created_by=1,
    )
    batch = db_session.query(Batch).first()

    # Dispatch 1/3 kg -> 0.333333...
    # If float, might cause issues.
    # If Decimal, handles it better?
    # Our system uses Decimal everywhere now.

    dispatch_data = DispatchEntryCreate(
        item_id=item.id,
        batch_id=batch.id,
        mart_name="TestMart",
        dispatch_date=date.today(),
        quantity=Decimal("3.333"),
        unit="kg",
    )
    create_dispatch_entry(db_session, dispatch_data)

    db_session.refresh(batch)
    assert batch.quantity == Decimal("10") - Decimal("3.333")
    assert batch.quantity == Decimal("6.667")


def test_insufficient_stock(db_session):
    item = db_session.query(Item).first()
    create_stock_entry(
        db_session,
        StockEntryCreate(
            item_id=item.id, quantity=1, unit="kg", received_date=date.today()
        ),
        created_by=1,
    )
    batch = db_session.query(Batch).first()

    # Try dispatch 1.1 kg
    with pytest.raises(AppException) as exc:
        create_dispatch_entry(
            db_session,
            DispatchEntryCreate(
                item_id=item.id,
                batch_id=batch.id,
                mart_name="TestMart",
                dispatch_date=date.today(),
                quantity=1.1,
                unit="kg",
            ),
        )
    assert "Not enough stock" in str(exc.value)
