"""
API endpoint for stock adjustments (corrections).
"""

import logging
from decimal import Decimal

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.session import get_db
from app.services.stock_entry import create_stock_adjustment
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, status
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
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> StockAdjustmentResponse:
    """
    Create a stock adjustment (correction) for a batch.

    This creates an 'ADJUST' InventoryTxn and updates the batch quantity.
    The original stock entry remains unchanged.
    """
    logger.info(f"Creating stock adjustment for batch_id={adjustment.batch_id}")

    try:
        resolved_warehouse_id = resolve_warehouse_for_request(
            current_user, warehouse_id, db, "update"
        )
        txn = create_stock_adjustment(
            db=db,
            batch_id=adjustment.batch_id,
            quantity_delta=Decimal(str(adjustment.quantity_delta)),
            unit=adjustment.unit,
            reason=adjustment.reason,
            user_id=current_user.id if current_user else None,
            warehouse_id=resolved_warehouse_id,
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
