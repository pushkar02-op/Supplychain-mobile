from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class InvoiceRead(BaseModel):
    id: int
    mart_id: int
    mart_name: Optional[str] = None
    invoice_date: date
    total_amount: float
    file_path: str
    is_verified: bool
    remarks: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class InvoiceUpdate(BaseModel):
    is_verified: Optional[bool]
    remarks: Optional[str]
