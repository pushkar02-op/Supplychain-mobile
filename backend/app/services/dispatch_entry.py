"""
Service functions for dispatch entry management.
Handles creation from single entries or orders, and CRUD operations.
"""

import logging
from datetime import date, datetime
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryMultiCreate,
    DispatchEntryUpdate,
)
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.inventory_txn import create_inventory_txn
from app.services.item_conversion_map import get_conversion_factor
from sqlalchemy import select
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from decimal import Decimal


def create_dispatch_entry(
    db: Session, entry: DispatchEntryCreate, created_by: Optional[str] = None
) -> DispatchEntry:
    """
    Create a single dispatch entry, decrementing batch stock and updating order status.
    ENFORCEMENT:
    - INV-005: Canonical Normalization
    - NUM-001: Decimal Safety

    Args:
        db (Session): Database session.
        entry (DispatchEntryCreate): Dispatch data.
        created_by (Optional[str]): Creator identifier.

    Returns:
        DispatchEntry: The created dispatch record.

    Raises:
        AppException: On invalid batch, insufficient stock, or duplicate dispatch.
    """
    logger.info(
        f"Creating dispatch for batch_id={entry.batch_id}, qty={entry.quantity}"
    )
    batch = db.query(Batch).filter(Batch.id == entry.batch_id).with_for_update().first()
    if not batch:
        logger.error("Invalid batch_id provided")
        raise AppException("Invalid batch_id provided", status_code=400)

    mart = db.scalar(select(Mart).where(Mart.name == entry.mart_name))
    if not mart:
        logger.error(f"Mart {entry.mart_name} not found")
        raise AppException(f"Mart {entry.mart_name} not found", status_code=404)

    # ====================================================================
    # ORD-007 ENFORCEMENT: Dispatch Must Respect Order Remaining Quantity
    # This check MUST occur BEFORE any inventory mutation.
    # ====================================================================
    order = db.scalar(
        select(Order).where(
            Order.item_id == entry.item_id,
            Order.mart_id == mart.id,
            Order.status.notin_(["Cancelled", "Completed"]),
        )
    )
    if order:
        existing_dispatched = Decimal(str(order.quantity_dispatched or 0))
        quantity_ordered = Decimal(str(order.quantity_ordered))
        dispatch_qty = Decimal(str(entry.quantity))
        remaining_qty = quantity_ordered - existing_dispatched

        if dispatch_qty > remaining_qty:
            logger.warning(
                f"ORD-007 BLOCKED: Dispatch {dispatch_qty} exceeds remaining {remaining_qty} "
                f"for order {order.id}"
            )
            raise AppException(
                message=f"Dispatch quantity ({dispatch_qty}) exceeds remaining order quantity ({remaining_qty}).",
                status_code=409,
                extra={
                    "rule_id": "ORD-007",
                    "requested_quantity": float(dispatch_qty),
                    "remaining_quantity": float(remaining_qty),
                    "explanation": "Over-dispatch is not allowed. Reduce quantity or create a new order.",
                },
            )

    # Check for dispatch against Cancelled/Completed orders
    blocked_order = db.scalar(
        select(Order).where(
            Order.item_id == entry.item_id,
            Order.mart_id == mart.id,
            Order.status.in_(["Cancelled", "Completed"]),
        )
    )
    if blocked_order and not order:
        # No active order, but a cancelled/completed one exists
        logger.warning(
            f"ORD-007 BLOCKED: Dispatch against {blocked_order.status} order {blocked_order.id}"
        )
        raise AppException(
            message=f"Cannot dispatch against {blocked_order.status} order.",
            status_code=409,
            extra={
                "rule_id": "ORD-007",
                "order_status": blocked_order.status,
                "explanation": f"Order is {blocked_order.status} and cannot receive dispatches.",
            },
        )
    # ====================================================================

    # 1) Normalize to Batch Unit (Canonical)
    # Batch is assumed/enforced to be in canonical unit by stock_entry logic.
    try:
        factor = Decimal(
            str(get_conversion_factor(db, entry.item_id, entry.unit, batch.unit))
        )
    except AppException as e:
        logger.error(f"Conversion failed for dispatch: {e}")
        raise

    raw_qty = Decimal(str(entry.quantity))
    canonical_qty = raw_qty * factor

    # 2) Validate Availability (Canonical vs Canonical)
    if batch.quantity < canonical_qty:
        msg = f"Not enough stock. Available: {batch.quantity} {batch.unit}, requested: {entry.quantity} {entry.unit} ({canonical_qty} {batch.unit})"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    exists = (
        db.query(DispatchEntry)
        .filter(
            DispatchEntry.item_id == entry.item_id,
            DispatchEntry.mart_id == mart.id,
            DispatchEntry.dispatch_date == entry.dispatch_date,
        )
        .first()
    )
    if exists:
        logger.error("Dispatch entry already exists for this item/date/mart")
        raise AppException("Dispatch entry already exists", status_code=400)

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    dispatch = DispatchEntry(
        batch_id=entry.batch_id,
        item_id=entry.item_id,
        mart_id=mart.id,
        dispatch_date=entry.dispatch_date,
        quantity=entry.quantity,  # Store raw user request
        unit=entry.unit,
        remarks=entry.remarks,
        created_by=user_name,
        created_by_id=user_id,
        updated_by=user_name,
    )
    db.add(dispatch)

    # 3) Mutate Batch (Canonical)
    batch.quantity -= canonical_qty
    batch.updated_at = datetime.utcnow()

    _update_order_after_dispatch(db, entry.item_id, entry.mart_name, entry.quantity)
    db.flush()
    db.refresh(dispatch)
    logger.debug(f"Created/Updating dispatch record for item_id={entry.item_id}")

    # 4) Ledger OUT movement
    # Using the same calculated factor/canonical_qty ensures consistency
    try:
        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=entry.item_id,
                batch_id=entry.batch_id,
                txn_type="OUT",
                raw_qty=entry.quantity,
                raw_unit=entry.unit,
                base_qty=canonical_qty,
                base_unit=batch.unit,
                ref_type="dispatch_entry",
                ref_id=dispatch.id,
                remarks="Stock dispatched",
            ),
        )
    except AppException as e:
        logger.error(f"Ledgering failed: {e}")
        raise

    db.commit()
    logger.debug(f"Created dispatch id={dispatch.id}")
    return dispatch


