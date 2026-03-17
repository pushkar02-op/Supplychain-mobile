from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from app.db.schemas.base import SchemaModel
from pydantic import BaseModel, field_serializer


class ReconciliationRecordResolve(SchemaModel):
    record_id: int
    adjustment_qty: Decimal
    apply_to_batch: bool = True


class ReconciliationRecordRead(SchemaModel):
    id: int
    batch_id: int
    warehouse_id: int
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


class DriftReportItem(BaseModel):
    batch_id: int
    item_id: int
    warehouse_id: int
    state_qty: Decimal
    ledger_qty: Decimal
    drift: Decimal
    item_name: str | None = None
    severity: str | None = None

    @field_serializer("state_qty", "ledger_qty", "drift")
    def serialize_decimal(self, value: Decimal) -> float:
        return float(value)


class DriftResolutionRequest(SchemaModel):
    batch_id: int
    resolution_type: Literal["state_to_ledger", "ledger_to_state"]
    notes: str | None = None


class DriftResolutionResult(SchemaModel):
    success: bool
    adjustment_txn_id: int
