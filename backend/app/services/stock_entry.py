from typing import List, Optional
from sqlalchemy import and_
from sqlalchemy.orm import Session
from app.db.models.stock_entry import StockEntry
from app.db.schemas.stock_entry import (
    StockEntryCreate,
    StockEntryUpdate,
)
from app.db.models.batch import Batch
from app.db.models.item import Item
from datetime import date, datetime


def create_stock_entry(db: Session, entry: StockEntryCreate, created_by: Optional[int] = None) -> StockEntry:
    # 1. Check for existing batch for same item and received_date
    existing_batch = db.query(Batch).filter(
        and_(
            Batch.item_id == entry.item_id,
            Batch.expiry_date == entry.received_date  # Grouping by date as batch key
        )
    ).first()

    if existing_batch:
        batch_id = existing_batch.id
        existing_batch.quantity += entry.quantity  # update existing batch quantity
        existing_batch.updated_by = created_by
    else:
        # Fetch unit from item if not explicitly in entry
        item = db.query(Item).filter(Item.id == entry.item_id).first()
        unit = item.default_unit if item else entry.unit

        new_batch = Batch(
            item_id=entry.item_id,
            quantity=entry.quantity,
            unit=unit,
            expiry_date=entry.received_date,  # used as batch grouping key
            created_by=created_by,
            updated_by=created_by
        )
        db.add(new_batch)
        db.flush()  # get new_batch.id
        batch_id = new_batch.id

    # 2. Create stock entry using batch
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

    for key, value in entry_update.dict(exclude_unset=True).items():
        print(key)
        print(value)
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

    db.delete(db_entry)
    db.commit()
    return True
