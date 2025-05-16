from sqlalchemy import select
from sqlalchemy.orm import Session
from app.db.models import Item
from app.db.schemas.item import ItemCreate, ItemUpdate
from app.db.models.batch import Batch

def create_item(db: Session, entry: ItemCreate, created_by: int):
    db_item = Item(name=entry.name, default_unit=entry.default_unit, created_by=created_by)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

def get_item(db: Session, item_id: int):
    return db.query(Item).filter(Item.id == item_id).first()

def get_all_items(db: Session, skip: int = 0, limit: int = 100):
    return db.query(Item).offset(skip).limit(limit).all()

def get_items_with_available_batches(db: Session) -> list[Item]:
    subquery = (
        select(Batch.item_id)
        .where(Batch.quantity > 0)
        .distinct()
        .subquery()
    )

    return db.query(Item).filter(Item.id.in_(select(subquery.c.item_id))).all()

def update_item(db: Session, item_id: int, entry_update: ItemUpdate, updated_by: int):
    db_item = db.query(Item).filter(Item.id == item_id).first()
    if db_item:
        if entry_update.name:
            db_item.name = entry_update.name
        if entry_update.default_unit:
            db_item.default_unit = entry_update.default_unit
        db_item.updated_by = updated_by
        db.commit()
        db.refresh(db_item)
    return db_item

def delete_item(db: Session, item_id: int):
    db_item = db.query(Item).filter(Item.id == item_id).first()
    if db_item:
        db.delete(db_item)
        db.commit()
        return True
    return False
