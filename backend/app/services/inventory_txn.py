import logging
from sqlalchemy.orm import Session
from typing import List, Optional

from app.db.models.inventory_txn import InventoryTxn
from app.db.schemas.inventory_txn import InventoryTxnCreate

logger = logging.getLogger(__name__)


def create_inventory_txn(db: Session, data: InventoryTxnCreate) -> InventoryTxn:
    txn = InventoryTxn(**data.dict())
    db.add(txn)
    db.commit()
    db.refresh(txn)
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
