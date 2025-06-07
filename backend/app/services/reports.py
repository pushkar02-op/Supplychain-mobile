"""
Service functions for reporting.
Handles inventory and P&L summary retrieval from materialized views.
"""

import logging
from typing import List, Optional

from sqlalchemy.orm import Session

from app.db.models.views.inventory_summary import InventorySummary
from app.db.models.views.pnl_summary import PnlSummary
from app.db.schemas.inventory_summary import InventorySummaryRead
from app.db.schemas.pnl_summary import PnlSummaryRead

logger = logging.getLogger(__name__)


def get_inventory_report(
    db: Session, item_id: Optional[int]
) -> List[InventorySummaryRead]:
    """
    Retrieve inventory summary report, optionally filtered by item.

    Args:
        db (Session): Database session.
        item_id (Optional[int]): Filter by item ID.

    Returns:
        List[InventorySummaryRead]: Inventory summary data.
    """
    logger.info(f"Fetching inventory report for item_id={item_id}")
    q = db.query(InventorySummary)
    if item_id:
        q = q.filter(InventorySummary.item_id == item_id)
    results = q.all()
    logger.debug(f"Retrieved {len(results)} inventory records")
    return [InventorySummaryRead.from_orm(r) for r in results]


def get_pnl_report(
    db: Session, start: Optional[str], end: Optional[str]
) -> List[PnlSummaryRead]:
    """
    Retrieve profit & loss summary report between dates.

    Args:
        db (Session): Database session.
        start (Optional[str]): Start date YYYY-MM-DD.
        end (Optional[str]): End date YYYY-MM-DD.

    Returns:
        List[PnlSummaryRead]: P&L summary data.
    """
    logger.info(f"Fetching P&L report from {start} to {end}")
    q = db.query(PnlSummary)
    if start:
        q = q.filter(PnlSummary.date >= start)
    if end:
        q = q.filter(PnlSummary.date <= end)
    results = q.all()
    logger.debug(f"Retrieved {len(results)} P&L records")
    return [PnlSummaryRead.from_orm(r) for r in results]
