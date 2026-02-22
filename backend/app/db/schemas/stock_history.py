from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional

from app.db.schemas.base import SchemaModel


class StockHistoryReceipt(SchemaModel):
    id: int
    received_date: date
    quantity: Decimal
    unit: str
    price_per_unit: Decimal
    total_cost: Decimal
    source: Optional[str] = None


class StockHistoryAdjustment(SchemaModel):
    id: int
    quantity_delta: Decimal
    unit: str
    reason: str
    created_at: datetime
    created_by: Optional[str] = None


class StockHistoryResponse(SchemaModel):
    receipt: StockHistoryReceipt
    adjustments: List[StockHistoryAdjustment]
    is_voided: bool
    voided_at: Optional[datetime] = None
