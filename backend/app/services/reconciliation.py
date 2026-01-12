"""
Service for ledger reconciliation and inventory drift detection.
Strictly read-only.
"""

import logging
from decimal import Decimal
from typing import Dict, List

from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.services.item_conversion_map import get_conversion_factor
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def check_batch_drift(db: Session, batch_id: int) -> Dict:
    """
    Compares Batch.quantity (cached) vs SUM(InventoryTxn.base_qty).
    Strictly read-only.
    """
    batch = db.get(Batch, batch_id)
    if not batch:
        return {"error": "Batch not found"}

    item = db.get(Item, batch.item_id)
    if not item:
        return {"error": "Item not found"}

    # Source of truth: Ledger Sum
    # Sum of IN - Sum of OUT
    # Note: We assume InventoryTxn base_qty is always positive and
    # txn_type indicates direction.
    in_sum = db.query(func.sum(InventoryTxn.base_qty)).filter(
        InventoryTxn.batch_id == batch_id, InventoryTxn.txn_type == "IN"
    ).scalar() or Decimal("0.0")

    out_sum = db.query(func.sum(InventoryTxn.base_qty)).filter(
        InventoryTxn.batch_id == batch_id, InventoryTxn.txn_type == "OUT"
    ).scalar() or Decimal("0.0")

    ledger_qty = in_sum - out_sum

    # Batch (Cached) Qty
    # We must convert batch.quantity (raw) to base unit for comparison
    # if the Batch.unit is not the default_uom.
    current_unit = batch.unit
    target_unit = item.default_uom_code or current_unit

    try:
        factor = get_conversion_factor(db, batch.item_id, current_unit, target_unit)
    except Exception:
        logger.warning(
            f"Could not find conversion for batch {batch_id}, assuming factor 1.0"
        )
        factor = Decimal("1.0")

    batch_qty_base = Decimal(batch.quantity) * factor
    drift = batch_qty_base - ledger_qty

    # Drift Detection Rule: abs(drift) > max(0.01, ledger_qty * 0.001)
    tolerance = max(0.01, abs(ledger_qty) * 0.001)
    is_drifted = abs(drift) > tolerance

    status = "healthy"
    if is_drifted:
        status = "drifted"
    elif batch_qty_base < -0.01:  # Check for negative stock
        status = "negative"

    return {
        "batch_id": batch_id,
        "item_name": item.name,
        "batch_qty_raw": batch.quantity,
        "batch_unit_raw": batch.unit,
        "batch_qty_base": batch_qty_base,
        "ledger_qty": ledger_qty,
        "base_unit": target_unit,
        "drift": drift,
        "status": status,
        "is_drifted": is_drifted,
    }


def get_ledger_health_report(db: Session) -> List[Dict]:
    """
    Returns health report for all batches with non-zero drift or issues.
    Strictly read-only.
    """
    batches = db.query(Batch).all()
    report = []
    for b in batches:
        metrics = check_batch_drift(db, b.id)
        if metrics.get("is_drifted") or metrics.get("status") != "healthy":
            report.append(metrics)
    return report
