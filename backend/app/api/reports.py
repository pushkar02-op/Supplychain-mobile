"""
API endpoints for reports.
Provides inventory and P&L summary reports.
"""

import logging
from typing import List, Optional

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.inventory_summary import (
    InventorySignalResponse,
    InventorySummaryRead,
    ReconciliationDetail,
    ReconciliationItem,
)
from app.db.schemas.pnl_summary import PnlSummaryRead
from app.db.session import get_db
from app.services.reports import get_inventory_report, get_pnl_report
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get(
    "/inventory/reconciliation",
    response_model=List[ReconciliationItem],
    summary="Inventory reconciliation report",
)
def read_reconciliation_report(
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    Get detailed reconciliation report showing drift between Batches (Available) and Ledger.
    """
    from app.services.reports import get_reconciliation_report

    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_reconciliation_report(db, warehouse_id=resolved_warehouse_id)


@router.get(
    "/inventory/{item_id}/reconciliation",
    response_model=ReconciliationDetail,
    summary="Item inventory reconciliation details",
)
def read_item_reconciliation(
    item_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    Get drill-down reconciliation details for a specific item.
    """
    from app.services.reports import get_item_reconciliation

    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    res = get_item_reconciliation(db, resolved_warehouse_id, item_id)
    if not res:
        raise AppException(
            detail="Item not found", status_code=404, rule_id=None, metadata={}
        )
    return res


@router.get(
    "/inventory/{item_id}/signals",
    response_model=InventorySignalResponse,
    summary="Inventory signal details",
)
def read_inventory_signals(
    item_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> InventorySignalResponse:
    """
    Retrieve detailed inventory signals for an item.
    """
    from app.services.reports import get_item_signals

    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    data = get_item_signals(db=db, warehouse_id=resolved_warehouse_id, item_id=item_id)
    if not data:
        raise AppException(
            detail="Item not found", status_code=404, rule_id=None, metadata={}
        )
    return data


@router.get(
    "/inventory", response_model=List[InventorySummaryRead], summary="Inventory report"
)
def inventory(
    item_id: Optional[int] = Query(None, description="Filter by item ID"),
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
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
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_inventory_report(
        db=db, warehouse_id=resolved_warehouse_id, item_id=item_id
    )


@router.get("/pnl", response_model=List[PnlSummaryRead], summary="P&L report")
def pnl(
    start: Optional[str] = Query(None, description="Start date YYYY-MM-DD"),
    end: Optional[str] = Query(None, description="End date YYYY-MM-DD"),
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
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
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_pnl_report(
        db=db, warehouse_id=resolved_warehouse_id, start=start, end=end
    )
