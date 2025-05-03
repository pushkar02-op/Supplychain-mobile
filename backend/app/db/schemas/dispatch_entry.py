from datetime import date, datetime
from pydantic import BaseModel, Field
from typing import Optional
from app.db.schemas.batch import BatchRead

class DispatchEntryBase(BaseModel):
    batch_id: int
    mart_name: str
    dispatch_date: date
    quantity: int
    unit: str


class DispatchEntryCreate(DispatchEntryBase):
    pass

class DispatchEntryUpdate(BaseModel):
    mart_name: Optional[str] = None
    dispatch_date: Optional[date] = None
    quantity: Optional[int] = None
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
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }
class BatchDispatchInput(BaseModel):
    batch_id: int
    quantity: int

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
    quantity: int