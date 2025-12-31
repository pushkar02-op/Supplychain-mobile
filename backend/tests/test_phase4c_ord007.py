"""
Phase 4C: ORD-007 Over-Dispatch Prevention Tests
"""

from datetime import date
from decimal import Decimal
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.services.dispatch_entry import create_dispatch_entry
from app.core.exceptions import AppException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base


def get_session():
    """In-memory SQLite for isolation."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    return Session()


def setup_basic_data(db):
    """Create base UOM, Item, Mart, Batch, Order for tests."""
    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item = Item(name="TestItem", default_uom_id=uom.id)
    db.add(item)
    db.flush()

    mart = Mart(name="TestMart", company_name="Test Co")
    db.add(mart)
    db.flush()

    # Create batch with stock
    batch = Batch(
        item_id=item.id,
        quantity=Decimal("100.0"),
        unit="kg",
        received_at=date.today(),
    )
    db.add(batch)
    db.flush()

    # Create order for 50 units
    order = Order(
        item_id=item.id,
        mart_id=mart.id,
        order_date=date.today(),
        quantity_ordered=50.0,
        quantity_dispatched=0.0,
        status="Pending",
        unit="kg",
    )
    db.add(order)
    db.commit()

    return item, mart, batch, order


def test_ord007_dispatch_within_limit():
    """Dispatch within remaining quantity should PASS."""
    db = get_session()
    item, mart, batch, order = setup_basic_data(db)

    payload = DispatchEntryCreate(
        batch_id=batch.id,
        item_id=item.id,
        mart_name="TestMart",
        dispatch_date=date.today(),
        quantity=30.0,  # Within 50 limit
        unit="kg",
    )

    try:
        result = create_dispatch_entry(db, payload, created_by="test")
        assert result is not None
        # Verify order updated
        db.refresh(order)
        assert order.quantity_dispatched == 30.0
        print("PASS: ORD-007 Dispatch Within Limit")
    except AppException as e:
        raise AssertionError(f"Unexpected exception: {e.message}")


def test_ord007_block_over_dispatch():
    """Dispatch exceeding remaining quantity should FAIL with 409."""
    db = get_session()
    item, mart, batch, order = setup_basic_data(db)

    payload = DispatchEntryCreate(
        batch_id=batch.id,
        item_id=item.id,
        mart_name="TestMart",
        dispatch_date=date.today(),
        quantity=60.0,  # Exceeds 50 limit
        unit="kg",
    )

    try:
        create_dispatch_entry(db, payload, created_by="test")
        raise AssertionError("Expected AppException not raised!")
    except AppException as e:
        assert e.status_code == 409, f"Expected 409, got {e.status_code}"
        assert e.extra.get("rule_id") == "ORD-007"
        assert e.extra.get("remaining_quantity") == 50.0
        assert e.extra.get("requested_quantity") == 60.0
        # Verify NO inventory mutation
        db.refresh(batch)
        assert batch.quantity == Decimal("100.0"), "Inventory should NOT be mutated"
        print("PASS: ORD-007 Block Over-Dispatch (409)")


def test_ord007_partial_dispatches_sum():
    """Multiple partial dispatches should sum correctly and block on over-dispatch."""
    db = get_session()
    item, mart, batch, order = setup_basic_data(db)

    # First dispatch: 30 of 50
    payload1 = DispatchEntryCreate(
        batch_id=batch.id,
        item_id=item.id,
        mart_name="TestMart",
        dispatch_date=date(2025, 1, 1),
        quantity=30.0,
        unit="kg",
    )
    create_dispatch_entry(db, payload1, created_by="test")
    db.refresh(order)
    assert order.quantity_dispatched == 30.0

    # Second dispatch: 25 of remaining 20 → should FAIL
    payload2 = DispatchEntryCreate(
        batch_id=batch.id,
        item_id=item.id,
        mart_name="TestMart",
        dispatch_date=date(2025, 1, 2),
        quantity=25.0,  # Only 20 remaining
        unit="kg",
    )

    try:
        create_dispatch_entry(db, payload2, created_by="test")
        raise AssertionError("Expected AppException not raised!")
    except AppException as e:
        assert e.status_code == 409
        assert e.extra.get("rule_id") == "ORD-007"
        assert e.extra.get("remaining_quantity") == 20.0
        print("PASS: ORD-007 Partial Dispatches Sum Correctly")


def test_ord007_block_dispatch_cancelled_order():
    """Dispatch against Cancelled order should FAIL."""
    db = get_session()
    item, mart, batch, order = setup_basic_data(db)

    # Cancel the order
    order.status = "Cancelled"
    db.commit()

    payload = DispatchEntryCreate(
        batch_id=batch.id,
        item_id=item.id,
        mart_name="TestMart",
        dispatch_date=date.today(),
        quantity=10.0,
        unit="kg",
    )

    try:
        create_dispatch_entry(db, payload, created_by="test")
        raise AssertionError("Expected AppException not raised!")
    except AppException as e:
        assert e.status_code == 409
        assert e.extra.get("rule_id") == "ORD-007"
        assert (
            "Cancelled" in str(e.extra.get("order_status", ""))
            or "Cancelled" in e.message
        )
        print("PASS: ORD-007 Block Dispatch Against Cancelled Order")


def test_ord007_block_dispatch_completed_order():
    """Dispatch against Completed order should FAIL."""
    db = get_session()
    item, mart, batch, order = setup_basic_data(db)

    # Complete the order
    order.status = "Completed"
    order.quantity_dispatched = 50.0
    db.commit()

    payload = DispatchEntryCreate(
        batch_id=batch.id,
        item_id=item.id,
        mart_name="TestMart",
        dispatch_date=date.today(),
        quantity=5.0,
        unit="kg",
    )

    try:
        create_dispatch_entry(db, payload, created_by="test")
        raise AssertionError("Expected AppException not raised!")
    except AppException as e:
        assert e.status_code == 409
        assert e.extra.get("rule_id") == "ORD-007"
        print("PASS: ORD-007 Block Dispatch Against Completed Order")


def test_ord007_no_inventory_mutation_on_failure():
    """On ORD-007 failure, batch quantity MUST remain unchanged."""
    db = get_session()
    item, mart, batch, order = setup_basic_data(db)

    original_qty = batch.quantity

    payload = DispatchEntryCreate(
        batch_id=batch.id,
        item_id=item.id,
        mart_name="TestMart",
        dispatch_date=date.today(),
        quantity=100.0,  # Way over
        unit="kg",
    )

    try:
        create_dispatch_entry(db, payload, created_by="test")
    except AppException:
        pass

    db.refresh(batch)
    assert batch.quantity == original_qty, "Inventory mutated despite failure!"
    print("PASS: ORD-007 No Inventory Mutation on Failure")


if __name__ == "__main__":
    try:
        test_ord007_dispatch_within_limit()
        test_ord007_block_over_dispatch()
        test_ord007_partial_dispatches_sum()
        test_ord007_block_dispatch_cancelled_order()
        test_ord007_block_dispatch_completed_order()
        test_ord007_no_inventory_mutation_on_failure()
        print("\n=== ALL PHASE 4C ORD-007 TESTS PASSED ===")
    except Exception as e:
        import traceback

        traceback.print_exc()
