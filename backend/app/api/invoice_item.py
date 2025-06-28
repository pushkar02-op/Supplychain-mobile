"""
API endpoints for invoice item management.
Provides retrieval, update, and deletion of invoice line items.
"""

import logging
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List

from app.core.exceptions import AppException
from app.db.schemas.invoice_item import InvoiceItemRead, InvoiceItemUpdate, InvoiceItemSummary
from app.services.invoice_item import (
    get_items_by_invoice,
    update_invoice_item,
    delete_invoice_item,
    get_distinct_items_for_mart,
)
from app.db.session import get_db
from app.db.models.invoice_item import InvoiceItem

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/invoice-items", tags=["Invoice Items"])


@router.get("/distinct-items", response_model=list[InvoiceItemSummary])
def distinct_items_for_mart(
    mart_name: str = Query(..., description="Mart name"),
    db: Session = Depends(get_db),
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
    return get_distinct_items_for_mart(db, mart_name)


@router.get(
    "/{invoice_id}", response_model=List[InvoiceItemRead], summary="List invoice items"
)
def read_items(invoice_id: int, db: Session = Depends(get_db)) -> List[InvoiceItemRead]:
    """
    Retrieve all items for a given invoice.

    Args:
        invoice_id (int): Invoice ID.
        db (Session): Database session dependency.

    Returns:
        List[InvoiceItemRead]: List of items.
    """
    logger.info(f"Fetching items for invoice_id={invoice_id}")
    return get_items_by_invoice(db, invoice_id)


@router.put("/{item_id}", response_model=InvoiceItemRead, summary="Update invoice item")
def update_item(
    item_id: int, update_data: InvoiceItemUpdate, db: Session = Depends(get_db)
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
    updated = update_invoice_item(db, item_id, update_data)
    if not updated:
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return updated


@router.delete(
    "/{item_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete invoice item"
)
def delete_item(item_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete a specific invoice item.

    Args:
        item_id (int): Item ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Deleting invoice item id={item_id}")
    if not delete_invoice_item(db, item_id):
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return None
