from datetime import date, datetime
from pydantic import BaseModel, Field
from typing import Optional

class DispatchEntryBase(BaseModel):
    batch_id: int
    mart_name: str
    dispatch_date: date
    quantity: int
    unit: str
    sell_price_per_unit: float
    total_revenue: float

class DispatchEntryCreate(DispatchEntryBase):
    pass

class DispatchEntryUpdate(BaseModel):
    mart_name: Optional[str] = None
    dispatch_date: Optional[date] = None
    quantity: Optional[int] = None
    unit: Optional[str] = None
    sell_price_per_unit: Optional[float] = None
    total_revenue: Optional[float] = None

class DispatchEntryRead(DispatchEntryBase):
    id: int
    created_at: datetime = Field(..., description="ISO 8601 format")
    updated_at: datetime = Field(..., description="ISO 8601 format")
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }
