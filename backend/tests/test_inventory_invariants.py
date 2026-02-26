from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.models.mart import Mart
from app.db.models.uom import UOM
from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.db.schemas.stock_entry import StockEntryCreate
from app.services.dispatch_entry import create_dispatch_entry
from app.services.inventory_truth import calculate_ledger_balance, get_drift_report
from app.services.stock_entry import create_stock_entry


# Setup In-Memory DB
@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, checkfirst=True)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # Pre-Seed Data
    uom_kg = UOM(code="kg", description="Kilogram")
    uom_g = UOM(code="g", description="Gram")
    session.add_all([uom_kg, uom_g])
    session.flush()

    item = Item(name="Rice", default_uom_id=uom_kg.id, item_code="RICE001")
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

    mart = Mart(name="TestMart", company_name="TestCo")
    session.add(mart)
    session.commit()

    yield session
    session.close()


def test_stock_entry_creates_ledger_record(db_session):
    """
    Invariant: Stock Entry creation MUST create an "IN" InventoryTxn via logic.
    """
    item = db_session.query(Item).first()

    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=10,
        unit="kg",
        received_date=date.today(),
        price_per_unit=100.0,
        total_cost=1000.0,
        source="Vendor",
    )

    stock_entry = create_stock_entry(db_session, entry_data, created_by=1)
    batch_id = stock_entry.batch_id

    # 1. State check
    batch = db_session.query(Batch).filter(Batch.id == batch_id).first()
    assert batch.quantity == Decimal("10.000")

    # 2. Ledger Check
    ledger_balance = calculate_ledger_balance(db_session, batch_id)
    assert ledger_balance == Decimal("10.000")

    # 3. Drift Check
    report = get_drift_report(db_session, batch_id)
    assert not report["is_drifted"]
    assert report["drift"] == Decimal("0")


def test_dispatch_entry_creates_ledger_record(db_session):
    """
    Invariant: Dispatch Entry creation MUST create an "OUT" InventoryTxn via logic.
    """
    item = db_session.query(Item).first()
    mart = db_session.query(Mart).first()

    # Setup stock
    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=10,
        unit="kg",
        received_date=date.today(),
        price_per_unit=100.0,
        total_cost=1000.0,
    )
    create_stock_entry(db_session, entry_data, created_by=1)
    batch = db_session.query(Batch).first()

    # Dispatch 2kg
    dispatch_data = DispatchEntryCreate(
        item_id=item.id,
        batch_id=batch.id,
        mart_name=mart.name,
        quantity=2,
        unit="kg",
        dispatch_date=date.today(),
    )
    create_dispatch_entry(db_session, dispatch_data, created_by="tester")

    db_session.refresh(batch)

    # 1. State check
    assert batch.quantity == Decimal("8.000")

    # 2. Ledger Check
    # Should be 10 (IN) - 2 (OUT) = 8
    ledger_balance = calculate_ledger_balance(db_session, batch.id)
    assert ledger_balance == Decimal("8.000")

    # 3. Drift Check
    report = get_drift_report(db_session, batch.id)
    assert not report["is_drifted"]


def test_ledger_drift_detection(db_session):
    """
    Invariant: Drift is allowed but must be explainable (detected).
    """
    item = db_session.query(Item).first()

    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=10,
        unit="kg",
        received_date=date.today(),
        price_per_unit=100.0,
        total_cost=1000.0,
    )
    create_stock_entry(db_session, entry_data, created_by=1)
    batch = db_session.query(Batch).first()

    # FORCE DRIFT: Manually update batch quantity WITHOUT creating a Txn
    # This simulates a bug or manual DB intervention
    batch.quantity = Decimal("9.500")  # Lost 0.5kg mysteriously
    db_session.commit()

    # 1. State check
    assert batch.quantity == Decimal("9.500")

    # 2. Ledger Check (Should still be 10)
    ledger_balance = calculate_ledger_balance(db_session, batch.id)
    assert ledger_balance == Decimal("10.000")

    # 3. Drift Check
    report = get_drift_report(db_session, batch.id)
    assert report["is_drifted"]
    assert report["drift"] == Decimal("-0.500")  # State - Ledger = 9.5 - 10 = -0.5
