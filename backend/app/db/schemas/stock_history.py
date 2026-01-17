from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel


class StockHistoryReceipt(BaseModel):
    id: int
    received_date: date
    quantity: float
    unit: str
    price_per_unit: float
    total_cost: float
    source: Optional[str] = None


class StockHistoryAdjustment(BaseModel):
    id: int
    quantity_delta: float
    unit: str
    reason: str
    created_at: datetime
    created_by: Optional[str] = None


class StockHistoryResponse(BaseModel):
    receipt: StockHistoryReceipt
    adjustments: List[StockHistoryAdjustment]
    is_voided: bool
    voided_at: Optional[datetime] = None
