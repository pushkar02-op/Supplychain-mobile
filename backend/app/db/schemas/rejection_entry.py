from datetime import date, datetime
from pydantic import BaseModel, Field
from typing import Optional
from app.db.schemas.batch import BatchRead

class RejectionEntryBase(BaseModel):
    batch_id: int
    quantity: int
    reason: Optional[str]
    rejection_date: date
    rejected_by: Optional[str]

class RejectionEntryCreate(RejectionEntryBase):
    pass

class RejectionEntryRead(RejectionEntryBase):
    id: int
    unit: str
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
