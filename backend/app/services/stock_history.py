import logging
from typing import List

from app.core.exceptions import AppException
from app.db.models.inventory_txn import InventoryTxn
from app.db.schemas.stock_history import (
    StockHistoryAdjustment,
    StockHistoryReceipt,
    StockHistoryResponse,
)
from app.services.stock_entry import get_stock_entry
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def get_stock_history(db: Session, stock_entry_id: int) -> StockHistoryResponse:
    """
    Constructs the history of a stock entry from its receipt and subsequent adjustments.
    """
    # 1. Fetch Receipt (StockEntry)
    entry = get_stock_entry(db, stock_entry_id)
    if not entry:
        raise AppException("Stock entry not found", status_code=404)

    receipt = StockHistoryReceipt(
        id=entry.id,
        received_date=entry.received_date,
        quantity=entry.quantity,
        unit=entry.unit,
        price_per_unit=entry.price_per_unit,
        total_cost=entry.total_cost,
        source=entry.source,
    )

    # 2. Fetch Adjustments (associated with the batch)
    adjustments: List[StockHistoryAdjustment] = []

    txns = (
        db.query(InventoryTxn)
        .filter(InventoryTxn.batch_id == entry.batch_id)
        .filter(InventoryTxn.txn_type == "ADJUST")
        .order_by(InventoryTxn.created_at.desc())
        .all()
    )

    for txn in txns:
        adjustments.append(
            StockHistoryAdjustment(
                id=txn.id,
                quantity_delta=txn.raw_qty,
                unit=txn.raw_unit,
                reason=txn.remarks or "Manual Adjustment",
                created_at=txn.created_at,
                created_by=None,
            )
        )

    # 3. Check for Void (Soft Delete)
    is_voided = not entry.is_active
    voided_at = None

    if is_voided:
        # Find the voiding transaction (OUT type linked to this stock entry)
        void_txn = (
            db.query(InventoryTxn)
            .filter(
                InventoryTxn.txn_type == "OUT",
                InventoryTxn.ref_type == "stock_entry",
                InventoryTxn.ref_id == entry.id,
            )
            .order_by(InventoryTxn.created_at.desc())
            .first()
        )
        if void_txn:
            voided_at = void_txn.created_at

    return StockHistoryResponse(
        receipt=receipt,
        adjustments=adjustments,
        is_voided=is_voided,
        voided_at=voided_at,
    )
