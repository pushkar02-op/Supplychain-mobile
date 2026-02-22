"""
API endpoint for stock adjustments (corrections).
"""

import logging
from decimal import Decimal

from app.core.auth import get_current_user
from app.core.exceptions import AppException
from app.db.models.user import User
from app.db.session import get_db
from app.services.stock_entry import create_stock_adjustment
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/stock-adjustment", tags=["Stock Adjustment"])


class StockAdjustmentCreate(BaseModel):
    """Request schema for creating a stock adjustment."""

    batch_id: int = Field(..., description="ID of the batch to adjust")
    quantity_delta: Decimal = Field(..., description="Adjustment quantity (+ or -)")
    unit: str = Field(..., description="Unit of measurement")
    reason: str = Field(..., min_length=1, description="Required reason for adjustment")


class StockAdjustmentResponse(BaseModel):
    """Response schema for stock adjustment."""

    success: bool
    message: str
    txn_id: int | None = None


@router.post(
    "/",
    response_model=StockAdjustmentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create stock adjustment",
)
def create_adjustment(
    adjustment: StockAdjustmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> StockAdjustmentResponse:
    """
    Create a stock adjustment (correction) for a batch.

    This creates an 'ADJUST' InventoryTxn and updates the batch quantity.
    The original stock entry remains unchanged.
    """
    logger.info(f"Creating stock adjustment for batch_id={adjustment.batch_id}")

    try:
        txn = create_stock_adjustment(
            db=db,
            batch_id=adjustment.batch_id,
            quantity_delta=Decimal(str(adjustment.quantity_delta)),
            unit=adjustment.unit,
            reason=adjustment.reason,
            user_id=current_user.id if current_user else None,
        )

        return StockAdjustmentResponse(
            success=True,
            message="Adjustment recorded successfully",
            txn_id=txn.id if txn else None,
        )
    except AppException as e:
        logger.error(f"Adjustment failed: {e}")
        raise
    except Exception as e:
        logger.exception(f"Unexpected error during adjustment: {e}")
        raise AppException(f"Failed to create adjustment: {str(e)}", status_code=500)
