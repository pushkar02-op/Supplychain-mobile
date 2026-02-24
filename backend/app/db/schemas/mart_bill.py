from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel


class MartBillRead(SchemaModel):
    id: int
    mart_id: int
    warehouse_id: int
    mart_name: Optional[str] = None
    invoice_date: date
    total_amount: Decimal
    file_path: str
    status: str
    locked_at: Optional[datetime]
    locked_by: Optional[str]
    remarks: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MartBillUpdate(SchemaModel):
    remarks: Optional[str]
