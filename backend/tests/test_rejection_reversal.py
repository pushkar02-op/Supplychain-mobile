import pytest
from decimal import Decimal
from app.core.exceptions import AppException
from app.db.models.stock_entry import StockEntry
from app.db.models.rejection_entry import RejectionEntry
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.item import Item
from app.db.models.batch import Batch
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.uom import UOM
from app.db.models.item_conversion_map import ItemConversionMap
from app.services.stock_entry import create_stock_entry, delete_stock_entry
from app.services.rejection_entry import create_rejection_entry, reverse_rejection_entry
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.schemas.rejection_entry import RejectionEntryCreate
from app.core.exceptions import AppException


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
    uom_l = UOM(code="l", description="Liter")  # For test cases
    session.add_all([uom_kg, uom_g, uom_l])
    session.flush()

    item = Item(name="Milk", default_uom_id=uom_l.id, item_code="MILK001")
    session.add(item)
    session.flush()

    # No conversion needed for L to L

    yield session
    session.close()


def test_db_init(db_session):
    assert True

    # def test_rejection_reversal_resolves_void_trap(db_session):
    """
    Refined Rejection Flow (Phase R3):
    1. Create Stock Entry (Receipt)
    2. Reject some items (Creates RejectionEntry)
    3. Try to Void Receipt -> BLOCKED ("Void Trap") -- This invariant MUST hold for active rejections
    4. Reverse Rejection (Refinement)
    5. Void Receipt -> ALLOWED (Trap Resolved)
    """

    # 1. Create Stock Entry
    entry_in = StockEntryCreate(
        received_date=date.today(),
        item_id=1,  # Assume seeded item 1 (Milk)
        quantity=Decimal("10.0"),
        unit="L",
        price_per_unit=1.0,
        total_cost=10.0,
    )
    receipt = create_stock_entry(db=db_session, entry=entry_in)
    batch_id = receipt.batch_id

    batch = db_session.query(Batch).filter(Batch.id == batch_id).first()
    assert batch.quantity == Decimal("10.0")

    # 2. Reject Items
    rej_in = RejectionEntryCreate(
        batch_id=batch_id,
        quantity=Decimal("2.0"),
        unit="L",
        reason="Damaged",
        rejection_date=date.today(),
        rejected_by="tester",
    )
    rejection = create_rejection_entry(db=db_session, entry=rej_in)

    db_session.refresh(batch)
    assert batch.quantity == Decimal("8.0")  # 10 - 2
    assert rejection.is_active is True

    # 3. Try to Void Receipt -> MUST BE BLOCKED
    # The system protects downstream history.
    with pytest.raises(AppException) as excinfo:
        delete_stock_entry(db=db_session, stock_entry_id=receipt.id)

    assert "Reverse rejections first" in excinfo.value.message

    # 4. Reverse Rejection (The Fix)
    success = reverse_rejection_entry(
        db=db_session, rejection_id=rejection.id, user_id=1
    )
    assert success is True

    # Verify Reversal State
    db_session.refresh(rejection)
    db_session.refresh(batch)
    assert rejection.is_active is False
    assert batch.quantity == Decimal("10.0")  # Restored! 8 + 2

    # 5. Void Receipt -> NOW ALLOWED
    # Since rejection is voided, it should no longer block the receipt void.
    void_success = delete_stock_entry(db=db_session, stock_entry_id=receipt.id)
    assert void_success is True

    # Verify Final State
    db_session.refresh(receipt)
    db_session.refresh(batch)
    assert receipt.is_active is False
    assert batch.quantity == Decimal("0.0")  # 10 - 10 (via void)


def test_reversal_is_idempotent_and_safe(db_session):
    # Setup similar to above
    entry_in = StockEntryCreate(
        received_date=date.today(),
        item_id=1,
        quantity=Decimal("5.0"),
        unit="L",
        price_per_unit=1.0,
        total_cost=5.0,
    )
    receipt = create_stock_entry(db=db_session, entry=entry_in)

    rej_in = RejectionEntryCreate(
        batch_id=receipt.batch_id,
        quantity=Decimal("1.0"),
        unit="L",
        reason="Expired",
        rejection_date=date.today(),
        rejected_by="tester",
    )
    rejection = create_rejection_entry(db=db_session, entry=rej_in)

    # Reverse once
    reverse_rejection_entry(db_session, rejection.id, 1)

    # Reverse again -> Should Fail (Already voided)
    with pytest.raises(AppException) as excinfo:
        reverse_rejection_entry(db_session, rejection.id, 1)
    assert "already voided" in excinfo.value.message
