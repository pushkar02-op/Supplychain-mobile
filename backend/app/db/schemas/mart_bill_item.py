from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class MartBillItemBase(BaseModel):
    hsn_code: Optional[str]
    item_code: Optional[str]
    item_name: str
    quantity: float
    uom: str
    price: float
    total: float
    invoice_date: datetime
    store_name: str


class MartBillItemCreate(MartBillItemBase):
    invoice_id: int


class MartBillItemUpdate(BaseModel):
    quantity: Optional[float] = None
    price: Optional[float] = None
    total: Optional[float] = None

    class Config:
        from_attributes = True


class MartBillItemRead(MartBillItemBase):
    id: int
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        from_attributes = True


class MartBillItemSummary(BaseModel):
    item_id: int
    item_code: str
    item_name: str
    uom: str

    class Config:
        from_attributes = True


class UnresolvedMartBillItemRead(MartBillItemBase):
    id: int
    invoice_id: int
    created_at: datetime

    class Config:
        from_attributes = True


# Was missing in previous view? Adding it if found by grep, otherwise I'll add a placeholder or copy if I find it.
# Assuming it might be missing or in another file. I will check grep result before finalizing this file if needed.
# Actually, I'll write what I have, and append if I find the missing class.
