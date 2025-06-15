from datetime import datetime
from pydantic import BaseModel
from typing import Optional


class InventoryTxnCreate(BaseModel):
    item_id: int
    batch_id: Optional[int]
    txn_type: str
    raw_qty: float
    raw_unit: str
    base_qty: float
    base_unit: str
    ref_type: Optional[str]
    ref_id: Optional[int]
    remarks: Optional[str]


class InventoryTxnRead(InventoryTxnCreate):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True
