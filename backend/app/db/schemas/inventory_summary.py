from decimal import Decimal

from app.db.schemas.base import SchemaModel


class InventorySummaryRead(SchemaModel):
    item_id: int
    name: str
    unit: str
    ledger_qty: Decimal
    state_qty: Decimal = Decimal("0")
    status: str = "HEALTHY"
    severity: str = "NONE"
    signals: list[str] = []

    class Config:
        from_attributes = True


class ReconciliationItem(SchemaModel):
    item_id: int
    item_name: str
    state_qty: Decimal
    ledger_qty: Decimal
    drift: Decimal
    status: str  # HEALTHY | DRIFT
    severity: str  # NONE | MINOR | MAJOR | CRITICAL


class ReconciliationBatch(SchemaModel):
    batch_id: int
    qty: Decimal
    received_at: str


class ReconciliationTxn(SchemaModel):
    type: str
    qty: Decimal
    ref: str
    created_at: str


class ReconciliationDetail(SchemaModel):
    item: InventorySummaryRead
    state_qty: Decimal
    ledger_qty: Decimal
    drift: Decimal
    severity: str
    recent_transactions: list[ReconciliationTxn]
    batch_snapshot: list[ReconciliationBatch]


class InventorySignalResponse(SchemaModel):
    available_stock: Decimal
    avg_daily_outflow: Decimal
    out_last_7d: Decimal
    out_prev_7d: Decimal
    signals: list[str]
