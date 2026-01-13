import logging
from datetime import datetime
from decimal import Decimal
from typing import Dict, List, Optional

from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.reconciliation_record import DriftStatus, ReconciliationRecord
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.inventory_truth import calculate_ledger_balance
from app.services.inventory_txn import create_inventory_txn
from app.services.item_conversion_map import get_conversion_factor
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def check_batch_drift(db: Session, batch_id: int) -> Dict:
    """
    Compares Batch.quantity (cached) vs Ledger Sum (via inventory_truth).
    Strictly read-only.
    """
    batch = db.get(Batch, batch_id)
    if not batch:
        return {"error": "Batch not found"}

    item = db.get(Item, batch.item_id)
    if not item:
        return {"error": "Item not found"}

    # Source of truth: Ledger Sum (Centralized)
    ledger_qty = calculate_ledger_balance(db, batch_id)

    # Batch (Cached) Qty normalization
    current_unit = batch.unit
    target_unit = item.default_uom_code or current_unit

    try:
        factor = get_conversion_factor(db, batch.item_id, current_unit, target_unit)
    except Exception:
        logger.warning(f"Could not find conversion for batch {batch_id}, assuming 1.0")
        factor = Decimal("1.0")

    batch_qty_base = Decimal(batch.quantity) * factor
    drift = batch_qty_base - ledger_qty

    # Classification
    is_drifted = drift != Decimal("0")
    status = "healthy"
    if is_drifted:
        status = "drifted"

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


def create_drift_record(db: Session, batch_id: int) -> Optional[ReconciliationRecord]:
    """
    Persists the current drift state as a ReconciliationRecord.
    Reference Point for resolution.
    """
    drift_data = check_batch_drift(db, batch_id)
    if drift_data.get("error"):
        return None

    if not drift_data["is_drifted"]:
        return None

    record = ReconciliationRecord(
        batch_id=batch_id,
        observed_ledger_qty=drift_data["ledger_qty"],
        observed_state_qty=drift_data["batch_qty_base"],
        drift_amount=drift_data["drift"],
        status=DriftStatus.OPEN,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def resolve_drift(
    db: Session,
    record_id: int,
    adjustment_qty: Decimal,
    user_id: int,
    apply_to_batch: bool = True,
) -> Dict:
    """
    Resolves a drift record by creating an ADJUST transaction.
    - Creates InventoryTxn (ADJUST).
    - Updates Batch.quantity (State) IF apply_to_batch is True.
    - Marks Record as RESOLVED.
    """
    record = db.get(ReconciliationRecord, record_id)
    if not record:
        return {"error": "Record not found"}

    if record.status != DriftStatus.OPEN:
        return {"error": "Record is not open"}

    batch = db.get(Batch, record.batch_id)
    if not batch:
        return {"error": "Batch via record not found"}

    item = db.get(Item, batch.item_id)

    # 1. Create Txn (Ledger Adjustment)
    txn_data = InventoryTxnCreate(
        item_id=batch.item_id,
        batch_id=batch.id,
        txn_type="ADJUST",
        raw_qty=adjustment_qty,
        raw_unit=item.default_uom_code,
        base_qty=adjustment_qty,
        base_unit=item.default_uom_code,
        remarks=f"Reconciliation Resolution for Record {record_id} (State Update: {apply_to_batch})",
        ref_type="reconciliation_record",
        ref_id=record.id,
    )

    txn = create_inventory_txn(db, txn_data)

    # 2. Update State (Batch) optionally
    if apply_to_batch:
        batch.quantity += adjustment_qty
        batch.updated_by = user_id
        batch.updated_at = datetime.utcnow()

    record.status = DriftStatus.RESOLVED
    record.resolution_txn_id = txn.id
    record.resolved_at = datetime.utcnow()
    record.resolved_by = user_id

    db.commit()
    db.refresh(record)
    return {"status": "success", "record": record}


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
