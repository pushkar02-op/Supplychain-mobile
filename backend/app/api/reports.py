"""
API endpoints for reports.
Provides inventory and P&L summary reports.
"""

import logging
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from app.db.schemas.inventory_summary import InventorySummaryRead
from app.db.schemas.pnl_summary import PnlSummaryRead
from app.services.reports import (
    get_inventory_report,
    get_pnl_report,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get(
    "/inventory", response_model=List[InventorySummaryRead], summary="Inventory report"
)
def inventory(
    item_id: Optional[int] = Query(None, description="Filter by item ID"),
    db: Session = Depends(get_db),
) -> List[InventorySummaryRead]:
    """
    Retrieve inventory summary report.

    Args:
        item_id (Optional[int]): Filter by item ID.
        db (Session): Database session dependency.

    Returns:
        List[InventorySummaryRead]: Inventory summary data.
    """
    logger.info(f"Fetching inventory report for item_id={item_id}")
    return get_inventory_report(db=db, item_id=item_id)


@router.get("/pnl", response_model=List[PnlSummaryRead], summary="P&L report")
def pnl(
    start: Optional[str] = Query(None, description="Start date YYYY-MM-DD"),
    end: Optional[str] = Query(None, description="End date YYYY-MM-DD"),
    db: Session = Depends(get_db),
) -> List[PnlSummaryRead]:
    """
    Retrieve profit and loss summary report.

    Args:
        start (Optional[str]): Start date.
        end (Optional[str]): End date.
        db (Session): Database session dependency.

    Returns:
        List[PnlSummaryRead]: P&L summary data.
    """
    logger.info(f"Fetching P&L report from {start} to {end}")
    return get_pnl_report(db=db, start=start, end=end)
