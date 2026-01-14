import logging
from typing import List, Optional

from app.db.models.domain_event import DomainEvent
from app.db.models.inventory_txn import InventoryTxn
from app.db.schemas.domain_event import InventoryTxnCommitted
from app.db.schemas.inventory_txn import InventoryTxnCreate
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_inventory_txn(db: Session, data: InventoryTxnCreate) -> InventoryTxn:
    txn = InventoryTxn(**data.dict())
    db.add(txn)
    db.flush()
    db.refresh(txn)

    # EMIT DOMAIN EVENT (Outbox Pattern)
    event_payload = InventoryTxnCommitted(
        txn_id=txn.id,
        item_id=txn.item_id,
        batch_id=txn.batch_id,
        qty=txn.raw_qty,
        unit=txn.raw_unit,
        txn_type=txn.txn_type,
    ).dict()

    event = DomainEvent(
        event_type="inventory_txn.committed",
        aggregate_type="inventory_txn",
        aggregate_id=str(txn.id),
        payload=event_payload,
    )
    db.add(event)
    # Commit happens at caller level or via FastAPI dependency
    logger.info(f"InventoryTxn created: {txn}")
    return txn


def get_inventory_txns(
    db: Session,
    item_id: int,
    unit: Optional[str] = None,
    limit: int = 10,
) -> List[InventoryTxn]:
    """
    Fetch recent inventory transactions for an item (optionally filtered by unit).
    """
    q = db.query(InventoryTxn).filter(InventoryTxn.item_id == item_id)
    if unit:
        q = q.filter(InventoryTxn.raw_unit == unit)
    q = q.order_by(InventoryTxn.created_at.desc()).limit(limit)
    return q.all()
