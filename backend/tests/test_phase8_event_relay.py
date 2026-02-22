import pytest
from datetime import datetime, date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.domain_event import DomainEvent
from app.db.models.inventory_flow_daily import InventoryFlowDaily
from app.db.models.inventory_drift_history import InventoryDriftHistory
from app.db.models.order_fulfillment_metrics import OrderFulfillmentMetrics
from app.db.models.order import Order
from app.services.event_relay import process_pending_events


@pytest.fixture(scope="function")
def db_session():
    import os

    DATABASE_URL = os.getenv(
        "DATABASE_URL", "postgresql://user:password@db:5432/supply_chain"
    )
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    session = Session()

    Base.metadata.create_all(bind=engine)

    # Cleanup
    from sqlalchemy import text

    try:
        # 1. Projections (Safe to delete)
        session.query(InventoryFlowDaily).delete()
        session.query(InventoryDriftHistory).delete()
        session.query(OrderFulfillmentMetrics).delete()

        # 2. Domain Events
        session.query(DomainEvent).delete()

        # 3. Dependent Data (Raw SQL for speed/safety)
        session.execute(text("DELETE FROM inventory_txn"))
        session.execute(text("DELETE FROM batch WHERE item_id IN (303, 304)"))
        # Handing Order dependencies if any exist from previous runs
        session.execute(
            text("DELETE FROM uom WHERE code IN ('kg', 'kg_test_p8')")
        )  # Fails if items exist
        session.execute(text("DELETE FROM item WHERE id IN (303, 304)"))
        # Order cleanup including dependencies (if cascade not set) -- simplistic approach:
        session.query(Order).filter(Order.id > 10000).delete()
        session.execute(text("DELETE FROM mart WHERE id IN (5, 6)"))

        session.commit()
    except Exception as e:
        session.rollback()
        print(f"Cleanup warning: {e}")

    yield session
    session.close()


def create_raw_event(session, event_type, payload):
    event = DomainEvent(
        event_type=event_type,
        aggregate_type="test",
        aggregate_id="1",
        payload=payload,
        occurred_at=datetime.utcnow(),
    )
    session.add(event)
    session.commit()
    return event


def test_inventory_flow_projection(db_session):
    # Clean slate: Remove any unprocessed events from other tests
    db_session.query(DomainEvent).filter(DomainEvent.processed_at.is_(None)).delete()
    db_session.query(InventoryFlowDaily).delete()
    db_session.commit()

    # 1. Insert Event
    first_event = create_raw_event(
        db_session,
        "inventory_txn.committed",
        {
            "txn_id": 1,
            "item_id": 101,
            "batch_id": 1,
            "qty": 50.0,
            "txn_type": "IN",
            "unit": "kg",
        },
    )

    # 2. Run Relay
    count = process_pending_events(db_session)
    assert count == 1

    # 3. Assert Projection
    flow = (
        db_session.query(InventoryFlowDaily)
        .filter_by(item_id=101, date=first_event.occurred_at.date())
        .first()
    )
    assert flow is not None
    assert flow.in_qty == 50.0
    assert flow.net_qty == 50.0

    # 4. Add OUT event
    create_raw_event(
        db_session,
        "inventory_txn.committed",
        {
            "txn_id": 2,
            "item_id": 101,
            "batch_id": 1,
            "qty": 20.0,
            "txn_type": "OUT",
            "unit": "kg",
        },
    )

    # 5. Run Relay Again
    count = process_pending_events(db_session)
    assert count == 1
    db_session.refresh(flow)
    assert flow.out_qty == 20.0
    assert flow.net_qty == 30.0


def test_drift_history_projection(db_session):
    # 1. Insert High Drift Event
    create_raw_event(
        db_session,
        "reconciliation.resolved",
        {
            "record_id": 1,
            "batch_id": 202,
            "drift_resolved": -60.0,
            "adjustment_txn_id": 10,
        },
    )

    # 2. Run Relay
    process_pending_events(db_session)

    # 3. Assert
    history = db_session.query(InventoryDriftHistory).filter_by(batch_id=202).first()
    assert history is not None
    assert float(history.drift) == -60.0
    assert history.severity == "HIGH"  # > 50


def test_order_metrics_projection(db_session):
    # Setup dependencies with unique IDs to avoid collision
    from app.db.models.item import Item
    from app.db.models.mart import Mart
    from app.db.models.uom import UOM

    # Unique IDs
    uom_code = "kg_test_p8"
    item_id = 304
    mart_id = 6
    order_id = 10002

    uom = db_session.query(UOM).filter_by(code=uom_code).first()
    if not uom:
        uom = UOM(code=uom_code, description="Kg Test")
        db_session.add(uom)
        db_session.commit()
    else:
        db_session.commit()  # ensure clean txn

    item = db_session.get(Item, item_id)
    if not item:
        item = Item(id=item_id, name="Metric Test Item P8", default_uom_id=uom.id)
        db_session.add(item)

    mart = db_session.get(Mart, mart_id)
    if not mart:
        mart = Mart(id=mart_id, name="Metric Test Mart P8", company_name="Test Co P8")
        db_session.add(mart)
    db_session.commit()

    # 1. Setup Order (created 60 mins ago)
    created_at = datetime.utcnow() - timedelta(minutes=60)

    order = Order(
        id=order_id,
        item_id=item_id,
        mart_id=mart_id,
        status="Completed",
        order_date=date.today(),
        quantity_ordered=10,
        quantity_dispatched=10,
        unit=uom_code,
    )
    db_session.add(order)
    db_session.flush()
    # Force created_at
    order.created_at = created_at
    db_session.commit()

    # 2. Insert Event (occurred_at = Now)
    create_raw_event(
        db_session,
        "order.fulfilled",
        {
            "order_id": order_id,
            "item_id": item_id,
            "mart_id": mart_id,
            "total_qty": 10.0,
        },
    )

    # 3. Run Relay
    process_pending_events(db_session)

    # 4. Assert
    metric = (
        db_session.query(OrderFulfillmentMetrics).filter_by(order_id=order_id).first()
    )
    assert metric is not None
    assert 55.0 <= metric.fulfillment_time_minutes <= 65.0

    # Cleanup
    db_session.delete(order)
    db_session.delete(metric) if metric else None
    db_session.commit()


def test_idempotency_and_unknown_event(db_session):
    # 1. Insert Unknown Event
    create_raw_event(db_session, "unknown.event", {"foo": "bar"})

    # 2. Run Relay
    count = process_pending_events(db_session)
    assert count == 1  # Should mark processed even if skipped

    # 3. Check processed (last event)
    # The last Query will be processed
    # 4. Run Relay Again (Idempotency)
    count = process_pending_events(db_session)
    assert count == 0
