from fastapi import HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from app.db.models.order import Order
from app.db.schemas.order import OrderCreate, OrderUpdate
from datetime import date, datetime
from app.db.models.invoice import Invoice


def get_distinct_mart_names(db: Session) -> List[str]:
    results = db.query(Invoice.mart_name).distinct().all()
    return [row[0] for row in results if row[0]] 

def create_order(db: Session, entry: OrderCreate, created_by: Optional[str] = None) -> Order:
    existing = db.query(Order).filter_by(
        item_id=entry.item_id,
        order_date=entry.order_date,
        mart_name=entry.mart_name
    ).first()

    if existing:
        raise HTTPException(
        status_code=400,
        detail={
        "error": "Duplicate Order",
        "message": "An order already exists for this item, mart, and date."
    }
    )
    db_entry = Order(
        **entry.dict(),
        created_by=created_by,
        updated_by=created_by,
    )
    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    return db_entry

def get_order(db: Session, order_id: int) -> Optional[Order]:
    return db.query(Order).filter(Order.id == order_id).first()

def get_orders(
    db: Session,
    order_date: Optional[date] = None,
    mart_name: Optional[str] = None
) -> List[Order]:
    query = db.query(Order)
    if order_date:
        query = query.filter(Order.order_date == order_date)
    if mart_name:
        query = query.filter(Order.mart_name == mart_name)
    return query.order_by(Order.created_at.desc()).all()

def update_order(db: Session, order_id: int, entry_update: OrderUpdate, updated_by: Optional[str] = None) -> Optional[Order]:
    db_entry = get_order(db, order_id)
    if not db_entry:
        return None
    
    original_quantity = db_entry.quantity_ordered
    original_status = db_entry.status
    quantity_dispatched = db_entry.quantity_dispatched or 0
    
    for key, value in entry_update.dict(exclude_unset=True).items():
        setattr(db_entry, key, value)
        
    print(original_quantity)
    print(quantity_dispatched)
    print(original_status)
    
    # Auto status adjustment logic
    if db_entry.quantity_ordered <= quantity_dispatched:
        db_entry.status = "Completed"
    else:
        db_entry.status = "Partially Completed"


    db_entry.updated_by = updated_by
    db_entry.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_entry)
    return db_entry

def delete_order(db: Session, order_id: int) -> bool:
    db_entry = get_order(db, order_id)
    if not db_entry:
        return False
    db.delete(db_entry)
    db.commit()
    return True
