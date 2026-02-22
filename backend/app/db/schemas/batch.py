from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel


# Base schema for shared fields
class BatchBase(SchemaModel):
    item_id: int
    quantity: Decimal
    unit: str
    received_at: Optional[date] = None
    expiry_date: Optional[date] = None
    remarks: Optional[str] = None

    class Config:
        orm_mode = True  # Pydantic v1/v2 compatibility


# Schema for creation
class BatchCreate(BatchBase):
    pass


# Schema for update
class BatchUpdate(SchemaModel):
    quantity: Optional[Decimal] = None
    unit: Optional[str] = None
    received_at: Optional[date] = None
    expiry_date: Optional[date] = None
    remarks: Optional[str] = None

    class Config:
        orm_mode = True


# Response schema
class BatchRead(BatchBase):
    id: int
    item_name: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[str] = None
    updated_by: Optional[str] = None

    class Config:
        orm_mode = True
