from __future__ import annotations

from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from app.core.decimal_utils import enforce_decimal
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.dispatch_reversal import DispatchReversal
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.labour_cost_daily import LabourCostDaily
from app.db.models.mart_bill import MartBill
from app.db.models.order import Order
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.stock_entry import StockEntry
from app.db.models.transport_cost_daily import TransportCostDaily
from sqlalchemy import and_, func
from sqlalchemy.orm import Session


def _dec(value: object) -> Decimal:
    return enforce_decimal(value)


def _money(value: object) -> Decimal:
    return _dec(value).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)


def get_financial_kpi(
    db: Session,
    warehouse_id: int,
    start_date: date,
    end_date: date,
) -> dict[str, Decimal | int | date]:
    revenue = _money(
        db.query(func.coalesce(func.sum(MartBill.total_amount), 0))
        .filter(
            MartBill.warehouse_id == warehouse_id,
            MartBill.invoice_date >= start_date,
            MartBill.invoice_date <= end_date,
        )
        .scalar()
    )

    cogs = _money(
        db.query(
            func.coalesce(
                func.sum(
                    func.abs(InventoryTxn.base_qty)
                    * func.coalesce(StockEntry.price_per_unit, 0)
                ),
                0,
            )
        )
        .join(StockEntry, StockEntry.batch_id == InventoryTxn.batch_id)
        .join(
            DispatchEntry,
            and_(
                InventoryTxn.ref_type == "dispatch_entry",
                InventoryTxn.ref_id == DispatchEntry.id,
            ),
        )
        .filter(
            InventoryTxn.warehouse_id == warehouse_id,
            StockEntry.warehouse_id == warehouse_id,
            DispatchEntry.warehouse_id == warehouse_id,
            InventoryTxn.ref_type == "dispatch_entry",
            InventoryTxn.txn_type.in_(["OUT", "DISPATCH"]),
            DispatchEntry.dispatch_date.between(start_date, end_date),
        )
        .scalar()
    )

    labour_cost = _money(
        db.query(func.coalesce(func.sum(LabourCostDaily.total_cost), 0))
        .filter(
            LabourCostDaily.warehouse_id == warehouse_id,
            LabourCostDaily.date >= start_date,
            LabourCostDaily.date <= end_date,
        )
        .scalar()
    )

    transport_cost = _money(
        db.query(func.coalesce(func.sum(TransportCostDaily.total_cost), 0))
        .filter(
            TransportCostDaily.warehouse_id == warehouse_id,
            TransportCostDaily.date >= start_date,
            TransportCostDaily.date <= end_date,
        )
        .scalar()
    )

    total_dispatched_units = _dec(
        db.query(func.coalesce(func.sum(DispatchEntry.quantity), 0))
        .filter(
            DispatchEntry.warehouse_id == warehouse_id,
            DispatchEntry.dispatch_date >= start_date,
            DispatchEntry.dispatch_date <= end_date,
        )
        .scalar()
    ).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)

    gross_margin = _money(revenue - cogs)
    net_margin = _money(gross_margin - labour_cost - transport_cost)

    if total_dispatched_units > 0:
        cost_per_unit = _money(
            (cogs + labour_cost + transport_cost) / total_dispatched_units
        )
        revenue_per_unit = _money(revenue / total_dispatched_units)
    else:
        cost_per_unit = Decimal("0.000000")
        revenue_per_unit = Decimal("0.000000")

    return {
        "warehouse_id": warehouse_id,
        "start_date": start_date,
        "end_date": end_date,
        "revenue": revenue,
        "cogs": cogs,
        "gross_margin": gross_margin,
        "labour_cost": labour_cost,
        "transport_cost": transport_cost,
        "net_margin": net_margin,
        "total_dispatched_units": total_dispatched_units,
        "cost_per_unit": cost_per_unit,
        "revenue_per_unit": revenue_per_unit,
    }


