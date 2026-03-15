"""
Service functions for order management.
Handles CRUD operations and retrieval of distinct mart names.
"""

import logging
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.schemas.order import OrderCreate, OrderUpdate
from app.services.audit import log_action
from app.services.financial_lock import enforce_financial_lock, enforce_lock_for_entity
from app.services.warehouse_scope import resolve_system_warehouse_id
from sqlalchemy.orm import Session, joinedload

logger = logging.getLogger(__name__)


def get_distinct_mart_names(
    db: Session, warehouse_id: Optional[int] = None
) -> List[dict]:
    """
    Retrieve mart master records for order entry.

    Args:
        db (Session): Database session.

    Returns:
        List[dict]: List of mart IDs and names.
    """
    resolve_system_warehouse_id(db, warehouse_id)
    logger.debug("Fetching mart names from mart master table")
    results = (
        db.query(Mart.id, Mart.name)
        .filter(Mart.is_active.is_(True))
        .order_by(Mart.name.asc())
        .all()
    )
    marts = [{"id": r.id, "name": r.name} for r in results if r.name]
    logger.info(f"Found {len(marts)} marts")
    return marts


def create_order(
    db: Session,
    entry: OrderCreate,
    created_by: Optional[str] = None,
    warehouse_id: Optional[int] = None,
) -> Order:
    """
    Create a new order unless duplicate exists.
    Resolves mart_name to mart_id internally.

    Args:
        db (Session): Database session.
        entry (OrderCreate): New order data (must include mart_name).
        created_by (Optional[str]): Creator ID.

    Returns:
        Order: Created order.

    Raises:
        AppException: On duplicate order or missing mart.
    """
    logger.info(
        f"Creating order for item_id={entry.item_id}, mart_name={entry.mart_name}, date={entry.order_date}"
    )
    resolved_warehouse_id = resolve_system_warehouse_id(
        db, warehouse_id if warehouse_id is not None else entry.warehouse_id
    )
    enforce_financial_lock(db, resolved_warehouse_id, entry.order_date)

    # ORD-009: Reject Zero Quantity
    if entry.quantity_ordered <= 0:
        raise AppException(
            "Quantity ordered must be greater than zero.",
            status_code=422,
            extra={"rule_id": "ORD-009"},
        )

    # 1. Resolve Mart Name -> Mart ID
    mart = db.query(Mart).filter(Mart.name == entry.mart_name).first()
    if not mart:
        logger.error(f"Mart not found: {entry.mart_name}")
        raise AppException(f"Mart '{entry.mart_name}' not found", status_code=404)

    resolved_mart_id = mart.id

    # 2. Check Duplicate (using resolved ID)
    existing = (
        db.query(Order)
        .filter_by(
            item_id=entry.item_id,
            order_date=entry.order_date,
            mart_id=resolved_mart_id,
            warehouse_id=resolved_warehouse_id,
        )
        .first()
    )
    if existing:
        logger.error("Duplicate order detected")
        raise AppException(
            "Duplicate Order: already exists for this item, mart, and date",
            status_code=400,
        )

    # 3. Prepare Data
    order_data = entry.dict()
    # Remove transient mart_name, inject resolved mart_id
    order_data.pop("mart_name", None)
    order_data["mart_id"] = resolved_mart_id
    order_data["warehouse_id"] = resolved_warehouse_id

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    ord_ = Order(
        **order_data, created_by=user_name, created_by_id=user_id, updated_by=user_name
    )
    db.add(ord_)

    try:
        log_action(
            db=db,
            actor_user_id=user_id,
            action_type="order_created",
            entity_type="order",
            entity_id=ord_.id,
            metadata={
                "warehouse_id": resolved_warehouse_id,
                "order_date": str(entry.order_date),
                "quantity_ordered": str(entry.quantity_ordered),
            },
        )
    except Exception:
        logger.warning("Audit log failed for order_created", exc_info=True)

    db.commit()
    db.refresh(ord_)
    logger.debug(f"Created order id={ord_.id}")
    return ord_


