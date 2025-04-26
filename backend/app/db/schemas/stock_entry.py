from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel
from app.db.schemas.item import ItemRead


class StockEntryBase(BaseModel):
    item_id: int 
    received_date: date
    price_per_unit: float
    total_cost: float
    source: Optional[str] = None
    quantity: float  
    unit: str        



class StockEntryCreate(StockEntryBase):
    pass

class StockEntryRead(StockEntryBase):
    id: int
    item: ItemRead
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        orm_mode = True
        
class StockEntryUpdate(BaseModel):
    received_date: Optional[date] = None
    price_per_unit: Optional[float] = None
    total_cost: Optional[float] = None
    source: Optional[str] = None
    quantity: Optional[float] = None
    unit: Optional[str] = None