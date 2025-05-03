from typing import List, Optional
from sqlalchemy import and_
from sqlalchemy.orm import Session
from app.db.models.stock_entry import StockEntry
from app.db.schemas.stock_entry import StockEntryCreate, StockEntryUpdate
from app.db.models.batch import Batch
from app.db.models.item import Item
from datetime import date, datetime


def create_stock_entry(db: Session, entry: StockEntryCreate, created_by: Optional[int] = None) -> StockEntry:
    existing_batch = db.query(Batch).filter(
        and_(
            Batch.item_id == entry.item_id,
            Batch.received_at == entry.received_date
        )
    ).first()

    if existing_batch:
        batch_id = existing_batch.id
        existing_batch.quantity += entry.quantity
        existing_batch.updated_by = created_by
    else:
        item = db.query(Item).filter(Item.id == entry.item_id).first()
        unit = item.default_unit if item else entry.unit

        new_batch = Batch(
            item_id=entry.item_id,
            quantity=entry.quantity,
            unit=unit,
            received_at=entry.received_date,
            created_by=created_by,
            updated_by=created_by
        )
        db.add(new_batch)
        db.flush()
        batch_id = new_batch.id

    db_entry = StockEntry(
        **entry.dict(),
        batch_id=batch_id,
        created_by=created_by,
        updated_by=created_by,
    )
    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    return db_entry


def get_stock_entry(db: Session, stock_entry_id: int) -> Optional[StockEntry]:
    return db.query(StockEntry).filter(StockEntry.id == stock_entry_id).first()


def get_all_stock_entries(db: Session, date: Optional[date] = None, skip: int = 0, limit: int = 100) -> List[StockEntry]:
    return db.query(StockEntry).filter(StockEntry.received_date == date).offset(skip).limit(limit).all()


def update_stock_entry(
    db: Session,
    stock_entry_id: int,
    entry_update: StockEntryUpdate,
    updated_by: Optional[int] = None
) -> Optional[StockEntry]:
    db_entry = get_stock_entry(db, stock_entry_id)
    if not db_entry:
        return None

    # Store original values
    original_quantity = db_entry.quantity
    original_batch = db.query(Batch).filter(Batch.id == db_entry.batch_id).first()

    # Extract update fields
    update_data = entry_update.dict(exclude_unset=True)
    new_item_id = update_data.get("item_id", db_entry.item_id)
    new_received_date = update_data.get("received_date", db_entry.received_date)
    new_quantity = update_data.get("quantity", db_entry.quantity)

    # Check if batch reassignment is needed
    is_batch_changed = (new_item_id != db_entry.item_id) or (new_received_date != db_entry.received_date)

    if is_batch_changed:
        # Subtract quantity from old batch
        if original_batch:
            original_batch.quantity -= original_quantity
            original_batch.updated_by = updated_by
            original_batch.updated_at = datetime.utcnow()

        # Find or create new batch
        new_batch = db.query(Batch).filter(
            and_(
                Batch.item_id == new_item_id,
                Batch.received_at == new_received_date
            )
        ).first()

        if not new_batch:
            # Get unit from item (or fallback to existing)
            item = db.query(Item).filter(Item.id == new_item_id).first()
            unit = item.default_unit if item else db_entry.unit

            new_batch = Batch(
                item_id=new_item_id,
                quantity=new_quantity,
                unit=unit,
                received_at=new_received_date,
                created_by=updated_by,
                updated_by=updated_by
            )
            db.add(new_batch)
            db.flush()  # Get new_batch.id
        else:
            new_batch.quantity += new_quantity
            new_batch.updated_by = updated_by
            new_batch.updated_at = datetime.utcnow()

        db_entry.batch_id = new_batch.id

    else:
        # Only update quantity difference in same batch
        quantity_diff = new_quantity - original_quantity
        if original_batch:
            original_batch.quantity += quantity_diff
            original_batch.updated_by = updated_by
            original_batch.updated_at = datetime.utcnow()

    # Apply other updates to stock_entry
    for key, value in update_data.items():
        setattr(db_entry, key, value)

    db_entry.updated_by = updated_by
    db_entry.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(db_entry)
    return db_entry



def delete_stock_entry(db: Session, stock_entry_id: int) -> bool:
    db_entry = get_stock_entry(db, stock_entry_id)
    if not db_entry:
        return False

    # Step 1: Subtract quantity from batch
    batch = db.query(Batch).filter(Batch.id == db_entry.batch_id).first()
    if batch:
        batch.quantity -= db_entry.quantity
        batch.updated_at = datetime.utcnow()
        batch.updated_by = db_entry.updated_by

    db.delete(db_entry)
    db.commit()
    return True
