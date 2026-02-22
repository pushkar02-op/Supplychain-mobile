from datetime import datetime
from decimal import Decimal
from typing import Any, Dict

from app.db.schemas.base import SchemaModel
from pydantic import Field


class DomainEventBase(SchemaModel):
    event_type: str
    aggregate_type: str
    aggregate_id: str
    payload: Dict[str, Any]
    occurred_at: datetime = Field(default_factory=datetime.utcnow)


class InventoryTxnCommitted(SchemaModel):
    txn_id: int
    item_id: int
    batch_id: int
    qty: Decimal
    unit: str
    txn_type: str


class ReconciliationResolved(SchemaModel):
    record_id: int
    batch_id: int
    drift_resolved: Decimal
    adjustment_txn_id: int


class DispatchCompleted(SchemaModel):
    dispatch_id: int
    order_id: int | None
    item_id: int
    qty: Decimal


class OrderFulfilled(SchemaModel):
    order_id: int
    item_id: int
    mart_id: int
    total_qty: Decimal
