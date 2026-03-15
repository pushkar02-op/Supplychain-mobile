from decimal import Decimal

from pydantic import BaseModel, field_serializer


class WarehouseHealthSummary(BaseModel):
    status: str
    total_batches: int
    drifted_batches: int
    negative_stock_batches: int
    unhealthy_records: int


class MissingDefaultUomItem(BaseModel):
    id: int
    name: str
    item_code: str | None = None


class MissingDefaultUomResponse(BaseModel):
    count: int
    items: list[MissingDefaultUomItem]


class ForecastSummaryRead(BaseModel):
    item_id: int
    current_ledger_qty: Decimal
    avg_daily_outflow: Decimal | None = None
    days_to_zero: Decimal | None = None
    projected_stockout_date: str | None = None
    signal: str
    last_refreshed: str | None = None

    @field_serializer("current_ledger_qty", "avg_daily_outflow", "days_to_zero")
    def serialize_decimal(self, value: Decimal | None):
        return float(value) if value is not None else None


class ForecastSummaryResponse(BaseModel):
    items: list[ForecastSummaryRead]
    count: int
