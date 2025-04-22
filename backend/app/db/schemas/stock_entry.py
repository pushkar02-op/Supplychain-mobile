from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel


class StockEntryBase(BaseModel):
    received_date: date
    source: Optional[str] = None  # Supplier or source name (optional)
    price_per_unit: float
    total_cost: float
    batch_id: int


class StockEntryCreate(StockEntryBase):
    pass

class StockEntryRead(StockEntryBase):
    id: int
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        orm_mode = True
        
class StockEntryUpdate(BaseModel):
    received_date: Optional[date] = None
    source: Optional[str] = None
    price_per_unit: Optional[float] = None
    total_cost: Optional[float] = None
    batch_id: Optional[int] = None


