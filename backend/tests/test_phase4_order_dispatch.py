"""
Phase 4: Order <-> Dispatch Intent Integrity Tests.
Contract:
1. New dispatches MUST persist order_id if order exists.
2. Reversal MUST优先 use explicit order_id if present.
3. Legacy behavior (no order_id) MUST fallback to heuristic.
"""

from datetime import date, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.models.uom import UOM
from app.db.schemas.dispatch_entry import DispatchEntryCreate, DispatchReversalCreate
from app.services.dispatch_entry import create_dispatch_entry, create_reversal_entry


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # Setup Basics
    uom = UOM(code="kg", description="Kg")
    session.add(uom)
    session.flush()

    item = Item(name="Rice", default_uom_id=uom.id, item_code="RICE")
    session.add(item)

    mart = Mart(name="Test Mart", company_name="Test Company")
    session.add(mart)
    session.flush()

    # Batch (Stock)
    batch = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("100.0"),
        received_at=date.today(),
    )
    session.add(batch)
    session.commit()  # batch.id=1

    yield session
    session.close()


def test_implicit_dispatch_sets_order_id(db_session):
    """
    Test that even if we don't pass order_id (legacy style),
    the system infers it and PERSISTS it (Forward Fix).
    """
    # 1. Create Order
    mart_id = db_session.query(Mart).first().id
    item_id = db_session.query(Item).first().id

    order = Order(
        mart_id=mart_id,
        item_id=item_id,
        order_date=date.today(),
        quantity_ordered=50.0,
        quantity_dispatched=0.0,
        status="Pending",
        unit="kg",
    )
    db_session.add(order)
    db_session.commit()

    # 2. Dispatch Implicitly (No order_id in input)
    entry = DispatchEntryCreate(
        item_id=item_id,
        batch_id=1,
        mart_name="Test Mart",
        dispatch_date=date.today(),
        quantity=10.0,
        unit="kg",
        order_id=None,  # Implicit
    )

    dispatch = create_dispatch_entry(db_session, entry, created_by="test")

    # 3. Verify
    assert dispatch.order_id == order.id
    assert dispatch.order_id is not None
    print("PASS: Implicit dispatch auto-linked to order")


def test_explicit_dispatch_respects_order_id(db_session):
    """
    Test that passing explicit order_id links to that specific order.
    """
    mart_id = db_session.query(Mart).first().id
    item_id = db_session.query(Item).first().id

    order = Order(
        mart_id=mart_id,
        item_id=item_id,
        order_date=date.today(),
        quantity_ordered=50.0,
        quantity_dispatched=0.0,
        status="Pending",
        unit="kg",
    )
    db_session.add(order)
    db_session.commit()

    entry = DispatchEntryCreate(
        item_id=item_id,
        batch_id=1,
        mart_name="Test Mart",
        dispatch_date=date.today(),
        quantity=10.0,
        unit="kg",
        order_id=order.id,  # Explicit
    )

    dispatch = create_dispatch_entry(db_session, entry, created_by="test")
    assert dispatch.order_id == order.id
    print("PASS: Explicit dispatch linked to order")


def test_reversal_prefer_explicit_link(db_session):
    """
    Test that reversal uses the stored order_id, ignoring heuristic date logic.
    Scenario:
    - Order A (Old): Dispatched 10. Status=Partially.
    - Order B (New): Dispatched 10. Status=Partially.
    - Dispatch D is linked to Order A.
    - Reversal of D should credit A, NOT B (even if B is newer/active).
    """
    mart_id = db_session.query(Mart).first().id
    item_id = db_session.query(Item).first().id

    # Order A
    order_a = Order(
        mart_id=mart_id,
        item_id=item_id,
        order_date=date.today() - timedelta(days=5),
        quantity_ordered=50.0,
        quantity_dispatched=10.0,
        status="Partially Completed",
        unit="kg",
    )
    db_session.add(order_a)

    # Order B
    order_b = Order(
        mart_id=mart_id,
        item_id=item_id,
        order_date=date.today(),
        quantity_ordered=50.0,
        quantity_dispatched=10.0,
        status="Partially Completed",
        unit="kg",
    )
    db_session.add(order_b)
    db_session.commit()

    # Dispatch linked to A explicitly
    dispatch = DispatchEntry(
        item_id=item_id,
        batch_id=1,
        mart_id=mart_id,
        dispatch_date=date.today(),
        quantity=10.0,
        unit="kg",
        order_id=order_a.id,  # Explicit link to A
    )
    db_session.add(dispatch)
    db_session.commit()

    # Reverse
    rev_entry = DispatchReversalCreate(quantity=5.0, reason="Return")
    create_reversal_entry(db_session, dispatch.id, rev_entry, created_by="test")

    db_session.refresh(order_a)
    db_session.refresh(order_b)

    # Order A should reduce dispatched (10 - 5 = 5)
    # Order B should remain 10
    assert order_a.quantity_dispatched == 5.0
    assert order_b.quantity_dispatched == 10.0
    print("PASS: Reversal respected explicit intent (Order A)")


if __name__ == "__main__":
    try:
        # Run manually to verify before pytest
        # Setup helpers not needed for pytest run via main if using pytest framework,
        # but useful for rapid debug.
        pass
    except Exception as e:
        print(e)
