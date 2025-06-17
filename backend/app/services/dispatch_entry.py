"""
Service functions for dispatch entry management.
Handles creation from single entries or orders, and CRUD operations.
"""

import logging
from typing import List, Optional
from datetime import datetime, date
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.core.exceptions import AppException
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.order import Order
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryMultiCreate,
    DispatchEntryUpdate,
)
from app.services.inventory_txn import create_inventory_txn
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.item_conversion_map import get_conversion_factor

logger = logging.getLogger(__name__)


def create_dispatch_entry(
    db: Session, entry: DispatchEntryCreate, created_by: Optional[str] = None
) -> DispatchEntry:
    """
    Create a single dispatch entry, decrementing batch stock and updating order status.

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
    batch = db.get(Batch, entry.batch_id)
    if not batch:
        logger.error("Invalid batch_id provided")
        raise AppException("Invalid batch_id provided", status_code=400)
    if batch.quantity < entry.quantity:
        msg = f"Not enough stock. Available: {batch.quantity}, requested: {entry.quantity}"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    exists = (
        db.query(DispatchEntry)
        .filter(
            DispatchEntry.item_id == entry.item_id,
            DispatchEntry.mart_name == entry.mart_name,
            DispatchEntry.dispatch_date == entry.dispatch_date,
        )
        .first()
    )
    if exists:
        logger.error("Dispatch entry already exists for this item/date/mart")
        raise AppException("Dispatch entry already exists", status_code=400)

    dispatch = DispatchEntry(
        batch_id=entry.batch_id,
        mart_name=entry.mart_name,
        dispatch_date=entry.dispatch_date,
        quantity=entry.quantity,
        unit=entry.unit,
        remarks=entry.remarks,
        created_by=created_by,
        updated_by=created_by,
    )
    db.add(dispatch)
    batch.quantity -= entry.quantity
    batch.updated_at = datetime.utcnow()
    _update_order_after_dispatch(db, entry.item_id, entry.mart_name, entry.quantity)
    db.flush()
    db.refresh(dispatch)
    db.commit()
    logger.debug(f"Created dispatch id={dispatch.id}")

    try:
        factor = get_conversion_factor(entry.item_id, entry.unit, batch.unit)
    except AppException as e:
        logger.error(f"Conversion lookup failed: {e}")
        raise

    base_qty = entry.quantity * factor

    create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=entry.item_id,
            batch_id=entry.batch_id,
            txn_type="OUT",
            raw_qty=entry.quantity,
            raw_unit=entry.unit,
            base_qty=base_qty,
            base_unit=entry.unit,
            ref_type="dispatch_entry",
            ref_id=dispatch.id,
            remarks="Stock dispatched",
        ),
    )
    return dispatch


def create_dispatch_from_order(
    db: Session, entry: DispatchEntryMultiCreate, created_by: Optional[str] = None
) -> List[DispatchEntry]:
    """
    Create dispatch entries from an order allocation across batches.

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
        select(Order).where(
            Order.item_id == entry.item_id,
            Order.mart_name == entry.mart_name,
            Order.status != "Completed",
        )
    )
    if not order:
        msg = f"No pending order for item {entry.item_id} at mart {entry.mart_name}"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    total_req = sum(b.quantity for b in entry.batches)
    results: List[DispatchEntry] = []
    for b in entry.batches:
        batch = db.scalar(
            select(Batch).where(Batch.id == b.batch_id, Batch.item_id == entry.item_id)
        )
        if not batch:
            logger.error(f"Batch {b.batch_id} not found")
            raise AppException(f"Batch {b.batch_id} not found", status_code=404)
        if batch.quantity < b.quantity:
            msg = (
                f"Batch {b.batch_id} has only {batch.quantity}, requested {b.quantity}"
            )
            logger.error(msg)
            raise AppException(msg, status_code=400)

        existing = db.scalar(
            select(DispatchEntry).where(
                DispatchEntry.batch_id == batch.id,
                DispatchEntry.mart_name == entry.mart_name,
                DispatchEntry.dispatch_date == entry.dispatch_date,
            )
        )
        if existing:
            existing.quantity += b.quantity
            existing.remarks = entry.remarks or existing.remarks
            existing.updated_by = created_by
            existing.updated_at = datetime.utcnow()
            db.add(existing)
            results.append(existing)
        else:
            disp = DispatchEntry(
                item_id=entry.item_id,
                batch_id=batch.id,
                mart_name=entry.mart_name,
                dispatch_date=entry.dispatch_date,
                quantity=b.quantity,
                unit=entry.unit,
                remarks=entry.remarks,
                created_by=created_by,
                updated_by=created_by,
            )
            db.add(disp)
            results.append(disp)

        batch.quantity -= b.quantity
        batch.updated_at = datetime.utcnow()

    _update_order_after_dispatch(db, entry.item_id, entry.mart_name, total_req)
    db.flush()
    for d in results:
        db.refresh(d)
    db.commit()
    logger.debug(f"Created/updated {len(results)} dispatch entries")

    try:
        factor = get_conversion_factor(entry.item_id, entry.unit, batch.unit)
    except AppException as e:
        logger.error(f"Conversion lookup failed: {e}")
        raise
    base_qty = b.quantity * factor

    create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=entry.item_id,
            batch_id=batch.id,
            txn_type="OUT",
            raw_qty=b.quantity,
            raw_unit=entry.unit,
            base_qty=base_qty,
            base_unit=entry.unit,
            ref_type="dispatch_entry",
            ref_id=disp.id if "disp" in locals() else existing.id,
            remarks="Stock dispatched",
        ),
    )
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
        select(Order).where(
            Order.item_id == item_id,
            Order.mart_name == mart_name,
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
    db.commit()


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
    return (
        query.order_by(DispatchEntry.created_at.desc()).offset(skip).limit(limit).all()
    )


def update_dispatch_entry(
    db: Session,
    dispatch_id: int,
    entry_update: DispatchEntryUpdate,
    updated_by: Optional[str] = None,
) -> Optional[DispatchEntry]:
    """
    Update an existing dispatch entry and adjust batch/order accordingly.

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

    old_qty = dispatch.quantity
    new_qty = entry_update.quantity if entry_update.quantity is not None else old_qty
    diff = new_qty - old_qty
    if diff:
        if batch.quantity < -diff:
            msg = f"Not enough stock to increase dispatch. Available: {batch.quantity}, needed: {-diff}"
            logger.error(msg)
            raise AppException(msg, status_code=400)
        batch.quantity -= diff
        batch.updated_at = datetime.utcnow()
        _update_order_after_dispatch(db, dispatch.item_id, dispatch.mart_name, diff)

    for field, val in entry_update.dict(exclude_unset=True).items():
        setattr(dispatch, field, val)
    dispatch.updated_by = updated_by
    dispatch.updated_at = datetime.utcnow()

    db.add(dispatch)
    db.flush()
    db.refresh(dispatch)
    db.commit()
    logger.debug(f"Dispatch id={dispatch_id} updated")

    if diff != 0:
        txn_type = "IN" if diff > 0 else "OUT"
        try:
            factor = get_conversion_factor(
                dispatch.item_id, entry_update.unit, batch.unit
            )
        except AppException as e:
            logger.error(f"Conversion lookup failed: {e}")
            raise

        base_qty = entry_update.quantity * factor

        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=dispatch.item_id,
                batch_id=batch.id,
                txn_type=txn_type,
                raw_qty=entry_update.quantity,
                raw_unit=entry_update.unit,
                base_qty=base_qty,
                base_unit=entry_update.unit,
                ref_type="dispatch_entry",
                ref_id=dispatch.id,
                remarks="Dispatch {txn_type} from update adjustment",
            ),
        )
    return dispatch


def delete_dispatch_entry(db: Session, dispatch_id: int) -> bool:
    """
    Delete a dispatch entry and restore batch/order state.

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

    batch = db.get(Batch, dispatch.batch_id)
    if not batch:
        logger.error("Batch not found during delete")
        raise AppException("Batch not found", status_code=404)

    # batch.quantity += dispatch.quantity
    # batch.updated_at = datetime.utcnow()
    _update_order_after_dispatch(
        db, batch.item_id, dispatch.mart_name, -dispatch.quantity
    )

    db.delete(dispatch)
    db.flush()
    db.commit()
    logger.debug(f"Dispatch id={dispatch_id} deleted")

    try:
        factor = get_conversion_factor(dispatch.item_id, dispatch.unit, batch.unit)
    except AppException as e:
        logger.error(f"Conversion lookup failed: {e}")
        raise

    base_qty = dispatch.quantity * factor

    create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=dispatch.item_id,
            batch_id=batch.id,
            txn_type="OUT",
            raw_qty=dispatch.quantity,
            raw_unit=dispatch.unit,
            base_qty=base_qty,
            base_unit=batch.unit,
            ref_type="dispatch_entry",
            ref_id=dispatch.id,
            remarks="Stock dispatched",
        ),
    )
    return True
