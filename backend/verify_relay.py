import sys
import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from datetime import datetime, date

# Add path
sys.path.append(os.getcwd())

from app.db.models.base_class import Base
from app.db.models.domain_event import DomainEvent
from app.db.models.inventory_flow_daily import InventoryFlowDaily
from app.services.event_relay import process_pending_events
from app.services.event_handlers.inventory_flow_handler import handle_inventory_flow

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://user:password@db:5432/supply_chain"
)
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)


def test_manual():
    print("--- Starting Manual Test ---")

    # 1. Setup
    Base.metadata.create_all(bind=engine)
    session = SessionLocal()

    try:
        # cleanup
        session.query(DomainEvent).delete()
        session.query(InventoryFlowDaily).delete()
        session.commit()
        print("Cleanup done.")

        # 2. Insert IN Event
        payload_in = {
            "txn_id": 1,
            "item_id": 101,
            "batch_id": 1,
            "qty": 50.0,
            "txn_type": "IN",
            "unit": "kg",
        }
        event_in = DomainEvent(
            event_type="inventory_txn.committed",
            aggregate_type="test",
            aggregate_id="1",
            payload=payload_in,
            occurred_at=datetime.utcnow(),
            created_at=datetime.utcnow(),
        )
        session.add(event_in)
        session.commit()
        print("Inserted IN event.")

        # 3. Relay
        count = process_pending_events(session)
        print(f"Relay 1 count: {count}")

        # Verify
        flow = (
            session.query(InventoryFlowDaily)
            .filter_by(item_id=101, date=date.today())
            .first()
        )
        if not flow:
            print("ERROR: Flow record not found!")
        else:
            print(
                f"Flow State 1: IN={flow.in_qty}, OUT={flow.out_qty}, NET={flow.net_qty}"
            )

        # 4. Insert OUT Event
        payload_out = {
            "txn_id": 2,
            "item_id": 101,
            "batch_id": 1,
            "qty": 20.0,
            "txn_type": "OUT",
            "unit": "kg",
        }
        event_out = DomainEvent(
            event_type="inventory_txn.committed",
            aggregate_type="test",
            aggregate_id="1",
            payload=payload_out,
            occurred_at=datetime.utcnow(),
            created_at=datetime.utcnow(),
        )
        session.add(event_out)
        session.commit()
        print("Inserted OUT event.")

        # 5. Relay
        count2 = process_pending_events(session)
        print(f"Relay 2 count: {count2}")

        session.refresh(flow)
        print(f"Flow State 2: IN={flow.in_qty}, OUT={flow.out_qty}, NET={flow.net_qty}")

    except Exception as e:
        print(f"EXCEPTION: {e}")
        import traceback

        traceback.print_exc()
    finally:
        session.close()


if __name__ == "__main__":
    test_manual()
