from decimal import Decimal
from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.item_conversion_map import ItemConversionMap
from app.core.exceptions import AppException
from app.services.stock_entry import create_stock_adjustment, create_stock_entry
from app.services.stock_history import get_stock_history
from app.db.schemas.stock_entry import StockEntryCreate


# Setup In-Memory DB
@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, checkfirst=True)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # Pre-Seed Data
    uom_kg = UOM(code="kg", description="Kilogram")
    session.add(uom_kg)
    session.flush()

    item = Item(name="Rice", default_uom_id=uom_kg.id, item_code="RICE001")
    session.add(item)
    session.flush()

    yield session
    session.close()


def test_get_stock_history_receipt_only(db_session):
    # 1. Create Stock Entry
    entry = create_stock_entry(
        db_session,
        StockEntryCreate(
            item_id=1,
            received_date="2025-01-01",
            quantity=10.0,
            unit="kg",
            price_per_unit=5.0,
            total_cost=50.0,
            source="Test Source",
        ),
        created_by=1,
    )

    # 2. Get History
    history = get_stock_history(db_session, entry.id)

    # 3. Assert Receipt details
    assert history.receipt.id == entry.id
    assert history.receipt.quantity == 10.0
    assert history.receipt.unit == "kg"
    assert history.adjustments == []
    assert history.is_voided is False


def test_get_stock_history_with_adjustments(db_session):
    # 1. Create Stock Entry
    entry = create_stock_entry(
        db_session,
        StockEntryCreate(
            item_id=1,
            received_date="2025-01-01",
            quantity=10.0,
            unit="kg",
            price_per_unit=5.0,
            total_cost=50.0,
        ),
        created_by=1,
    )

    # 2. Add Adjustments (via create_stock_adjustment)
    create_stock_adjustment(
        db_session,
        batch_id=entry.batch_id,
        quantity_delta=Decimal("-2.0"),
        unit="kg",
        reason="Spoilage",
        user_id=1,
    )

    # Add positive adjustment
    create_stock_adjustment(
        db_session,
        batch_id=entry.batch_id,
        quantity_delta=Decimal("1.5"),
        unit="kg",
        reason="Found extra",
        user_id=1,
    )

    # 3. Get History
    history = get_stock_history(db_session, entry.id)

    # 4. Assert Adjustments
    assert len(history.adjustments) == 2

    # Check ordering (reverse chronological)
    # The second adjustment was created last, so it should be first
    adj1 = history.adjustments[0]
    adj2 = history.adjustments[1]

    # Assert values
    assert adj1.quantity_delta == 1.5
    assert adj1.reason == "Found extra"

    assert adj2.quantity_delta == -2.0
    assert adj2.reason == "Spoilage"


def test_get_stock_history_not_found(db_session):
    with pytest.raises(AppException) as e:
        get_stock_history(db_session, 99999)
    assert e.value.status_code == 404


def test_soft_delete_and_void_history(db_session):
    from app.services.stock_entry import delete_stock_entry
    
    # 1. Create Stock Entry
    entry = create_stock_entry(
        db_session,
        StockEntryCreate(
            item_id=1,
            received_date="2025-01-01",
            quantity=10.0,
            unit="kg",
            price_per_unit=5.0,
            total_cost=50.0,
        ),
        created_by=1,
    )
    
    # 2. Soft Delete (Void)
    success = delete_stock_entry(db_session, entry.id)
    assert success is True
    
    # 3. Verify entry still exists but is inactive
    assert entry.is_active is False
    
    # 4. Get History
    history = get_stock_history(db_session, entry.id)
    
    # 5. Assert Void Status
    assert history.is_voided is True
    assert history.voided_at is not None
    assert history.receipt.quantity == 10.0  # Original data preserved
