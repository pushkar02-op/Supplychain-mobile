from pydantic import BaseModel


class InventorySummaryRead(BaseModel):
    item_id: int
    name: str
    unit: str
    current_stock: float
    available_stock: float = 0.0
    signals: list[str] = []

    class Config:
        from_attributes = True


class ReconciliationItem(BaseModel):
    item_id: int
    item_name: str
    available_stock: float
    ledger_stock: float
    delta: float
    status: str  # HEALTHY | DRIFT
    severity: str  # MINOR | MAJOR | CRITICAL


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
    available_stock: float
    ledger_stock: float
    delta: float
    recent_transactions: list[ReconciliationTxn]
    batch_snapshot: list[ReconciliationBatch]


class InventorySignalResponse(BaseModel):
    available_stock: float
    avg_daily_outflow: float
    out_last_7d: float
    out_prev_7d: float
    signals: list[str]
