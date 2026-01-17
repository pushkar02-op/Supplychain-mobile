import logging

from app.core.auth import get_current_user
from app.db.models.user import User
from app.db.schemas.stock_history import StockHistoryResponse
from app.db.session import get_db
from app.services.stock_history import get_stock_history
from fastapi import APIRouter, Depends
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
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
    return get_stock_history(db=db, stock_entry_id=stock_entry_id)
