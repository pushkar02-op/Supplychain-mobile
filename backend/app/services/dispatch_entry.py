from typing import List, Optional
from datetime import datetime
from app.db.models.batch import Batch
from sqlalchemy.orm import Session
from app.db.models.dispatch_entry import DispatchEntry
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryUpdate,
)

def create_dispatch_entry(
    db: Session,
    entry: DispatchEntryCreate,
    created_by: Optional[str] = None
) -> DispatchEntry:
    db_entry = DispatchEntry(
        **entry.dict(),
        created_by=created_by,
        updated_by=created_by,
    )
    batch = db.query(Batch).get(entry.batch_id)
    if batch is None:
        raise ValueError("Invalid batch_id provided")
    batch.quantity -= entry.quantity

    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    return db_entry

def get_dispatch_entry(db: Session, dispatch_id: int) -> Optional[DispatchEntry]:
    return db.query(DispatchEntry).filter(DispatchEntry.id == dispatch_id).first()

def get_all_dispatch_entries(db: Session, skip: int = 0, limit: int = 100) -> List[DispatchEntry]:
    return db.query(DispatchEntry).offset(skip).limit(limit).all()

def update_dispatch_entry(
    db: Session,
    dispatch_id: int,
    entry_update: DispatchEntryUpdate,
    updated_by: Optional[str] = None
) -> Optional[DispatchEntry]:
    db_entry = get_dispatch_entry(db, dispatch_id)
    if not db_entry:
        return None
    for key, val in entry_update.dict(exclude_unset=True).items():
        setattr(db_entry, key, val)
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
