import logging
from typing import List, Optional

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.inventory_txn import InventoryTxnRead
from app.db.session import get_db
from app.services.inventory_txn import get_inventory_txns
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/inventory-txn", tags=["Inventory Txn"])


@router.get(
    "/", response_model=List[InventoryTxnRead], summary="List inventory transactions"
)
def list_inventory_txns(
    item_id: int = Query(..., description="Filter by item ID"),
    warehouse_id: Optional[int] = Query(None, description="Warehouse scope"),
    unit: Optional[str] = Query(None, description="Filter by unit"),
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=200, description="Number of transactions"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> List[InventoryTxnRead]:
    """
    List recent inventory transactions for an item (optionally filtered by unit).
    """
    logger.info(
        f"Fetching last {limit} inventory transactions for item_id={item_id}, unit={unit}"
    )
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    txns = get_inventory_txns(
        db=db,
        item_id=item_id,
        warehouse_id=resolved_warehouse_id,
        unit=unit,
        skip=skip,
        limit=limit,
    )
    logger.debug(f"Found {len(txns)} transactions for item_id={item_id}")
    return [InventoryTxnRead.from_orm(txn) for txn in txns]
