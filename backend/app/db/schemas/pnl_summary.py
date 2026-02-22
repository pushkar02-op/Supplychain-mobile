from datetime import date
from decimal import Decimal

from app.db.schemas.base import SchemaModel


class PnlSummaryRead(SchemaModel):
    date: date
    total_purchase: Decimal
    total_sales: Decimal
    profit: Decimal

    class Config:
        from_attributes = True
