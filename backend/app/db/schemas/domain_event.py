from datetime import datetime
from typing import Any, Dict

from pydantic import BaseModel, Field


class DomainEventBase(BaseModel):
    event_type: str
    aggregate_type: str
    aggregate_id: str
    payload: Dict[str, Any]
    occurred_at: datetime = Field(default_factory=datetime.utcnow)


class InventoryTxnCommitted(BaseModel):
    txn_id: int
    item_id: int
    batch_id: int
    qty: float
    unit: str
    txn_type: str


class ReconciliationResolved(BaseModel):
    record_id: int
    batch_id: int
    drift_resolved: float
    adjustment_txn_id: int


class DispatchCompleted(BaseModel):
    dispatch_id: int
    order_id: int | None
    item_id: int
    qty: float


class OrderFulfilled(BaseModel):
    order_id: int
    item_id: int
    mart_id: int
    total_qty: float
