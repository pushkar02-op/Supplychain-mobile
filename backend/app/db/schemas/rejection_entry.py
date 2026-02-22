from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel
from app.db.schemas.batch import BatchRead
from pydantic import Field


class RejectionEntryBase(SchemaModel):
    batch_id: int
    quantity: Decimal
    unit: str
    reason: Optional[str]
    rejection_date: date
    rejected_by: Optional[str]


class RejectionEntryCreate(RejectionEntryBase):
    pass


class RejectionEntryRead(RejectionEntryBase):
    id: int
    unit: str
    is_active: bool
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


class RejectionPagination(SchemaModel):
    items: list[RejectionEntryRead]
    skip: int
    limit: int
    total: int
    has_more: bool
