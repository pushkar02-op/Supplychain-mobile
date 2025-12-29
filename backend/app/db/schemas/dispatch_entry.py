from datetime import date, datetime
from typing import Optional

from app.db.schemas.batch import BatchRead
from pydantic import BaseModel, Field


class DispatchEntryBase(BaseModel):
    item_id: int
    batch_id: int
    mart_name: str
    dispatch_date: date
    quantity: float
    unit: str
    remarks: Optional[str] = None


class DispatchEntryCreate(DispatchEntryBase):
    pass


class DispatchEntryUpdate(BaseModel):
    mart_name: Optional[str] = None
    dispatch_date: Optional[date] = None
    quantity: Optional[float] = None
    unit: Optional[str] = None


class DispatchEntryRead(DispatchEntryBase):
    id: int
    created_at: datetime = Field(..., description="ISO 8601 format")
    updated_at: datetime = Field(..., description="ISO 8601 format")
    created_by: Optional[str]
    updated_by: Optional[str]

    batch: BatchRead

    class Config:
        orm_mode = True
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }


class BatchDispatchInput(BaseModel):
    batch_id: int
    quantity: float


# Update the create schema
class DispatchEntryMultiCreate(BaseModel):
    item_id: int
    mart_name: str
    dispatch_date: date
    unit: str
    remarks: Optional[str] = None
    batches: list[BatchDispatchInput]


class DispatchEntryCreated(BaseModel):
    dispatch_id: int
    batch_id: int
    quantity: float
