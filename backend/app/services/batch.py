from sqlalchemy.orm import Session
from app.db.models import Batch
from app.db.schemas.batch import BatchCreate, BatchUpdate

def create_batch(db: Session, entry: BatchCreate, created_by: int):
    db_batch = Batch(
        expiry_date=entry.expiry_date,
        unit=entry.unit,
        quantity=entry.quantity,
        item_id=entry.item_id,
        created_by=created_by
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
        if entry_update.expiry_date:
            db_batch.expiry_date = entry_update.expiry_date
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
