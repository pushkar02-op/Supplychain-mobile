"""
Admin Forecasting API - Phase 9

Read-only API for forecasting summaries.
Admin-only authorization.
"""

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.schemas.admin_read_models import (
    ForecastSummaryRead,
    ForecastSummaryResponse,
)
from app.db.session import get_db
from app.services.forecasting import (
    get_all_forecast_summaries,
    get_forecast_summary,
    refresh_all_forecasts,
)
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter(prefix="/admin/forecasting", tags=["Admin Forecasting"])


@router.get(
    "/summary",
    response_model=ForecastSummaryResponse,
    dependencies=[Depends(require_role(Role.OWNER))],
)
def get_forecasting_summary(db: Session = Depends(get_db)):
    """
    Get forecast summary for all items.

    Returns per item:
    - ledger_qty
    - avg_daily_outflow
    - days_to_zero
    - projected_stockout_date
    - signal (STABLE/WATCH/REORDER_SOON/CRITICAL)
    """
    summaries = get_all_forecast_summaries(db)
    return {"items": summaries, "count": len(summaries)}


@router.get(
    "/summary/{item_id}",
    response_model=ForecastSummaryRead,
    dependencies=[Depends(require_role(Role.OWNER))],
)
def get_item_forecast(item_id: int, db: Session = Depends(get_db)):
    """
    Get forecast summary for a specific item.
    """
    summary = get_forecast_summary(db, item_id)
    if not summary:
        raise AppException(
            detail="Forecast not found for item",
            status_code=404,
            rule_id=None,
            metadata={},
        )
    return summary


@router.post("/refresh", dependencies=[Depends(require_role(Role.OWNER))])
def refresh_forecasts(db: Session = Depends(get_db)):
    """
    Refresh all forecasts.

    Idempotent: Can be called multiple times safely.
    """
    results = refresh_all_forecasts(db)
    return {
        "status": "refreshed",
        "items_processed": len(results),
        "results": results[:10],  # Limit response size
    }
