from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel
from app.db.schemas.item import ItemRead


class StockEntryBase(SchemaModel):
    item_id: int
    warehouse_id: Optional[int] = None
    source_bill_item_id: Optional[int] = None
    received_date: date
    price_per_unit: Decimal
    total_cost: Decimal
    source: Optional[str] = None
    quantity: Decimal
    unit: str


class StockEntryCreate(StockEntryBase):
    pass


class StockEntryRead(StockEntryBase):
    id: int
    batch_id: int
    warehouse_id: int
    batch_quantity: Optional[Decimal] = (
        None  # Current batch balance (may differ from receipt qty)
    )
    item: ItemRead
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        orm_mode = True
        from_attributes = True


class StockEntryUpdate(SchemaModel):
    received_date: Optional[date] = None
    price_per_unit: Optional[Decimal] = None
    total_cost: Optional[Decimal] = None
    source: Optional[str] = None
    quantity: Optional[Decimal] = None
    unit: Optional[str] = None
