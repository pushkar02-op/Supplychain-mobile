from sqlalchemy.orm import Session
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.schemas.item_conversion_map import (
    ItemConversionCreate,
    ItemConversionUpdate,
)

def create_conversion(db: Session, data: ItemConversionCreate, created_by: str):
    conv = ItemConversionMap(**data.dict(), created_by=created_by, updated_by=created_by)
    db.add(conv)
    db.commit()
    db.refresh(conv)
    return conv

def get_all_conversions(db: Session):
    return db.query(ItemConversionMap).all()

def get_conversion(db: Session, conv_id: int):
    return db.query(ItemConversionMap).filter(ItemConversionMap.id == conv_id).first()

def update_conversion(db: Session, conv_id: int, data: ItemConversionUpdate, updated_by: str):
    conv = get_conversion(db, conv_id)
    if not conv:
        return None
    for field, value in data.dict(exclude_unset=True).items():
        setattr(conv, field, value)
    conv.updated_by = updated_by
    db.commit()
    db.refresh(conv)
    return conv

def delete_conversion(db: Session, conv_id: int):
    conv = get_conversion(db, conv_id)
    if not conv:
        return False
    db.delete(conv)
    db.commit()
    return True
