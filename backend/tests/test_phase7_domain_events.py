import pytest
from datetime import datetime, date
from decimal import Decimal
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.domain_event import DomainEvent
from app.db.models.item import Item
from app.db.models.batch import Batch
from app.db.models.uom import UOM
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.inventory_txn import create_inventory_txn
from app.services.dispatch_entry import create_dispatch_entry
from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.services.reconciliation import create_drift_record, resolve_drift
from app.db.schemas.order import OrderCreate
from app.services.order import create_order
from app.db.models.inventory_txn import InventoryTxn

# Use the real DB from the environment (or fallback to test config)
# Ideally, we reuse the conftest.py fixtures, but for standalone clarity:


@pytest.fixture(scope="module")
def db_session():
    # Assuming running in Docker with env vars set, or valid local URL
    import os

    DATABASE_URL = os.getenv(
        "DATABASE_URL", "postgresql://user:password@db:5432/supply_chain"
    )
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def setup_base_data(db):
    # Ensure UOM
    uom = db.query(UOM).filter_by(code="kg").first()
    if not uom:
        uom = UOM(code="kg", description="Killogram")
        db.add(uom)
        db.commit()

    # Ensure Item
    item = db.query(Item).filter_by(name="Event Test Item").first()
    if not item:
        item = Item(name="Event Test Item", default_uom_id=uom.id)
        db.add(item)
        db.commit()

    # Ensure Mart
    mart = db.query(Mart).filter_by(name="Event Test Mart").first()
    if not mart:
        mart = Mart(name="Event Test Mart")
        db.add(mart)
        db.commit()

    return item, mart


def test_inventory_txn_emits_event(db_session):
    item, _ = setup_base_data(db_session)

    # Create Batch
    batch = Batch(item_id=item.id, unit="kg", quantity=100.0, received_at=date.today())
    db_session.add(batch)
    db_session.commit()

    # 1. Create Txn
    txn_data = InventoryTxnCreate(
        item_id=item.id,
        batch_id=batch.id,
        txn_type="IN",
        raw_qty=50.0,
        raw_unit="kg",
        base_qty=50.0,
        base_unit="kg",
        ref_type="manual",
        ref_id=999,
        remarks="Event Test",
    )
    txn = create_inventory_txn(db_session, txn_data)
    db_session.commit()

    # 2. Assert Event
    event = db_session.execute(
        select(DomainEvent).where(
            DomainEvent.event_type == "inventory_txn.committed",
            DomainEvent.aggregate_id == str(txn.id),
        )
    ).scalar_one_or_none()

    assert event is not None
    assert event.aggregate_type == "inventory_txn"
    assert event.payload["qty"] == 50.0
    assert event.payload["txn_type"] == "IN"


def test_dispatch_emits_event(db_session):
    item, mart = setup_base_data(db_session)

    # Create Batch with enough stock
    batch = Batch(item_id=item.id, unit="kg", quantity=200.0, received_at=date.today())
    db_session.add(batch)
    db_session.commit()

    # 1. Create Dispatch
    entry = DispatchEntryCreate(
        item_id=item.id,
        batch_id=batch.id,
        mart_name=mart.name,
        quantity=20.0,
        unit="kg",
        dispatch_date=date.today(),
        remarks="Event Dispatch",
    )
    dispatch = create_dispatch_entry(db_session, entry, created_by="tester")
    # Commit handled in service, but let's be safe

    # 2. Assert Dispatch Event
    event = db_session.execute(
        select(DomainEvent).where(
            DomainEvent.event_type == "dispatch.completed",
            DomainEvent.aggregate_id == str(dispatch.id),
        )
    ).scalar_one_or_none()

    assert event is not None
    assert event.payload["qty"] == 20.0
    assert event.payload["item_id"] == item.id


def test_order_fulfillment_event(db_session):
    item, mart = setup_base_data(db_session)

    # 1. Create Order (Qty 10)
    order_data = OrderCreate(
        item_id=item.id,
        mart_name=mart.name,
        order_date=date.today(),
        quantity_ordered=10.0,
        unit="kg",
    )
    # Ensure no duplicate
    existing = (
        db_session.query(Order)
        .filter_by(item_id=item.id, order_date=date.today(), mart_id=mart.id)
        .first()
    )
    if existing:
        db_session.delete(existing)
        db_session.commit()

    order = create_order(db_session, order_data)
    db_session.commit()

    # 2. Fulfill Order via Dispatch (Qty 10)
    batch = Batch(item_id=item.id, unit="kg", quantity=100.0, received_at=date.today())
    db_session.add(batch)
    db_session.commit()

    dispatch_entry = DispatchEntryCreate(
        item_id=item.id,
        batch_id=batch.id,
        mart_name=mart.name,
        quantity=10.0,
        unit="kg",
        dispatch_date=date.today(),
        order_id=order.id,  # Explicit link
        remarks="Fulfillment Dispatch",
    )
    create_dispatch_entry(db_session, dispatch_entry, created_by="tester")

    # 3. Assert OrderFulfilled Event
    event = db_session.execute(
        select(DomainEvent).where(
            DomainEvent.event_type == "order.fulfilled",
            DomainEvent.aggregate_id == str(order.id),
        )
    ).scalar_one_or_none()

    assert event is not None
    assert event.payload["total_qty"] == 10.0


def test_reconciliation_resolved_event(db_session):
    item, _ = setup_base_data(db_session)

    # 1. Create Batch
    batch = Batch(item_id=item.id, unit="kg", quantity=100.0, received_at=date.today())
    db_session.add(batch)
    db_session.commit()

    # 2. Create Ledger Record (Manual injection to simulate drift)
    # We use create_inventory_txn to create a mismatch
    # Batch says 100. Ledger says 0 (no txns).
    # Reconciliation logic: Drift = 100 - 0 = 100 Drifted.

    # Create drift record
    record = create_drift_record(db_session, batch.id)
    assert record is not None
    assert record.status == "OPEN"

    # 3. Resolve Drift
    result = resolve_drift(
        db_session,
        record.id,
        adjustment_qty=Decimal("100.0"),
        user_id=1,
        apply_to_batch=False,
    )
    assert result["status"] == "success"

    # 4. Assert Event
    event = db_session.execute(
        select(DomainEvent).where(
            DomainEvent.event_type == "reconciliation.resolved",
            DomainEvent.aggregate_id == str(record.id),
        )
    ).scalar_one_or_none()

    assert event is not None
    assert event.payload["drift_resolved"] == 100.0