def create_dispatch_from_order(
    db: Session, entry: DispatchEntryMultiCreate, created_by: Optional[str] = None
) -> List[DispatchEntry]:
    """
    Create dispatch entries from an order allocation across batches.
    ENFORCEMENT:
    - INV-005: Canonical Normalization
    - NUM-001: Decimal Safety

    Args:
        db (Session): Database session.
        entry (DispatchEntryMultiCreate): Multi-batch dispatch data.
        created_by (Optional[str]): Creator identifier.

    Returns:
        List[DispatchEntry]: All created/updated dispatch records.

    Raises:
        AppException: If no pending order or batch issues.
    """
    logger.info(f"Creating dispatches from order for item_id={entry.item_id}")
    order = db.scalar(
        select(Order)
        .join(Mart)
        .where(
            Order.item_id == entry.item_id,
            Mart.name == entry.mart_name,
            Order.status != "Completed",
        )
    )
    if not order:
        msg = f"No pending order for item {entry.item_id} at mart {entry.mart_name}"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    total_req = sum(b.quantity for b in entry.batches)
    # 1) Deterministically lock all involved batches to prevent deadlocks
    params_batch_ids = sorted(list({b.batch_id for b in entry.batches}))

    locked_batches = (
        db.query(Batch)
        .filter(Batch.id.in_(params_batch_ids))
        .filter(Batch.item_id == entry.item_id)
        .order_by(Batch.id)
        .with_for_update()
        .all()
    )

    batch_map = {b.id: b for b in locked_batches}

    # Verify all batches were found
    if len(batch_map) != len(params_batch_ids):
        found_ids = set(batch_map.keys())
        missing = set(params_batch_ids) - found_ids
        msg = f"Batches not found for item {entry.item_id}: {missing}"
        logger.error(msg)
        raise AppException(msg, status_code=404)

    results: List[DispatchEntry] = []

    # 2) Process each requested allocation using the locked batch objects
    for b in entry.batches:
        batch = batch_map[b.batch_id]

        # Canonical Normalization
        try:
            factor = Decimal(
                str(get_conversion_factor(db, entry.item_id, entry.unit, batch.unit))
            )
        except AppException as e:
            logger.error(f"Conversion failed for batch {batch.id}: {e}")
            raise

        raw_qty = Decimal(str(b.quantity))
        canonical_qty = raw_qty * factor

        if batch.quantity < canonical_qty:
            msg = f"Batch {b.batch_id} has only {batch.quantity} {batch.unit}, requested {b.quantity} {entry.unit} ({canonical_qty} {batch.unit})"
            logger.error(msg)
            raise AppException(msg, status_code=400)

        existing = db.scalar(
            select(DispatchEntry).where(
                DispatchEntry.batch_id == batch.id,
                DispatchEntry.mart_id == order.mart_id,
                DispatchEntry.dispatch_date == entry.dispatch_date,
            )
        )
        if existing:
            existing.quantity += b.quantity  # Raw update
            existing.remarks = entry.remarks or existing.remarks
            from app.utils.audit import resolve_user_audit

            user_name, _ = resolve_user_audit(
                db, created_by
            )  # Treated as updated_by here
            existing.updated_by = user_name
            existing.updated_at = datetime.utcnow()
            db.add(existing)
            results.append(existing)
        else:
            from app.utils.audit import resolve_user_audit

            user_name, user_id = resolve_user_audit(db, created_by)

            disp = DispatchEntry(
                item_id=entry.item_id,
                batch_id=batch.id,
                mart_id=order.mart_id,
                dispatch_date=entry.dispatch_date,
                quantity=b.quantity,  # Raw
                unit=entry.unit,
                remarks=entry.remarks,
                created_by=user_name,
                created_by_id=user_id,
                updated_by=user_name,
            )
            db.add(disp)
            results.append(disp)

        # Mutate Batch (Canonical)
        batch.quantity -= canonical_qty
        batch.updated_at = datetime.utcnow()

        # 4) Ledger OUT movement for this batch
        try:
            # Factor already calculated
            # base_qty = canonical_qty (already calculated)

            create_inventory_txn(
                db,
                InventoryTxnCreate(
                    item_id=entry.item_id,
                    batch_id=batch.id,
                    txn_type="OUT",
                    raw_qty=b.quantity,
                    raw_unit=entry.unit,
                    base_qty=canonical_qty,
                    base_unit=batch.unit,
                    ref_type="dispatch_entry",
                    ref_id=disp.id if "disp" in locals() else existing.id,
                    remarks="Stock dispatched",
                ),
            )
        except AppException as e:
            logger.error(f"Ledgering failed for batch {batch.id}: {e}")
            raise

    # 5) Finalize Order and Transactions
    _update_order_after_dispatch(db, entry.item_id, entry.mart_name, total_req)
    db.flush()
    for d in results:
        db.refresh(d)
    db.commit()
    logger.debug(f"Created/updated {len(results)} dispatch entries")

    return results


