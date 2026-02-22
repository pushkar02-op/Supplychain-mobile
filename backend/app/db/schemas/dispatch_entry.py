from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel
from app.db.schemas.batch import BatchRead
from pydantic import Field


class DispatchEntryBase(SchemaModel):
    item_id: int
    batch_id: int
    mart_name: str
    dispatch_date: date
    quantity: Decimal
    unit: str
    remarks: Optional[str] = None
    order_id: Optional[int] = None


class DispatchEntryCreate(DispatchEntryBase):
    pass


class DispatchEntryUpdate(SchemaModel):
    mart_name: Optional[str] = None
    dispatch_date: Optional[date] = None
    quantity: Optional[Decimal] = None
    unit: Optional[str] = None


class DispatchEntryRead(DispatchEntryBase):
    id: int
    created_at: datetime = Field(..., description="ISO 8601 format")
    updated_at: datetime = Field(..., description="ISO 8601 format")
    created_by: Optional[str]
    updated_by: Optional[str]

    batch: BatchRead


# ========================
# Reversal Schemas
# ========================
class DispatchReversalCreate(SchemaModel):
    quantity: Optional[Decimal] = None  # None = full reversal
    reason: Optional[str] = None


class DispatchReversalRead(SchemaModel):
    id: int
    dispatch_entry_id: int
    quantity: Decimal
    reason: Optional[str]
    created_at: datetime
    created_by: Optional[str]

    class Config:
        orm_mode = True

        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }


class BatchDispatchInput(SchemaModel):
    batch_id: int
    quantity: Decimal


# Update the create schema
class DispatchEntryMultiCreate(SchemaModel):
    item_id: int
    mart_name: str
    dispatch_date: date
    unit: str
    remarks: Optional[str] = None
    order_id: Optional[int] = None
    batches: list[BatchDispatchInput]


class DispatchEntryCreated(SchemaModel):
    dispatch_id: int
    batch_id: int
    quantity: Decimal


class DispatchEntryNetRead(DispatchEntryRead):
    net_quantity: Decimal
    status: str  # 'Active', 'Partially Reversed', 'Fully Reversed'

    class Config:
        orm_mode = True
