from decimal import Decimal
import pytest
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.inventory_txn import create_inventory_txn
from app.db.models.inventory_txn import InventoryTxn
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    yield session
    session.close()


def test_inventory_txn_quantization(db_session):
    """
    Verify that creating an inventory txn correctly quantizes
    input values to 3 decimal places (NUM-001).
    """
    # Input with excessive precision
    raw_input = Decimal("10.123456")
    base_input = Decimal("10.987654")

    # Expected quantization (ROUND_HALF_UP)
    expected_raw = Decimal("10.123")  # .1234 -> .123
    expected_base = Decimal("10.988")  # .9876 -> .988

    data = InventoryTxnCreate(
        item_id=1,
        batch_id=1,
        txn_type="TEST",
        raw_qty=raw_input,
        raw_unit="kg",
        base_qty=base_input,
        base_unit="kg",
        remarks="Test quantization",
    )

    txn = create_inventory_txn(db_session, data)

    # Refresh from DB to verify storage
    db_session.refresh(txn)

    # Assertions
    # Note: SQLite stores as float/real, so we cast to Decimal for comparison match
    # In Postgres (Numeric), this is implicit.
    assert Decimal(str(txn.raw_qty)) == expected_raw
    assert Decimal(str(txn.base_qty)) == expected_base
