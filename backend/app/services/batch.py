from datetime import date, datetime
from typing import List, Optional
from sqlalchemy import and_, select
from sqlalchemy.orm import Session
from app.db.models import Batch
from app.db.schemas.batch import BatchCreate, BatchUpdate

def create_batch(db: Session, batch: BatchCreate, created_by: Optional[str] = None) -> Batch:
    today = date.today()

    # 👀 Check if batch already exists for the item today
    existing_batch = db.query(Batch).filter(
        and_(
            Batch.item_id == batch.item_id,
            Batch.created_at >= datetime.combine(today, datetime.min.time()),
            Batch.created_at <= datetime.combine(today, datetime.max.time())
        )
    ).first()

    if existing_batch:
        # ✅ Reuse the batch, just increase the quantity
        existing_batch.quantity += batch.quantity
        existing_batch.updated_by = created_by
        existing_batch.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(existing_batch)
        return existing_batch
    else:
        # ➕ Create new batch
        db_batch = Batch(
            **batch.dict(),
            created_by=created_by,
            updated_by=created_by,
        )
        db.add(db_batch)
        db.commit()
        db.refresh(db_batch)
        return db_batch

def get_batch(db: Session, batch_id: int):
    return db.query(Batch).filter(Batch.id == batch_id).first()

def get_all_batches(db: Session, skip: int = 0, limit: int = 100):
    return db.query(Batch).offset(skip).limit(limit).all()

def update_batch(db: Session, batch_id: int, entry_update: BatchUpdate, updated_by: int):
    db_batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if db_batch:
        if entry_update.received_at:
            db_batch.received_at = entry_update.received_at
        if entry_update.unit:
            db_batch.unit = entry_update.unit
        if entry_update.quantity:
            db_batch.quantity = entry_update.quantity
        if entry_update.item_id:
            db_batch.item_id = entry_update.item_id
        db_batch.updated_by = updated_by
        db.commit()
        db.refresh(db_batch)
    return db_batch

def delete_batch(db: Session, batch_id: int):
    db_batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if db_batch:
        db.delete(db_batch)
        db.commit()
        return True
    return False


def get_batches_by_item_with_quantity(db: Session, item_id: int) -> List[Batch]:
    return db.scalars(
        select(Batch).where(
            Batch.item_id == item_id,
            Batch.quantity > 0
        ).order_by(Batch.created_at)
    ).all()
