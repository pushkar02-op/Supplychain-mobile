import pytest
from datetime import date
from decimal import Decimal
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.models.uom import UOM
from app.db.schemas.stock_entry import StockEntryCreate, StockEntryUpdate
from app.services.stock_entry import delete_stock_entry
from app.core.exceptions import AppException
from app.services.inventory_truth import calculate_ledger_balance


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
    uom_l = UOM(code="l", description="Liter")  # Incompatible unit
    session.add_all([uom_kg, uom_g, uom_l])
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
    session.commit()

    yield session
    session.close()


def test_stock_entry_is_immutable(db_session):
    """
    Invariant: Updating a stock entry via update_stock_entry is FORBIDDEN.
    Should raise HTTP 409.
    """
    item = db_session.query(Item).first()

    # 1. Create Initial Entry
    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=10,
        unit="kg",
        received_date=date.today(),
        price_per_unit=100.0,
        total_cost=1000.0,
        source="Vendor A",
    )
    stock_entry = create_stock_entry(db_session, entry_data, created_by=1)

    # 2. Attempt Update
    update_data = StockEntryUpdate(quantity=20)

    with pytest.raises(AppException) as excinfo:
        update_stock_entry(db_session, stock_entry.id, update_data, updated_by=1)

    assert excinfo.value.status_code == 409
    assert "immutable" in str(excinfo.value.message).lower()


def test_create_stock_entry_enforces_unit_compatibility(db_session):
    """
    Invariant: Creating stock entry with incompatible unit (not convertible to default)
    must fail validation.
    """
    item = db_session.query(Item).first()  # Default UOM is kg

    # Try creating with 'Liter' which has no conversion map to 'kg'
    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=10,
        unit="l",  # Incompatible
        received_date=date.today(),
        price_per_unit=100.0,
        total_cost=1000.0,
    )

    with pytest.raises(AppException) as excinfo:
        create_stock_entry(db_session, entry_data, created_by=1)

    # Should probably be 400 Bad Request or UOMConfigurationError (which is an AppException)
    # The key is it should fail, not silently accept raw unit.
    assert excinfo.value.status_code in [400, 422]


def test_stock_adjustment_creates_txn_and_updates_batch(db_session):
    """
    Invariant: Use create_stock_adjustment (to be implemented) for corrections.
    Must generate 'ADJUST' txn and update batch quantity.
    """
    # This test assumes create_stock_adjustment will be imported
    # For now, we can try to import it inside the test or skip if not implemented yet
    try:
        from app.services.stock_entry import create_stock_adjustment
    except ImportError:
        pytest.fail("create_stock_adjustment not implemented yet")

    item = db_session.query(Item).first()

    # 1. Create Initial Entry (10kg)
    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=10,
        unit="kg",
        received_date=date.today(),
        price_per_unit=100.0,
        total_cost=1000.0,
    )
    stock_entry = create_stock_entry(db_session, entry_data, created_by=1)
    batch_id = stock_entry.batch_id

    # 2. Adjust: Add 5kg correction
    # Implies we found 5kg more
    new_balance = create_stock_adjustment(
        db_session,
        batch_id=batch_id,
        quantity_delta=Decimal("5.0"),
        unit="kg",
        reason="Found extra stock",
        user_id=1,
    )

    # 3. Assertions
    batch = db_session.query(Batch).get(batch_id)
    assert batch.quantity == Decimal("15.000")  # 10 + 5

    # Verify Ledger
    balance = calculate_ledger_balance(db_session, batch_id)
    assert balance == Decimal("15.000")
