from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class MartBillRead(BaseModel):
    id: int
    mart_id: int
    mart_name: Optional[str] = None
    invoice_date: date
    total_amount: float
    file_path: str
    status: str
    locked_at: Optional[datetime]
    locked_by: Optional[str]
    remarks: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MartBillUpdate(BaseModel):
    remarks: Optional[str]
