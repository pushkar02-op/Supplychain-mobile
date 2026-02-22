from datetime import datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel


class InventoryTxnCreate(SchemaModel):
    item_id: int
    batch_id: Optional[int]
    txn_type: str
    raw_qty: Decimal
    raw_unit: str
    base_qty: Decimal
    base_unit: str
    ref_type: Optional[str] = None
    ref_id: Optional[int] = None
    remarks: Optional[str] = None


class InventoryTxnRead(InventoryTxnCreate):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True
