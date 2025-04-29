from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from app.services.order import get_distinct_mart_names

from app.db.schemas.order import OrderCreate, OrderRead, OrderUpdate
from app.services.order import create_order, get_order, get_orders, update_order, delete_order
from app.db.session import get_db

router = APIRouter(prefix="/orders", tags=["Orders"])

@router.post("/", response_model=OrderRead, status_code=status.HTTP_201_CREATED)
def create(entry: OrderCreate, db: Session = Depends(get_db)):
    return create_order(db=db, entry=entry, created_by="system")

@router.get("/", response_model=List[OrderRead])
def read_all(
    order_date: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    return get_orders(db=db, order_date=order_date)

@router.get("/mart-names", response_model=List[str])
def get_mart_names(db: Session = Depends(get_db)):
    return get_distinct_mart_names(db)

@router.get("/{order_id}", response_model=OrderRead)
def read_one(order_id: int, db: Session = Depends(get_db)):
    order = get_order(db=db, order_id=order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order

@router.put("/{order_id}", response_model=OrderRead)
def update(order_id: int, entry_update: OrderUpdate, db: Session = Depends(get_db)):
    updated = update_order(db=db, order_id=order_id, entry_update=entry_update, updated_by="system")
    if not updated:
        raise HTTPException(status_code=404, detail="Order not found")
    return updated

@router.delete("/{order_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(order_id: int, db: Session = Depends(get_db)):
    success = delete_order(db=db, order_id=order_id)
    if not success:
        raise HTTPException(status_code=404, detail="Order not found")
    return None
