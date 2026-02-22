from datetime import datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel


class MartBillItemBase(SchemaModel):
    hsn_code: Optional[str]
    item_code: Optional[str]
    item_name: str
    quantity: Decimal
    uom: str
    price: Decimal
    total: Decimal
    invoice_date: datetime
    store_name: str


class MartBillItemCreate(MartBillItemBase):
    invoice_id: int


class MartBillItemUpdate(SchemaModel):
    quantity: Optional[Decimal] = None
    price: Optional[Decimal] = None
    total: Optional[Decimal] = None

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


class MartBillItemSummary(SchemaModel):
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