def _update_order_after_dispatch(
    db: Session, item_id: int, mart_name: str, dispatched_quantity: float
) -> None:
    """
    Update the corresponding order’s dispatched quantity and status.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.
        mart_name (str): Mart name.
        dispatched_quantity (float): Quantity dispatched in this operation.
    """
    order = db.scalar(
        select(Order)
        .join(Mart)
        .where(
            Order.item_id == item_id,
            Mart.name == mart_name,
            Order.status != "Completed",
        )
    )
    if not order:
        return
    order.quantity_dispatched = (order.quantity_dispatched or 0) + dispatched_quantity
    order.status = (
        "Completed"
        if order.quantity_dispatched >= order.quantity_ordered
        else "Partially Completed"
    )
    order.updated_at = datetime.utcnow()
    db.add(order)
    db.flush()


def get_dispatch_entry(db: Session, dispatch_id: int) -> Optional[DispatchEntry]:
    """
    Retrieve a dispatch entry by ID.

    Args:
        db (Session): Database session.
        dispatch_id (int): Dispatch entry ID.

    Returns:
        Optional[DispatchEntry]: The dispatch entry or None.
    """
    logger.debug(f"Retrieving dispatch id={dispatch_id}")
    return db.get(DispatchEntry, dispatch_id)


def get_all_dispatch_entries(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    dispatch_date: Optional[date] = None,
    mart_name: Optional[str] = None,
) -> List[DispatchEntry]:
    """
    Retrieve dispatch entries with optional filters and pagination.

    Args:
        db (Session): Database session.
        skip (int): Records to skip.
        limit (int): Max records to return.
        dispatch_date (Optional[date]): Filter by date.
        mart_name (Optional[str]): Filter by mart name.

    Returns:
        List[DispatchEntry]: List of dispatch entries.
    """
    logger.debug(
        f"Fetching dispatches skip={skip}, limit={limit}, date={dispatch_date}, mart={mart_name}"
    )
    query = db.query(DispatchEntry)
    if dispatch_date:
        query = query.filter(DispatchEntry.dispatch_date == dispatch_date)
    if mart_name:
        query = query.filter(DispatchEntry.mart_name == mart_name)
    if mart_name:
        query = query.filter(DispatchEntry.mart_name == mart_name)

    from app.utils.pagination import get_pagination_params

    offset, limit = get_pagination_params(skip=skip, limit=limit)

    return (
        query.order_by(DispatchEntry.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )


def update_dispatch_entry(
    db: Session,
    dispatch_id: int,
    entry_update: DispatchEntryUpdate,
    updated_by: Optional[str] = None,
) -> Optional[DispatchEntry]:
    """
    Update an existing dispatch entry and adjust batch/order accordingly.
    ENFORCEMENT:
    - INV-005: Canonical Normalization
    - NUM-001: Decimal Safety

    Args:
        db (Session): Database session.
        dispatch_id (int): Dispatch entry ID.
        entry_update (DispatchEntryUpdate): Fields to update.
        updated_by (Optional[str]): Updater identifier.

    Returns:
        Optional[DispatchEntry]: The updated dispatch entry or None.

    Raises:
        AppException: If original batch not found or insufficient stock.
    """
    logger.info(f"Updating dispatch id={dispatch_id}")
    dispatch = db.get(DispatchEntry, dispatch_id)
    if not dispatch:
        logger.error(f"Dispatch not found id={dispatch_id}")
        return None

    batch = db.get(Batch, dispatch.batch_id)
    if not batch:
        logger.error("Original batch not found")
        raise AppException("Original batch not found", status_code=404)

    # Calculate Canonical Diffs
    old_qty_raw = Decimal(str(dispatch.quantity))
    data = entry_update.dict(exclude_unset=True)
    new_qty_raw = Decimal(str(data.get("quantity", dispatch.quantity)))
    new_unit = data.get("unit", dispatch.unit)

    # 1. Reverse old contribution (Canonical)
    try:
        factor_old = Decimal(
            str(get_conversion_factor(db, dispatch.item_id, dispatch.unit, batch.unit))
        )
        old_canonical = old_qty_raw * factor_old

        # 2. New contribution (Canonical)
        factor_new = Decimal(
            str(get_conversion_factor(db, dispatch.item_id, new_unit, batch.unit))
        )
        new_canonical = new_qty_raw * factor_new

        canonical_diff = new_canonical - old_canonical

    except AppException as e:
        logger.error(f"Conversion failed during update: {e}")
        raise

    if canonical_diff != 0:
        # Check if increasing usage
        if canonical_diff > 0:
            if batch.quantity < canonical_diff:
                msg = f"Not enough stock to increase dispatch. Available: {batch.quantity} {batch.unit}, needed: {canonical_diff} {batch.unit}"
                logger.error(msg)
                raise AppException(msg, status_code=400)

        batch.quantity -= canonical_diff
        batch.updated_at = datetime.utcnow()
        # Order update logic remains using RAW diff (assuming simpler counting)
        # Note: If order unit different, this is ambiguous, but keeping as is for Phase 1.
        raw_diff = new_qty_raw - old_qty_raw
        _update_order_after_dispatch(
            db, dispatch.item_id, dispatch.mart.name, float(raw_diff)
        )

    for field, val in data.items():
        setattr(dispatch, field, val)
    from app.utils.audit import resolve_user_audit

    user_name, _ = resolve_user_audit(db, updated_by)  # No updated_by_id yet
    dispatch.updated_by = user_name
    dispatch.updated_at = datetime.utcnow()

    db.add(dispatch)
    db.flush()
    db.refresh(dispatch)
    logger.debug(f"Dispatch id={dispatch_id} meta-fields updated")

    if canonical_diff != 0:
        txn_type = (
            "IN" if canonical_diff < 0 else "OUT"
        )  # diff > 0 means we took MORE stock OUT
        # Wait, if canonical_diff > 0, we increased dispatch, so batch decreases.
        # But for TXN, if we increase dispatch, we are doing another OUT.
        # Original: txn_type = "IN" if diff > 0 else "OUT"
        # Wait.
        # stock_entry update: diff > 0 means stock INCREASED -> IN.
        # dispatch_entry update: diff > 0 means dispatch INCREASED -> Stock DECREASE -> OUT.

        # Let's double check original logic:
        # old: diff = new - old
        # if diff > 0: batch -= diff. (Stock goes down).
        # txn: diff > 0 -> txn_type = "IN"?
        # Original code line 426: txn_type = "IN" if diff > 0 else "OUT"
        # If dispatch increased, we took more stock. This is an OUT transaction relative to inventory?
        # NO. InventoryTxn types: IN (stock added), OUT (stock removed).
        # If dispatch quantity INCREASES, we remove MORE stock. So it should be OUT.
        # If original code said IN, it might have been tracking dispatch size not stock flow?
        # create_dispatch uses OUT.
        # So additional dispatch = OUT.
        # Reduction in dispatch = IN (refund).

        final_txn_type = "OUT" if canonical_diff > 0 else "IN"

        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=dispatch.item_id,
                batch_id=batch.id,
                txn_type=final_txn_type,
                raw_qty=abs(new_qty_raw - old_qty_raw),  # Approximate raw
                raw_unit=new_unit,
                base_qty=abs(canonical_diff),
                base_unit=batch.unit,  # Canonical
                ref_type="dispatch_entry",
                ref_id=dispatch.id,
                remarks="Dispatch update adjustment",
            ),
        )

    db.commit()
    logger.debug(f"Dispatch id={dispatch_id} fully updated and ledgered")
    return dispatch


