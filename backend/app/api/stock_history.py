import logging
from typing import Optional

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.stock_history import StockHistoryResponse
from app.db.session import get_db
from app.services.stock_history import get_stock_history
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Stock Entry History"])


@router.get(
    "/{stock_entry_id}/history",
    response_model=StockHistoryResponse,
    summary="Get stock entry history",
)
def read_history(
    stock_entry_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> StockHistoryResponse:
    """
    Retrieve the full history of a stock entry, including the original receipt and any subsequent adjustments.

    Args:
        stock_entry_id (int): Stock entry ID.
        db (Session): Database session.

    Returns:
        StockHistoryResponse: History details.

    Raises:
        AppException: If entry not found.
    """
    logger.info(f"Fetching history for stock entry id={stock_entry_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_stock_history(
        db=db, stock_entry_id=stock_entry_id, warehouse_id=resolved_warehouse_id
    )