def get_operational_kpi(
    db: Session,
    warehouse_id: int,
    start_date: date,
    end_date: date,
) -> dict[str, Decimal | int | date]:
    total_inward_qty = _dec(
        db.query(func.coalesce(func.sum(StockEntry.quantity), 0))
        .filter(
            StockEntry.warehouse_id == warehouse_id,
            StockEntry.received_date >= start_date,
            StockEntry.received_date <= end_date,
            StockEntry.is_active,
        )
        .scalar()
    ).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)

    total_dispatch_qty = _dec(
        db.query(func.coalesce(func.sum(DispatchEntry.quantity), 0))
        .filter(
            DispatchEntry.warehouse_id == warehouse_id,
            DispatchEntry.dispatch_date >= start_date,
            DispatchEntry.dispatch_date <= end_date,
        )
        .scalar()
    ).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)

    rejection_qty = _dec(
        db.query(func.coalesce(func.sum(RejectionEntry.quantity), 0))
        .filter(
            RejectionEntry.warehouse_id == warehouse_id,
            RejectionEntry.rejection_date >= start_date,
            RejectionEntry.rejection_date <= end_date,
            RejectionEntry.is_active,
        )
        .scalar()
    ).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)

    reversal_count = int(
        db.query(func.count(DispatchReversal.id))
        .join(DispatchEntry, DispatchEntry.id == DispatchReversal.dispatch_entry_id)
        .filter(
            DispatchEntry.warehouse_id == warehouse_id,
            func.date(DispatchReversal.created_at) >= start_date,
            func.date(DispatchReversal.created_at) <= end_date,
        )
        .scalar()
        or 0
    )

    order_count = int(
        db.query(func.count(Order.id))
        .filter(
            Order.warehouse_id == warehouse_id,
            Order.order_date >= start_date,
            Order.order_date <= end_date,
        )
        .scalar()
        or 0
    )

    fulfillment_rows = (
        db.query(
            Order.id.label("order_id"),
            Order.order_date.label("order_date"),
            func.max(DispatchEntry.dispatch_date).label("last_dispatch_date"),
        )
        .join(DispatchEntry, DispatchEntry.order_id == Order.id)
        .filter(
            Order.warehouse_id == warehouse_id,
            DispatchEntry.warehouse_id == warehouse_id,
            DispatchEntry.dispatch_date >= start_date,
            DispatchEntry.dispatch_date <= end_date,
        )
        .group_by(Order.id, Order.order_date)
        .all()
    )
    if fulfillment_rows:
        total_days = sum(
            max(0, (row.last_dispatch_date - row.order_date).days)
            for row in fulfillment_rows
            if row.last_dispatch_date is not None
        )
        avg_fulfillment_time = (
            Decimal(total_days) / Decimal(len(fulfillment_rows))
        ).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)
    else:
        avg_fulfillment_time = Decimal("0.000")

    active_batch_count = int(
        db.query(func.count(Batch.id))
        .filter(Batch.warehouse_id == warehouse_id, Batch.quantity > 0)
        .scalar()
        or 0
    )

    item_totals_subquery = (
        db.query(
            Batch.item_id.label("item_id"),
            func.coalesce(func.sum(Batch.quantity), 0).label("total_qty"),
        )
        .filter(Batch.warehouse_id == warehouse_id)
        .group_by(Batch.item_id)
        .subquery()
    )

    zero_stock_items_count = int(
        db.query(func.count())
        .select_from(item_totals_subquery)
        .filter(item_totals_subquery.c.total_qty <= 0)
        .scalar()
        or 0
    )

    return {
        "warehouse_id": warehouse_id,
        "start_date": start_date,
        "end_date": end_date,
        "total_inward_qty": total_inward_qty,
        "total_dispatch_qty": total_dispatch_qty,
        "rejection_qty": rejection_qty,
        "reversal_count": reversal_count,
        "order_count": order_count,
        "avg_fulfillment_time": avg_fulfillment_time,
        "active_batch_count": active_batch_count,
        "zero_stock_items_count": zero_stock_items_count,
    }
