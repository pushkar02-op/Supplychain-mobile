from datetime import date
from decimal import Decimal

from app.db.schemas.base import SchemaModel


class FinancialKpiResponse(SchemaModel):
    warehouse_id: int
    start_date: date
    end_date: date
    revenue: Decimal
    cogs: Decimal
    gross_margin: Decimal
    labour_cost: Decimal
    transport_cost: Decimal
    net_margin: Decimal
    total_dispatched_units: Decimal
    cost_per_unit: Decimal
    revenue_per_unit: Decimal


class OperationalKpiResponse(SchemaModel):
    warehouse_id: int
    start_date: date
    end_date: date
    total_inward_qty: Decimal
    total_dispatch_qty: Decimal
    rejection_qty: Decimal
    reversal_count: int
    order_count: int
    avg_fulfillment_time: Decimal
    active_batch_count: int
    zero_stock_items_count: int
