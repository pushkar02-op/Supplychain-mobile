"""
Service functions for invoice item management.
Handles recalculation of totals and CRUD operations on invoice line items.
"""

import logging
from datetime import datetime
from typing import List, Optional

from sqlalchemy.orm import Session

from app.core.exceptions import AppException
from app.db.models.invoice_item import InvoiceItem
from app.db.models.invoice import Invoice
from app.db.models.audit_log import AuditLog
from app.db.schemas.invoice_item import InvoiceItemUpdate

logger = logging.getLogger(__name__)


def recalculate_invoice_total(db: Session, invoice_id: int) -> None:
    """
    Recalculate and update the total_amount of an invoice after item changes.

    Args:
        db (Session): Database session.
        invoice_id (int): ID of the invoice to recalculate.
    """
    logger.info(f"Recalculating total for invoice_id={invoice_id}")
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if not invoice:
        logger.error(f"Invoice not found: id={invoice_id}")
        raise AppException("Invoice not found", status_code=404)

    invoice.total_amount = sum(item.total for item in invoice.items)
    invoice.updated_at = datetime.utcnow()
    db.add(invoice)
    db.commit()
    logger.debug(f"Updated invoice total to {invoice.total_amount}")


def get_items_by_invoice(db: Session, invoice_id: int) -> List[InvoiceItem]:
    """
    Retrieve all line items for a given invoice.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        List[InvoiceItem]: List of items.
    """
    logger.debug(f"Fetching items for invoice_id={invoice_id}")
    return db.query(InvoiceItem).filter(InvoiceItem.invoice_id == invoice_id).all()


def update_invoice_item(
    db: Session, item_id: int, update_data: InvoiceItemUpdate
) -> Optional[InvoiceItem]:
    """
    Update a specific invoice item and recalculate invoice total.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.
        update_data (InvoiceItemUpdate): Fields to update.

    Returns:
        Optional[InvoiceItem]: Updated item, or None if not found.

    Raises:
        AppException: If item not found.
    """
    logger.info(f"Updating invoice item id={item_id}")
    item = db.query(InvoiceItem).filter(InvoiceItem.id == item_id).first()
    if not item:
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)

    for field, value in update_data.dict(exclude_unset=True).items():
        setattr(item, field, value)
    db.commit()
    db.refresh(item)
    logger.debug(f"Item id={item_id} updated, recalculating invoice total")
    recalculate_invoice_total(db, item.invoice_id)
    return item


def delete_invoice_item(db: Session, item_id: int) -> bool:
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
    logger.info(f"Deleting invoice item id={item_id}")
    item = db.query(InvoiceItem).filter(InvoiceItem.id == item_id).first()
    if not item:
        logger.error(f"Invoice item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)

    invoice_id = item.invoice_id
    db.delete(item)
    db.commit()
    logger.debug(f"Item id={item_id} deleted, recalculating invoice total")
    recalculate_invoice_total(db, invoice_id)
    return True
