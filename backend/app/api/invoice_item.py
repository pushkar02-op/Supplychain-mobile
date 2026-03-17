"""
API endpoints for invoice item management.
Provides retrieval, update, and deletion of invoice line items.
"""

import logging
from typing import List, Optional

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.mart_bill_item import MartBillItemRead as InvoiceItemRead
from app.db.schemas.mart_bill_item import MartBillItemSummary as InvoiceItemSummary
from app.db.schemas.mart_bill_item import MartBillItemUpdate as InvoiceItemUpdate
from app.db.session import get_db
from app.services.mart_bill_item import (
    delete_mart_bill_item,
    get_distinct_items_for_mart,
    get_items_by_mart_bill,
    update_mart_bill_item,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/invoice-items", tags=["Invoice Items"])


@router.get("/distinct-items", response_model=list[InvoiceItemSummary])
def distinct_items_for_mart(
    mart_name: str = Query(..., description="Mart name"),
    warehouse_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
):
    """
    Retrieve distinct invoice items for a given mart.
    Returns only item_id, item_code, item_name, uom.

    Args:
        mart_name (str): Mart name.
        db (Session): Database session dependency.

    Returns:
        List[InvoiceItemRead]: List of distinct invoice items.
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
    "/{invoice_id}", response_model=List[InvoiceItemRead], summary="List invoice items"
)
def read_items(
    invoice_id: int,
    warehouse_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> List[InvoiceItemRead]:
    """
    Retrieve all items for a given invoice.

    Args:
        invoice_id (int): Invoice ID.
        db (Session): Database session dependency.

    Returns:
        List[InvoiceItemRead]: List of items.
    """
    logger.info(f"Fetching items for invoice_id={invoice_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    results = get_items_by_mart_bill(db, invoice_id, warehouse_id=resolved_warehouse_id)
    return results[skip : skip + limit]


@router.put("/{item_id}", response_model=InvoiceItemRead, summary="Update invoice item")
def update_item(
    item_id: int,
    update_data: InvoiceItemUpdate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> InvoiceItemRead:
    """
    Update a specific invoice item.

    Args:
        item_id (int): Item ID.
        update_data (InvoiceItemUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        InvoiceItemRead: The updated item.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Updating invoice item id={item_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )
    updated = update_mart_bill_item(
        db, item_id, update_data, warehouse_id=resolved_warehouse_id
    )
    if not updated:
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return updated


@router.delete(
    "/{item_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete invoice item"
)
def delete_item(
    item_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> None:
    """
    Delete a specific invoice item.

    Args:
        item_id (int): Item ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Deleting invoice item id={item_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "delete"
    )
    if not delete_mart_bill_item(db, item_id, warehouse_id=resolved_warehouse_id):
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return None
