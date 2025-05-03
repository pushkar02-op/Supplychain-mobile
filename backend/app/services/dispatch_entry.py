# app/services/dispatch_entry.py

from typing import List, Optional
from datetime import datetime, date
from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.order import Order
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryMultiCreate,
    DispatchEntryUpdate,
)

def create_dispatch_entry(
    db: Session,
    entry: DispatchEntryCreate,
    created_by: Optional[str] = None
) -> DispatchEntry:
    """
    Single‐batch dispatch. Atomic: create dispatch row + update batch + update order.
    """
    # Start a transaction
    with db.begin():
        # 1. Load and validate batch
        batch = db.get(Batch, entry.batch_id)
        if not batch:
            raise HTTPException(400, "Invalid batch_id provided")

        if batch.quantity < entry.quantity:
            raise HTTPException(
                400,
                f"Not enough stock in batch. Available: {batch.quantity}, requested: {entry.quantity}"
            )

        # 2. Create dispatch entry
        dispatch = DispatchEntry(
            batch_id=entry.batch_id,
            mart_name=entry.mart_name,
            dispatch_date=entry.dispatch_date,
            quantity=entry.quantity,
            unit=entry.unit,
            remarks=getattr(entry, "remarks", None),
            created_by=created_by,
            updated_by=created_by,
        )
        db.add(dispatch)

        # 3. Deduct from batch
        batch.quantity -= entry.quantity
        batch.updated_at = datetime.utcnow()

        # 4. Update related order, if any
        _update_order_after_dispatch(
            db=db,
            item_id=batch.item_id,
            mart_name=entry.mart_name,
            dispatched_quantity=entry.quantity
        )

    # Outside the transaction block, objects are committed
    db.refresh(dispatch)
    return dispatch


def create_dispatch_from_order(
    db: Session,
    entry: DispatchEntryMultiCreate,
    created_by: Optional[str] = None
) -> List[DispatchEntry]:
    """
    Dispatch items from order using one or more batches. 
    If same item is dispatched to same mart on same day, update previous dispatch.
    Also deduct from batch stock and update order + batch metadata.
    """
    with db.begin():
        # 1. Load order
        order = db.scalar(
            select(Order).where(
                Order.item_id == entry.item_id,
                Order.mart_name == entry.mart_name,
                Order.status != "Completed"
            )
        )
        if not order:
            raise HTTPException(400, "No pending order found for this item and mart")

        total_requested = sum(b.quantity for b in entry.batches)
        if (order.quantity_dispatched or 0) + total_requested > order.quantity_ordered:
            raise HTTPException(400, "Dispatched quantity exceeds remaining order quantity")

        updated_or_created_dispatches: List[DispatchEntry] = []

        # 2. Process each batch
        for b in entry.batches:
            batch = db.scalar(
                select(Batch).where(Batch.id == b.batch_id, Batch.item_id == entry.item_id)
            )
            if not batch:
                raise HTTPException(404, f"Batch {b.batch_id} not found for this item")

            if batch.quantity < b.quantity:
                raise HTTPException(
                    400,
                    f"Batch {batch.id} has only {batch.quantity}, requested {b.quantity}"
                )

            # 3. Check if a dispatch already exists for same batch, mart, and date
            existing_dispatch = db.scalar(
                select(DispatchEntry).where(
                    DispatchEntry.batch_id == batch.id,
                    DispatchEntry.mart_name == entry.mart_name,
                    DispatchEntry.dispatch_date == entry.dispatch_date
                )
            )

            if existing_dispatch:
                # Update quantity
                existing_dispatch.quantity += b.quantity
                existing_dispatch.remarks = entry.remarks or existing_dispatch.remarks
                existing_dispatch.updated_by = created_by
                existing_dispatch.updated_at = datetime.utcnow()
                db.add(existing_dispatch)
                updated_or_created_dispatches.append(existing_dispatch)
            else:
                # Create new dispatch
                dispatch = DispatchEntry(
                    batch_id=batch.id,
                    mart_name=entry.mart_name,
                    dispatch_date=entry.dispatch_date,
                    quantity=b.quantity,
                    unit=entry.unit,
                    remarks=entry.remarks,
                    created_by=created_by,
                    updated_by=created_by,
                )
                db.add(dispatch)
                updated_or_created_dispatches.append(dispatch)

            # 4. Deduct batch quantity
            batch.quantity -= b.quantity
            batch.updated_at = datetime.utcnow()

            # 5. Update item name/unit in batch if not already set
            if not batch.item_name:
                batch.item_name = entry.item_name
            if not batch.unit:
                batch.unit = entry.unit

        # 6. Update order's dispatched quantity & status
        _update_order_after_dispatch(
            db=db,
            item_id=entry.item_id,
            mart_name=entry.mart_name,
            dispatched_quantity=total_requested
        )

    # 7. Refresh and return all updated/created dispatches
    for d in updated_or_created_dispatches:
        db.refresh(d)
    return updated_or_created_dispatches


