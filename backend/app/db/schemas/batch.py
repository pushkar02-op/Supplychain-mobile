from datetime import date
from pydantic import BaseModel
from typing import Optional


class BatchBase(BaseModel):
    expiry_date: date
    unit: str
    quantity: int
    item_id: int

class BatchCreate(BatchBase):
    pass

class BatchUpdate(BatchBase):
    expiry_date: date = None
    unit: Optional[str] = None
    quantity: Optional[int] = None
    item_id: Optional[int] = None

class BatchRead(BatchBase):
    id: int
    item_name: str

    class Config:
        orm_mode = True
