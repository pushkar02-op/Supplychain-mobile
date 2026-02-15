"""
Forecasting Service - Phase 9

Deterministic, explainable forecasting based on ledger truth and Phase 8 projections.
All forecasts are READ-ONLY with respect to core domain models.
"""

import logging
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import List, Optional

from app.db.models.inventory_flow_daily import InventoryFlowDaily
from app.db.models.item import Item
from app.db.models.item_burn_rate import ItemBurnRate
from app.db.models.stock_depletion_forecast import StockDepletionForecast
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


# Signal thresholds (days to stockout)
SIGNAL_CRITICAL = 3
SIGNAL_REORDER_SOON = 7
SIGNAL_WATCH = 14


def classify_signal(days_to_zero: Optional[float]) -> str:
    """
    Classify stockout risk based on days_to_zero.

    Rules (deterministic):
    - CRITICAL → stockout < 3 days
    - REORDER_SOON → stockout < 7 days
    - WATCH → stockout < 14 days
    - STABLE → otherwise (including None/infinite)
    """
    if days_to_zero is None:
        return "STABLE"

    if days_to_zero < SIGNAL_CRITICAL:
        return "CRITICAL"
    elif days_to_zero < SIGNAL_REORDER_SOON:
        return "REORDER_SOON"
    elif days_to_zero < SIGNAL_WATCH:
        return "WATCH"
    else:
        return "STABLE"


def compute_burn_rate(db: Session, item_id: int) -> dict:
    """
    Compute average daily outflow for an item over 7d, 14d, 30d windows.

    Source: InventoryFlowDaily (Phase 8 projection)

    Returns:
        {
            "avg_daily_outflow_7d": float,
            "avg_daily_outflow_14d": float,
            "avg_daily_outflow_30d": float,
        }
    """
    today = date.today()

    def avg_outflow_for_window(days: int) -> Decimal:
        start_date = today - timedelta(days=days)
        result = (
            db.query(func.coalesce(func.sum(InventoryFlowDaily.out_qty), 0))
            .filter(
                InventoryFlowDaily.item_id == item_id,
                InventoryFlowDaily.date >= start_date,
                InventoryFlowDaily.date <= today,
            )
            .scalar()
        )
        total_out = Decimal(str(result or 0))
        return total_out / Decimal(str(days)) if days > 0 else Decimal("0")

    return {
        "avg_daily_outflow_7d": avg_outflow_for_window(7),
        "avg_daily_outflow_14d": avg_outflow_for_window(14),
        "avg_daily_outflow_30d": avg_outflow_for_window(30),
    }


def get_current_ledger_qty(db: Session, item_id: int) -> Decimal:
    """
    Get current ledger quantity for an item.

    Source: batch_ledger_balance_view or direct calculation
    """
    # Note: batch_ledger_balance_view is batch-centric; for item aggregation
    # we rely on the Batch table snapshot which is maintained by transaction services.

    # Fallback: Calculate from batches directly
    from app.db.models.batch import Batch

    result = (
        db.query(func.coalesce(func.sum(Batch.quantity), 0))
        .filter(Batch.item_id == item_id)
        .scalar()
    )
    return Decimal(str(result or 0))


def compute_depletion_forecast(
    db: Session, item_id: int, avg_daily_outflow: float
) -> dict:
    """
    Compute stockout forecast for an item.

    Formula:
        days_to_zero = ledger_qty / avg_daily_outflow

    Guards:
        - If avg_daily_outflow = 0 → days_to_zero = None (STABLE)
        - No division by zero
    """
    ledger_qty = get_current_ledger_qty(db, item_id)
    avg_daily_outflow = Decimal(str(avg_daily_outflow))

    if avg_daily_outflow <= 0:
        # No outflow = stable, no stockout projected
        return {
            "current_ledger_qty": ledger_qty,
            "avg_daily_outflow": 0.0,
            "days_to_zero": None,
            "projected_stockout_date": None,
            "confidence_window_days": 7,
        }

    days_to_zero = ledger_qty / avg_daily_outflow
    stockout_date = date.today() + timedelta(days=int(days_to_zero))

    return {
        "current_ledger_qty": ledger_qty,
        "avg_daily_outflow": avg_daily_outflow,
        "days_to_zero": days_to_zero,
        "projected_stockout_date": stockout_date,
        "confidence_window_days": 7,  # Fixed window for simplicity
    }


