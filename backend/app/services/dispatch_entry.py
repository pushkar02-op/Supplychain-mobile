from typing import List, Optional
from datetime import date, datetime
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryUpdate,
)
from app.db.models.order import Order


def create_dispatch_entry(
    db: Session,
    entry: DispatchEntryCreate,
    created_by: Optional[str] = None
) -> DispatchEntry:
    # Validate batch
    batch = db.get(Batch, entry.batch_id)
    if batch is None:
        raise ValueError("Invalid batch_id provided")

    # Create dispatch entry
    db_entry = DispatchEntry(
        **entry.dict(),
        created_by=created_by,
        updated_by=created_by,
    )
    db.add(db_entry)
    if batch.quantity < entry.quantity:
        raise HTTPException(
            status_code=400,
            detail=f"Not enough stock in batch. Available: {batch.quantity}, Requested: {entry.quantity}"
        )
    # Update batch quantity
    batch.quantity -= entry.quantity
    batch.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(db_entry)

    # Update order (if matching order found)
    update_order_dispatch(
        db=db,
        item_id=batch.item_id,
        mart_name=entry.mart_name,
        dispatched_quantity=entry.quantity
    )

    return db_entry


def get_dispatch_entry(db: Session, dispatch_id: int) -> Optional[DispatchEntry]:
    return db.query(DispatchEntry).filter(DispatchEntry.id == dispatch_id).first()


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

    entries = query.offset(skip).limit(limit).all()

    for entry in entries:
        entry.item_id = entry.batch.item_id
        entry.item_name = entry.batch.item.name

    return entries


def update_dispatch_entry(
    db: Session,
    dispatch_id: int,
    entry_update: DispatchEntryUpdate,
    updated_by: Optional[str] = None
) -> Optional[DispatchEntry]:
    db_entry = get_dispatch_entry(db, dispatch_id)
    if not db_entry:
        return None

    for key, value in entry_update.dict(exclude_unset=True).items():
        setattr(db_entry, key, value)

    db_entry.updated_by = updated_by
    db_entry.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(db_entry)
    return db_entry


def delete_dispatch_entry(db: Session, dispatch_id: int) -> bool:
    db_entry = get_dispatch_entry(db, dispatch_id)
    if not db_entry:
        return False

    db.delete(db_entry)
    db.commit()
    return True


def update_order_dispatch(db: Session, item_id: int, mart_name: str, dispatched_quantity: float) -> None:
    """
    Update related order's dispatched quantity and status after dispatch.
    """
    order = db.query(Order).filter(
        Order.item_id == item_id,
        Order.mart_name == mart_name,
        Order.status != "Completed"
    ).first()

    if order:
        order.quantity_dispatched = (order.quantity_dispatched or 0) + dispatched_quantity

        if order.quantity_dispatched >= order.quantity_ordered:
            order.status = "Completed"
        else:
            order.status = "Partially Completed"

        order.updated_at = datetime.utcnow()
        db.commit()
