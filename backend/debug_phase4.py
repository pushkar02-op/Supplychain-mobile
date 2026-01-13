import pytest
from datetime import date, datetime, timedelta
from decimal import Decimal
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.batch import Batch
from app.db.models.order import Order
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.uom import UOM
from app.db.schemas.dispatch_entry import DispatchEntryCreate, DispatchReversalCreate
from app.services.dispatch_entry import create_dispatch_entry, create_reversal_entry


def get_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    return SessionLocal()


def run_tests():
    session = get_session()
    try:
        # Setup Basics
        uom = UOM(code="kg", description="Kg")
        session.add(uom)
        session.flush()

        item = Item(
            name="Rice", default_uom_id=uom.id, item_code="RICE"
        )  # Correct field
        # Checking Item model... usually 'name' is unique or code.
        # Let's check Item creation.

        # In test_phase4_order_dispatch.py I used item_code="RICE".
        # Check Item model definition if needed.

        session.add(item)

        mart = Mart(name="Test Mart", company_name="Test Company")
        session.add(mart)
        session.flush()

        # Batch
        batch = Batch(
            item_id=item.id,
            unit="kg",
            quantity=Decimal("100.0"),
            received_at=date.today(),
        )
        session.add(batch)
        session.commit()

        # Test 1
        print("Running Test 1")
        order = Order(
            mart_id=mart.id,
            item_id=item.id,
            order_date=date.today(),
            quantity_ordered=50.0,
            quantity_dispatched=0.0,
            status="Pending",
            unit="kg",
        )
        session.add(order)
        session.commit()

        entry = DispatchEntryCreate(
            item_id=item.id,
            batch_id=batch.id,
            mart_name="Test Mart",
            dispatch_date=date.today(),
            quantity=10.0,
            unit="kg",
            order_id=None,
        )

        dispatch = create_dispatch_entry(session, entry, created_by="test")
        print(f"Dispatch Created: {dispatch.id}, Order ID: {dispatch.order_id}")

    except Exception as e:
        import traceback

        with open("error_log.txt", "w") as f:
            f.write(str(e))
            f.write("\n")
            traceback.print_exc(file=f)
        print("Logged error to error_log.txt")


if __name__ == "__main__":
    run_tests()
