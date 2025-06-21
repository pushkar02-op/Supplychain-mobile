from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Optional
import logging

from app.db.schemas.inventory_txn import InventoryTxnRead
from app.db.session import get_db
from app.services.inventory_txn import get_inventory_txns

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/inventory-txn", tags=["Inventory Txn"])


@router.get(
    "/", response_model=List[InventoryTxnRead], summary="List inventory transactions"
)
def list_inventory_txns(
    item_id: int = Query(..., description="Filter by item ID"),
    unit: Optional[str] = Query(None, description="Filter by unit"),
    limit: int = Query(10, ge=1, le=100, description="Number of transactions"),
    db: Session = Depends(get_db),
) -> List[InventoryTxnRead]:
    """
    List recent inventory transactions for an item (optionally filtered by unit).
    """
    logger.info(
        f"Fetching last {limit} inventory transactions for item_id={item_id}, unit={unit}"
    )
    txns = get_inventory_txns(db=db, item_id=item_id, unit=unit, limit=limit)
    logger.debug(f"Found {len(txns)} transactions for item_id={item_id}")
    return [InventoryTxnRead.from_orm(txn) for txn in txns]