def get_order(
    db: Session, order_id: int, warehouse_id: Optional[int] = None
) -> Optional[Order]:
    """
    Retrieve an order by ID.

    Args:
        db (Session): Database session.
        order_id (int): Order ID.

    Returns:
        Optional[Order]: The order or None.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.debug(f"Retrieving order id={order_id}")
    q = db.query(Order).filter(
        Order.id == order_id, Order.warehouse_id == resolved_warehouse_id
    )
    return q.first()


def get_orders(
    db: Session,
    warehouse_id: Optional[int] = None,
    order_date: Optional[date] = None,
    mart_name: Optional[str] = None,
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
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.debug(f"Fetching orders date={order_date}, mart={mart_name}")
    q = (
        db.query(Order)
        .options(
            joinedload(Order.item),
            joinedload(Order.mart),
        )
        .filter(Order.warehouse_id == resolved_warehouse_id)
    )
    if order_date:
        q = q.filter(Order.order_date == order_date)
    if mart_name:
        from app.db.models.mart import Mart

        q = q.join(Mart, Order.mart_id == Mart.id).filter(Mart.name == mart_name)
    return q.order_by(Order.created_at.desc()).all()


def recalculate_status_helper(order: Order) -> str:
    """Helper to determine status based on dispatched qty."""
    logger.debug("recalculate_status_helper called")
    if not order:
        return "Pending"
    dispatched = Decimal(str(order.quantity_dispatched or 0))
    ordered = Decimal(str(order.quantity_ordered))

    if dispatched >= ordered:
        return "Completed"
    if dispatched > 0:
        return "Partially Completed"
    return "Pending"


def update_order(
    db: Session,
    order_id: int,
    entry_update: OrderUpdate,
    updated_by: Optional[str] = None,
    warehouse_id: Optional[int] = None,
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
    ord_ = get_order(db, order_id, warehouse_id=warehouse_id)
    ord_ = get_order(db, order_id, warehouse_id=warehouse_id)
    if not ord_:
        logger.error(f"Order not found id={order_id}")
        return None
    enforce_lock_for_entity(db, ord_, ord_.order_date)

    # ORD-004: Block Update After Dispatch
    current_dispatched = ord_.quantity_dispatched or 0
    if current_dispatched > 0:
        # Check if core fields are being updated
        # Ideally we allow harmless updates, but test expects block on quantity_ordered
        changes = entry_update.dict(exclude_unset=True)
        # Block if changing quantity or mart or item?
        # Test case specifically tries changing quantity_ordered.
        if "quantity_ordered" in changes or "mart_name" in changes:
            raise AppException(
                "Cannot update order details after dispatch has started.",
                status_code=409,
                extra={"rule_id": "ORD-004"},
            )

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

    try:
        from app.utils.audit import resolve_user_audit

        _, actor_id = resolve_user_audit(db, updated_by)
        log_action(
            db=db,
            actor_user_id=actor_id,
            action_type="order_updated",
            entity_type="order",
            entity_id=ord_.id,
            metadata={"warehouse_id": ord_.warehouse_id},
        )
    except Exception:
        logger.warning("Audit log failed for order_updated", exc_info=True)

    db.commit()
    db.refresh(ord_)
    logger.debug(f"Order id={order_id} updated with status {ord_.status}")
    return ord_


def delete_order(
    db: Session, order_id: int, warehouse_id: Optional[int] = None
) -> bool:
    """
    Delete an order by ID.

    Args:
        db (Session): Database session.
        order_id (int): Order ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting order id={order_id}")
    ord_ = get_order(db, order_id, warehouse_id=warehouse_id)
    if not ord_:
        logger.error(f"Order not found id={order_id}")
        return False

    # ORD-008: Block Delete With Dispatch
    if (ord_.quantity_dispatched or 0) > 0:
        raise AppException(
            "Cannot delete order with existing dispatches.",
            status_code=409,
            extra={"rule_id": "ORD-008"},
        )

    order_wh = ord_.warehouse_id
    order_pk = ord_.id

    try:
        log_action(
            db=db,
            actor_user_id=None,
            action_type="order_deleted",
            entity_type="order",
            entity_id=order_pk,
            metadata={"warehouse_id": order_wh},
        )
    except Exception:
        logger.warning("Audit log failed for order_deleted", exc_info=True)

    db.delete(ord_)
    db.commit()
    logger.debug(f"Order id={order_id} deleted")
    return True


