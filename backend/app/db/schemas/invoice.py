from pydantic import BaseModel
from datetime import datetime, date
from typing import Optional


class InvoiceRead(BaseModel):
    id: int
    mart_name: str
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