def delete_dispatch_entry(db: Session, dispatch_id: int) -> bool:
    """
    Delete a dispatch entry and restore batch/order state.
    ENFORCEMENT:
    - INV-005: Canonical Normalization
    - NUM-001: Decimal Safety

    Args:
        db (Session): Database session.
        dispatch_id (int): Dispatch entry ID.

    Returns:
        bool: True if deleted, False otherwise.

    Raises:
        AppException: If batch not found during restoration.
    """
    logger.info(f"Deleting dispatch id={dispatch_id}")
    dispatch = db.get(DispatchEntry, dispatch_id)
    if not dispatch:
        logger.error(f"Dispatch not found id={dispatch_id}")
        return False

    # Lock batch to restore stock safely
    batch = (
        db.query(Batch).filter(Batch.id == dispatch.batch_id).with_for_update().first()
    )
    if not batch:
        logger.error("Batch not found during delete")
        raise AppException("Batch not found", status_code=404)

    # 1) Restore Stock (Canonical)
    try:
        factor = Decimal(
            str(get_conversion_factor(db, dispatch.item_id, dispatch.unit, batch.unit))
        )
        canonical_qty = Decimal(str(dispatch.quantity)) * factor
    except AppException as e:
        logger.error(f"Conversion failed during delete dispatch: {e}")
        raise

    batch.quantity += canonical_qty
    batch.updated_at = datetime.utcnow()

    _update_order_after_dispatch(
        db, batch.item_id, dispatch.mart.name, -dispatch.quantity
    )

    db.delete(dispatch)
    db.flush()

    # Ledger IN (Stock back)
    try:
        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=dispatch.item_id,
                batch_id=batch.id,
                txn_type="IN",  # Stock Coming Back
                raw_qty=dispatch.quantity,
                raw_unit=dispatch.unit,
                base_qty=canonical_qty,
                base_unit=batch.unit,
                ref_type="dispatch_entry",
                ref_id=dispatch.id,
                remarks="Stock dispatch deleted (Reversal)",
            ),
        )
    except AppException as e:
        logger.error(f"Reversal ledgering failed: {e}")
        raise

    db.commit()
    logger.debug(f"Dispatch id={dispatch_id} deleted and stock restored")
    return True
