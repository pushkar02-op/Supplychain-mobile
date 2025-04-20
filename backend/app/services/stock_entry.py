from typing import List, Optional
from sqlalchemy.orm import Session
from app.db.models.stock_entry import StockEntry
from app.db.schemas.stock_entry import (
    StockEntryCreate,
    StockEntryUpdate,
)

from datetime import datetime


def create_stock_entry(db: Session, entry: StockEntryCreate, created_by: Optional[int] = None) -> StockEntry:
    db_entry = StockEntry(
        **entry.dict(),
        created_by=created_by,
        updated_by=created_by,
    )
    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    return db_entry


def get_stock_entry(db: Session, stock_entry_id: int) -> Optional[StockEntry]:
    return db.query(StockEntry).filter(StockEntry.id == stock_entry_id).first()


def get_all_stock_entries(db: Session, skip: int = 0, limit: int = 100) -> List[StockEntry]:
    return db.query(StockEntry).offset(skip).limit(limit).all()


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
