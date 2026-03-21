"""
API endpoints for Mart Bill Item management.
This is the preferred endpoint for bill item management.
Aliases logic from legacy /invoice-items.
"""

import logging
from typing import List, Optional

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.mart_bill_item import (
    MartBillItemRead,
    MartBillItemSummary,
    MartBillItemUpdate,
)
from app.db.session import get_db
from app.services.mart_bill_item import (
    delete_mart_bill_item,
    get_bill_item_suggestions,
    get_distinct_items_for_mart,
    get_items_by_mart_bill,
    update_mart_bill_item,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/mart-bill-items", tags=["Mart Bill Items"])


@router.get("/distinct-items", response_model=list[MartBillItemSummary])
def distinct_items_for_mart(
    mart_name: str = Query(..., description="Mart name"),
    warehouse_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
):
    """
    Retrieve distinct items for a given mart.
    Returns only item_id, item_code, item_name, uom.

    Args:
        mart_name (str): Mart name.
        db (Session): Database session dependency.

    Returns:
        List[MartBillItemRead]: List of distinct mart bill items.
    """
    logger.info(f"API: Fetching distinct items for mart: {mart_name}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    results = get_distinct_items_for_mart(
        db, mart_name, warehouse_id=resolved_warehouse_id
    )
    return results[skip : skip + limit]


@router.get(
    "/{bill_id}/suggestions",
    summary="Get mapping suggestions for unresolved items",
)
def bill_item_suggestions(
    bill_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> list[dict]:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_bill_item_suggestions(db, bill_id, warehouse_id=resolved_warehouse_id)


@router.get(
    "/{bill_id}", response_model=List[MartBillItemRead], summary="List mart bill items"
)
def read_items(
    bill_id: int,
    warehouse_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> List[MartBillItemRead]:
    """
    Retrieve all items for a given mart bill.

    Args:
        bill_id (int): Bill ID.
        db (Session): Database session dependency.

    Returns:
        List[MartBillItemRead]: List of items.
    """
    logger.info(f"Fetching items for bill_id={bill_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    results = get_items_by_mart_bill(db, bill_id, warehouse_id=resolved_warehouse_id)
    return results[skip : skip + limit]


@router.put(
    "/{item_id}", response_model=MartBillItemRead, summary="Update mart bill item"
)
def update_item(
    item_id: int,
    update_data: MartBillItemUpdate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> MartBillItemRead:
    """
    Update a specific mart bill item.

    Args:
        item_id (int): Item ID.
        update_data (MartBillItemUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        MartBillItemRead: The updated item.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Updating mart bill item id={item_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )
    updated = update_mart_bill_item(
        db, item_id, update_data, warehouse_id=resolved_warehouse_id
    )
    if not updated:
        logger.error(f"Mart bill item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return updated


@router.delete(
    "/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete mart bill item",
)
def delete_item(
    item_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> None:
    """
    Delete a specific mart bill item.

    Args:
        item_id (int): Item ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Deleting mart bill item id={item_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "delete"
    )
    if not delete_mart_bill_item(db, item_id, warehouse_id=resolved_warehouse_id):
        logger.error(f"Mart bill item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return None
