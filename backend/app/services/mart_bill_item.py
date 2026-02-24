"""
Service functions for invoice item management.
Handles recalculation of totals and CRUD operations on invoice line items.
"""

import logging
from datetime import datetime
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.models.mart_bill import MartBill
from app.db.models.mart_bill_item import MartBillItem
from app.db.schemas.mart_bill_item import MartBillItemUpdate
from app.services.warehouse_scope import resolve_system_warehouse_id
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def recalculate_mart_bill_total(
    db: Session, invoice_id: int, warehouse_id: Optional[int] = None
) -> None:
    """
    Recalculate and update the total_amount of an invoice after item changes.

    Args:
        db (Session): Database session.
        invoice_id (int): ID of the invoice to recalculate.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.info(f"Recalculating total for invoice_id={invoice_id}")
    q = db.query(MartBill).filter(
        MartBill.id == invoice_id, MartBill.warehouse_id == resolved_warehouse_id
    )
    invoice = q.first()
    if not invoice:
        logger.error(f"Invoice not found: id={invoice_id}")
        raise AppException("Invoice not found", status_code=404)

    # We use .items because relationship is named 'items' in MartBill
    invoice.total_amount = sum(item.total for item in invoice.items)
    invoice.updated_at = datetime.utcnow()
    db.add(invoice)
    db.flush()
    logger.debug(f"Updated invoice total to {invoice.total_amount}")


def get_items_by_mart_bill(
    db: Session, invoice_id: int, warehouse_id: Optional[int] = None
) -> List[MartBillItem]:
    """
    Retrieve all line items for a given invoice.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        List[MartBillItem]: List of items.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.debug(f"Fetching items for invoice_id={invoice_id}")
    q = db.query(MartBillItem).filter(
        MartBillItem.invoice_id == invoice_id,
        MartBillItem.warehouse_id == resolved_warehouse_id,
    )
    return q.all()


def update_mart_bill_item(
    db: Session,
    item_id: int,
    update_data: MartBillItemUpdate,
    warehouse_id: Optional[int] = None,
) -> Optional[MartBillItem]:
    """
    Update a specific invoice item and recalculate invoice total.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.
        update_data (MartBillItemUpdate): Fields to update.

    Returns:
        Optional[MartBillItem]: Updated item, or None if not found.

    Raises:
        AppException: If item not found.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.info(f"Updating invoice item id={item_id}")
    q = db.query(MartBillItem).filter(
        MartBillItem.id == item_id, MartBillItem.warehouse_id == resolved_warehouse_id
    )
    item = q.first()
    if not item:
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)

    for field, value in update_data.dict(exclude_unset=True).items():
        setattr(item, field, value)
    db.flush()
    db.refresh(item)
    logger.debug(f"Item id={item_id} updated, recalculating invoice total")
    recalculate_mart_bill_total(db, item.invoice_id, warehouse_id=resolved_warehouse_id)
    db.commit()
    return item


def delete_mart_bill_item(
    db: Session, item_id: int, warehouse_id: Optional[int] = None
) -> bool:
    """
    Delete an invoice item and recalculate invoice total.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.

    Returns:
        bool: True if deleted, False otherwise.

    Raises:
        AppException: If item not found.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.info(f"Deleting invoice item id={item_id}")
    q = db.query(MartBillItem).filter(
        MartBillItem.id == item_id, MartBillItem.warehouse_id == resolved_warehouse_id
    )
    item = q.first()
    if not item:
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)

    invoice_id = item.invoice_id
    db.delete(item)
    db.flush()
    logger.debug(f"Item id={item_id} deleted, recalculating invoice total")
    recalculate_mart_bill_total(db, invoice_id, warehouse_id=resolved_warehouse_id)
    db.commit()
    return True


def get_distinct_items_for_mart(
    db: Session, mart_name: str, warehouse_id: Optional[int] = None
) -> list[dict]:
    """
    Retrieve distinct items for a given mart from invoice items.
    Returns only item_id, item_code, item_name, uom.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.debug(f"Fetching distinct items for mart: {mart_name}")
    query = db.query(
        MartBillItem.item_id,
        MartBillItem.item_code,
        MartBillItem.item_name,
        MartBillItem.uom,
    ).filter(MartBillItem.store_name == mart_name, MartBillItem.item_id.isnot(None))
    query = query.filter(MartBillItem.warehouse_id == resolved_warehouse_id)
    rows = query.distinct().all()
    logger.info(f"Found {len(rows)} distinct items for mart: {mart_name}")
    return [
        {
            "item_id": r[0],
            "item_code": r[1],
            "item_name": r[2],
            "uom": r[3],
        }
        for r in rows
    ]