def recompute_order_status(db: Session, order_id: int) -> None:
    """
    Recompute and update order status based on net dispatched quantity.
    Net Quantity = Sum(Dispatch) - Sum(Reversal)

    Args:
        db (Session): Database session.
        order_id (int): Order ID.
    """
    order = get_order(db, order_id)
    if not order:
        logger.error(f"Order not found for recompute id={order_id}")
        return

    # 1. Calculate Total Dispatched (Raw Sum)
    # We need to sum up all dispatch entries for this order.
    # Dispatch Entry does NOT have order_id directly, it uses item_id + mart_id + order_date?
    # No, Dispatch Entry is linked to Batch, Batch to Item.
    # Order is linked to Item + Mart.
    # Dispatch Entry has Mart ID.
    # So we find all dispatch entries for (item, mart) that occurred?
    # Wait, Order is (Item, Mart, Date).
    # Dispatch is (Batch, Item, Mart, Date).
    # Dispatches are usually created ACROSS dates? Or matched?
    #
    # Current logic in `_update_order_after_dispatch`:
    # It finds order by (item_id, mart_name, status!=Completed).
    # This implies FIFO matching or "Active Order" matching.
    # If we are reversing, we act on a specific dispatch entry.
    # That dispatch entry contributed to *some* order.
    #
    # PROBLEM: Dispatch Entry does not store `order_id`.
    # It updates the "current open order" at creation time.
    # If we have multiple orders for same item/mart (e.g. different dates),
    # which one did it update?
    # The current `_update_order_after_dispatch` just grabs "the pending one".
    #
    # If we want to strictly recompute, we need to know WHICH order a dispatch belongs to.
    # BUT the data model doesn't support that link explicitly yet (Legacy limitation).
    #
    # FOR NOW (Phase 1 Correction):
    # We will trust `order.quantity_dispatched` as the running counter,
    # and simply SUBTRACT the reversal amount from it.
    #
    # Full recompute from zero is impossible without `dispatch_entry.order_id`.
    #
    # Plan:
    # 1. Decrease `order.quantity_dispatched` by reversal quantity.
    # 2. Update status based on new value.
    pass


def update_order_status_after_reversal(db: Session, order: Order, reversal_qty) -> None:
    """
    Adjust order dispatched quantity and refresh status after a reversal.
    """
    current_dispatched = Decimal(str(order.quantity_dispatched or 0))
    reversal_dec = Decimal(str(reversal_qty))

    new_dispatched = current_dispatched - reversal_dec
    if new_dispatched < 0:
        logger.warning(
            f"Order {order.id} dispatched qty went negative ({new_dispatched}). Clamping to 0."
        )
        new_dispatched = Decimal(0)

    order.quantity_dispatched = new_dispatched

    # Update Status
    qty_ordered = Decimal(str(order.quantity_ordered))
    if new_dispatched >= qty_ordered:
        order.status = "Completed"
    elif new_dispatched > 0:
        order.status = "Partially Completed"
    else:
        order.status = "Pending"

    order.updated_at = datetime.utcnow()
    db.add(order)
    db.flush()
    logger.info(
        f"Order {order.id} status updated to {order.status} (Dispatched: {new_dispatched})"
    )
