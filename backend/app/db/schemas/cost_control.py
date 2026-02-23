from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel


class DailyCostUpsertRequest(SchemaModel):
    warehouse_id: Optional[int] = None
    date: date
    total_cost: Decimal
    notes: Optional[str] = None


class DailyCostRead(SchemaModel):
    id: int
    warehouse_id: int
    date: date
    total_cost: Decimal
    notes: Optional[str] = None
    created_by: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