def _update_order_after_dispatch(
    db: Session,
    item_id: int,
    mart_name: str,
    dispatched_quantity: float
) -> None:
    """
    Internal helper, assumes within an active transaction.
    """
    order = db.scalar(
        select(Order).where(
            Order.item_id == item_id,
            Order.mart_name == mart_name,
            Order.status != "Completed"
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
    db.add(order)  # mark as dirty


def get_dispatch_entry(db: Session, dispatch_id: int) -> Optional[DispatchEntry]:
    return db.get(DispatchEntry, dispatch_id)


def get_all_dispatch_entries(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    dispatch_date: Optional[date] = None,
    mart_name: Optional[str] = None
) -> List[DispatchEntry]:
    query = db.query(DispatchEntry)
    if dispatch_date:
        query = query.filter(DispatchEntry.dispatch_date == dispatch_date)
    if mart_name:
        query = query.filter(DispatchEntry.mart_name == mart_name)
    return query.order_by(DispatchEntry.created_at.desc()).offset(skip).limit(limit).all()


def update_dispatch_entry(
    db: Session,
    dispatch_id: int,
    entry_update: DispatchEntryUpdate,
    updated_by: Optional[str] = None
) -> Optional[DispatchEntry]:
    with db.begin():
        dispatch = db.get(DispatchEntry, dispatch_id)
        if not dispatch:
            return None

        # 1. Load related batch and order
        old_batch = db.get(Batch, dispatch.batch_id)
        if not old_batch:
            raise HTTPException(404, "Original batch not found")

        # Only update if quantity is changed
        old_quantity = dispatch.quantity
        new_quantity = entry_update.quantity if entry_update.quantity is not None else old_quantity
        quantity_diff = new_quantity - old_quantity

        # If quantity changed, adjust batch and order
        if quantity_diff != 0:
            # a) Update Batch
            if old_batch.quantity < -quantity_diff:
                raise HTTPException(
                    400,
                    f"Not enough stock to increase dispatch. Available: {old_batch.quantity}, needed: {-quantity_diff}"
                )
            old_batch.quantity -= quantity_diff
            old_batch.updated_at = datetime.utcnow()

            # b) Update Order
            _update_order_after_dispatch(
                db=db,
                item_id=old_batch.item_id,
                mart_name=dispatch.mart_name,
                dispatched_quantity=quantity_diff
            )

        # 2. Update dispatch entry fields
        for field, val in entry_update.dict(exclude_unset=True).items():
            setattr(dispatch, field, val)
        dispatch.updated_by = updated_by
        dispatch.updated_at = datetime.utcnow()

        db.add(dispatch)

    db.refresh(dispatch)
    return dispatch


def delete_dispatch_entry(db: Session, dispatch_id: int) -> bool:
    with db.begin():
        dispatch = db.get(DispatchEntry, dispatch_id)
        if not dispatch:
            return False

        # Get related batch
        batch = db.get(Batch, dispatch.batch_id)
        if not batch:
            raise HTTPException(status_code=404, detail="Batch not found")

        # 1. Restore quantity back to batch
        batch.quantity += dispatch.quantity
        batch.updated_at = datetime.utcnow()

        # 2. Update order's dispatched quantity
        _update_order_after_dispatch(
            db=db,
            item_id=batch.item_id,
            mart_name=dispatch.mart_name,
            dispatched_quantity=-dispatch.quantity  # subtract from dispatched total
        )

        # 3. Delete dispatch
        db.delete(dispatch)

    return True
