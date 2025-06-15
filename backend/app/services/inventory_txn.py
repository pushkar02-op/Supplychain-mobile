import logging
from sqlalchemy.orm import Session
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