def refresh_forecast_for_item(db: Session, item_id: int) -> dict:
    """
    Refresh all forecast data for a single item.

    Idempotent: Overwrites existing records.
    """
    # 1. Compute burn rate
    burn_data = compute_burn_rate(db, item_id)

    # 2. Persist burn rate (upsert)
    burn_rate = db.query(ItemBurnRate).filter_by(item_id=item_id).first()
    if not burn_rate:
        burn_rate = ItemBurnRate(item_id=item_id)
        db.add(burn_rate)

    burn_rate.avg_daily_outflow_7d = burn_data["avg_daily_outflow_7d"]
    burn_rate.avg_daily_outflow_14d = burn_data["avg_daily_outflow_14d"]
    burn_rate.avg_daily_outflow_30d = burn_data["avg_daily_outflow_30d"]
    burn_rate.calculated_at = datetime.utcnow()

    # 3. Compute depletion forecast (using 7d average)
    depletion_data = compute_depletion_forecast(
        db, item_id, burn_data["avg_daily_outflow_7d"]
    )

    # 4. Persist depletion forecast (upsert)
    forecast = db.query(StockDepletionForecast).filter_by(item_id=item_id).first()
    if not forecast:
        forecast = StockDepletionForecast(item_id=item_id)
        db.add(forecast)

    forecast.current_ledger_qty = depletion_data["current_ledger_qty"]
    forecast.avg_daily_outflow = depletion_data["avg_daily_outflow"]
    forecast.days_to_zero = depletion_data["days_to_zero"]
    forecast.projected_stockout_date = depletion_data["projected_stockout_date"]
    forecast.confidence_window_days = depletion_data["confidence_window_days"]

    # 5. Compute and persist signal
    signal = classify_signal(depletion_data["days_to_zero"])
    forecast.signal = signal

    forecast.calculated_at = datetime.utcnow()

    db.commit()

    return {
        "item_id": item_id,
        "burn_rate": burn_data,
        "depletion": depletion_data,
        "signal": signal,
    }


def refresh_all_forecasts(db: Session) -> List[dict]:
    """
    Refresh forecasts for all items.

    Returns list of forecast summaries.
    """
    items = db.query(Item.id).all()
    results = []

    for (item_id,) in items:
        try:
            result = refresh_forecast_for_item(db, item_id)
            results.append(result)
        except Exception as e:
            logger.error(f"Failed to refresh forecast for item {item_id}: {e}")
            results.append({"item_id": item_id, "error": str(e)})

    return results


def get_forecast_summary(db: Session, item_id: int) -> Optional[dict]:
    """
    Get forecast summary for a single item.

    Returns computed signal (not stored).
    """
    forecast = db.query(StockDepletionForecast).filter_by(item_id=item_id).first()
    burn_rate = db.query(ItemBurnRate).filter_by(item_id=item_id).first()

    if not forecast:
        return None

    return {
        "item_id": item_id,
        "current_ledger_qty": forecast.current_ledger_qty,
        "avg_daily_outflow": forecast.avg_daily_outflow,
        "days_to_zero": forecast.days_to_zero,
        "projected_stockout_date": (
            str(forecast.projected_stockout_date)
            if forecast.projected_stockout_date
            else None
        ),
        "signal": classify_signal(forecast.days_to_zero),
        "calculated_at": str(forecast.calculated_at),
        "last_refreshed": str(forecast.calculated_at),
        "burn_rates": {
            "7d": burn_rate.avg_daily_outflow_7d if burn_rate else None,
            "14d": burn_rate.avg_daily_outflow_14d if burn_rate else None,
            "30d": burn_rate.avg_daily_outflow_30d if burn_rate else None,
        },
    }


def get_all_forecast_summaries(db: Session) -> List[dict]:
    """
    Get forecast summaries for all items with forecasts.
    """
    forecasts = db.query(StockDepletionForecast).all()
    return [get_forecast_summary(db, f.item_id) for f in forecasts]
