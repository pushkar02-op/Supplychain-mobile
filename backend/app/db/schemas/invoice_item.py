from datetime import datetime
from pydantic import BaseModel
from typing import Optional

class InvoiceItemBase(BaseModel):
    hsn_code: Optional[str]
    item_code: Optional[str]
    item_name: str
    quantity: float
    uom: str
    price: float
    total: float
    invoice_date: datetime
    store_name: str

class InvoiceItemCreate(InvoiceItemBase):
    invoice_id: int

class InvoiceItemRead(InvoiceItemBase):
    id: int
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        orm_mode = True
