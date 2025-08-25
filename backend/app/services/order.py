"""
Service functions for order management.
Handles CRUD operations and retrieval of distinct mart names.
"""

import logging
from datetime import date, datetime
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.models.invoice import Invoice
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.schemas.order import OrderCreate, OrderUpdate
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def get_distinct_mart_names(db: Session) -> List[dict]:
    """
    Retrieve unique mart names from invoices.

    Args:
        db (Session): Database session.

    Returns:
        List[str]: List of mart names.
    """
    logger.debug("Fetching distinct mart names from invoices")
    results = (
        db.query(Mart.id, Mart.name)
        .join(Invoice, Invoice.mart_id == Mart.id)
        .distinct()
        .all()
    )
    marts = [{"id": r.id, "name": r.name} for r in results if r.name]
    logger.info(f"Found {len(marts)} distinct marts")
    return marts


def create_order(
    db: Session, entry: OrderCreate, created_by: Optional[str] = None
) -> Order:
    """
    Create a new order unless duplicate exists.

    Args:
        db (Session): Database session.
        entry (OrderCreate): New order data.
        created_by (Optional[str]): Creator ID.

    Returns:
        Order: Created order.

    Raises:
        AppException: On duplicate order.
    """
    logger.info(
        f"Creating order for item_id={entry.item_id}, mart={entry.mart_id}, date={entry.order_date}"
    )
    existing = (
        db.query(Order)
        .filter_by(
            item_id=entry.item_id,
            order_date=entry.order_date,
            mart_id=entry.mart_id,
        )
        .first()
    )
    if existing:
        logger.error("Duplicate order detected")
        raise AppException(
            "Duplicate Order: already exists for this item, mart, and date",
            status_code=400,
        )

    order_data = entry.dict()
    order_data["mart_id"] = entry.mart_id
    ord_ = Order(**order_data, created_by=created_by, updated_by=created_by)
    db.add(ord_)
    db.commit()
    db.refresh(ord_)
    logger.debug(f"Created order id={ord_.id}")
    return ord_


def get_order(db: Session, order_id: int) -> Optional[Order]:
    """
    Retrieve an order by ID.

    Args:
        db (Session): Database session.
        order_id (int): Order ID.

    Returns:
        Optional[Order]: The order or None.
    """
    logger.debug(f"Retrieving order id={order_id}")
    return db.query(Order).filter(Order.id == order_id).first()


def get_orders(
    db: Session, order_date: Optional[date] = None, mart_name: Optional[str] = None
) -> List[Order]:
    """
    Retrieve orders with optional filters.

    Args:
        db (Session): Database session.
        order_date (Optional[date]): Filter by date.
        mart_name (Optional[str]): Filter by mart.

    Returns:
        List[Order]: List of orders.
    """
    logger.debug(f"Fetching orders date={order_date}, mart={mart_name}")
    q = db.query(Order)
    if order_date:
        q = q.filter(Order.order_date == order_date)
    if mart_name:
        from app.db.models.mart import Mart

        q = q.join(Mart, Order.mart_id == Mart.id).filter(Mart.name == mart_name)
    return q.order_by(Order.created_at.desc()).all()


def update_order(
    db: Session,
    order_id: int,
    entry_update: OrderUpdate,
    updated_by: Optional[str] = None,
) -> Optional[Order]:
    """
    Update an existing order and adjust status automatically.

    Args:
        db (Session): Database session.
        order_id (int): Order ID.
        entry_update (OrderUpdate): Fields to update.
        updated_by (Optional[str]): Updater ID.

    Returns:
        Optional[Order]: Updated order or None.
    """
    logger.info(f"Updating order id={order_id}")
    ord_ = get_order(db, order_id)
    if not ord_:
        logger.error(f"Order not found id={order_id}")
        return None

    update_data = entry_update.dict(exclude_unset=True)
    if "mart_name" in update_data:
        mart_name = update_data.pop("mart_name")
        mart = db.query(Mart).filter(Mart.name == mart_name).first()
        if not mart:
            raise AppException(f"Mart '{mart_name}' not found", status_code=404)
        update_data["mart_id"] = mart.id

    original_dispatched = ord_.quantity_dispatched or 0
    for field, val in update_data.items():
        setattr(ord_, field, val)
    # Adjust status
    if ord_.quantity_ordered <= original_dispatched:
        ord_.status = "Completed"
    else:
        ord_.status = "Partially Completed"
    ord_.updated_by = updated_by
    ord_.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(ord_)
    logger.debug(f"Order id={order_id} updated with status {ord_.status}")
    return ord_


def delete_order(db: Session, order_id: int) -> bool:
    """
    Delete an order by ID.

    Args:
        db (Session): Database session.
        order_id (int): Order ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting order id={order_id}")
    ord_ = get_order(db, order_id)
    if not ord_:
        logger.error(f"Order not found id={order_id}")
        return False
    db.delete(ord_)
    db.commit()
    logger.debug(f"Order id={order_id} deleted")
    return True
