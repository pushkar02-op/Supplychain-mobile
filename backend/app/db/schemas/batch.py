from datetime import date, datetime
from pydantic import BaseModel
from typing import Optional


class BatchBase(BaseModel):
    received_at: date
    unit: str
    quantity: int
    item_id: int


class BatchCreate(BatchBase):
    pass


class BatchUpdate(BaseModel):
    received_at: Optional[date] = None
    unit: Optional[str] = None
    quantity: Optional[int] = None
    item_id: Optional[int] = None


class BatchRead(BatchBase):
    id: int
    item_name: Optional[str]
    expiry_date: Optional[date]
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True
