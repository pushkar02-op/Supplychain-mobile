from datetime import date, datetime
from pydantic import BaseModel
from typing import Optional
from app.db.schemas.item import ItemRead

class OrderBase(BaseModel):
    item_id: int
    mart_name: str
    order_date: date
    quantity_ordered: float

class OrderCreate(OrderBase):
    pass

class OrderUpdate(BaseModel):
    quantity_ordered: Optional[float] = None
    mart_name: Optional[str] = None

class OrderRead(OrderBase):
    id: int
    item: ItemRead
    quantity_dispatched: float
    status: str
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        orm_mode = True
