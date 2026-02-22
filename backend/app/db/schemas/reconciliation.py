from datetime import datetime
from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel


class ReconciliationRecordResolve(SchemaModel):
    record_id: int
    adjustment_qty: Decimal
    apply_to_batch: bool = True


class ReconciliationRecordRead(SchemaModel):
    id: int
    batch_id: int
    observed_ledger_qty: Decimal
    observed_state_qty: Decimal
    drift_amount: Decimal
    status: str
    detected_at: datetime
    resolution_txn_id: Optional[int] = None
    resolved_at: Optional[datetime] = None
    resolved_by: Optional[int] = None

    class Config:
        from_attributes = True
