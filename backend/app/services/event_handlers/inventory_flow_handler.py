from decimal import Decimal

from app.db.models.inventory_flow_daily import InventoryFlowDaily
from app.db.schemas.domain_event import DomainEventBase
from sqlalchemy.orm import Session


def handle_inventory_flow(session: Session, event: DomainEventBase):
    """
    Update InventoryFlowDaily projection.
    """
    payload = event.payload
    txn_type = payload.get("txn_type")
    qty = Decimal(str(payload.get("qty", 0)))
    item_id = payload.get("item_id")

    # Use occurred_at date
    event_date = event.occurred_at.date()

    # Check for existing record
    record = (
        session.query(InventoryFlowDaily)
        .filter_by(date=event_date, item_id=item_id)
        .with_for_update()
        .first()
    )

    if not record:
        record = InventoryFlowDaily(
            date=event_date, item_id=item_id, in_qty=0, out_qty=0
        )
        session.add(record)

    if txn_type == "IN":
        record.in_qty += qty
    else:
        record.out_qty += qty

    record.net_qty = record.in_qty - record.out_qty
