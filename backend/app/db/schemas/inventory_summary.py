from pydantic import BaseModel


class InventorySummaryRead(BaseModel):
    item_id: int
    name: str
    unit: str
    ledger_qty: float
    state_qty: float = 0.0
    status: str = "HEALTHY"
    severity: str = "NONE"
    signals: list[str] = []

    class Config:
        from_attributes = True


class ReconciliationItem(BaseModel):
    item_id: int
    item_name: str
    state_qty: float
    ledger_qty: float
    drift: float
    status: str  # HEALTHY | DRIFT
    severity: str  # NONE | MINOR | MAJOR | CRITICAL


class ReconciliationBatch(BaseModel):
    batch_id: int
    qty: float
    received_at: str


class ReconciliationTxn(BaseModel):
    type: str
    qty: float
    ref: str
    created_at: str


class ReconciliationDetail(BaseModel):
    item: InventorySummaryRead
    state_qty: float
    ledger_qty: float
    drift: float
    severity: str
    recent_transactions: list[ReconciliationTxn]
    batch_snapshot: list[ReconciliationBatch]


class InventorySignalResponse(BaseModel):
    available_stock: float
    avg_daily_outflow: float
    out_last_7d: float
    out_prev_7d: float
    signals: list[str]
