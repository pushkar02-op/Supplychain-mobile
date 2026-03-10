from decimal import Decimal

from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.dispatch_reversal import DispatchReversal
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.reconciliation_record import ReconciliationRecord
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.stock_entry import StockEntry
from sqlalchemy import case, func
from sqlalchemy.orm import Session

VALID_REF_MODELS = {
    "stock_entry": StockEntry,
    "dispatch_entry": DispatchEntry,
    "dispatch_reversal": DispatchReversal,
    "rejection_entry": RejectionEntry,
    "rejection_reversal": RejectionEntry,
    "reconciliation_record": ReconciliationRecord,
    "manual_adjustment": Batch,
    "manual": None,
}


def check_inventory_drift(db: Session) -> list[dict]:
    signed_qty = case(
        (InventoryTxn.txn_type == "OUT", -InventoryTxn.base_qty),
        else_=InventoryTxn.base_qty,
    )
    ledger_rows = (
        db.query(
            InventoryTxn.batch_id,
            func.coalesce(func.sum(signed_qty), Decimal("0")).label("ledger_qty"),
        )
        .filter(InventoryTxn.batch_id.isnot(None))
        .group_by(InventoryTxn.batch_id)
        .all()
    )

    ledger_by_batch = {
        int(row.batch_id): Decimal(str(row.ledger_qty)) for row in ledger_rows
    }
    drift_batches: list[dict] = []

    for batch in db.query(Batch).all():
        state_qty = Decimal(str(batch.quantity))
        ledger_qty = ledger_by_batch.get(batch.id, Decimal("0"))
        if state_qty != ledger_qty:
            drift_batches.append(
                {
                    "batch_id": batch.id,
                    "item_id": batch.item_id,
                    "warehouse_id": batch.warehouse_id,
                    "state_qty": str(state_qty),
                    "ledger_qty": str(ledger_qty),
                    "drift": str(state_qty - ledger_qty),
                }
            )

    return drift_batches


def check_ledger_integrity(db: Session) -> list[dict]:
    invalid_rows: list[dict] = []

    for txn in db.query(InventoryTxn).all():
        reasons: list[str] = []

        if txn.ref_type not in VALID_REF_MODELS:
            reasons.append("invalid_ref_type")

        if txn.ref_id is None:
            reasons.append("missing_ref_id")

        if txn.ref_type is None:
            reasons.append("missing_ref_type")

        batch = db.get(Batch, txn.batch_id) if txn.batch_id is not None else None
        if txn.batch_id is None or batch is None:
            reasons.append("missing_batch")

        target_model = VALID_REF_MODELS.get(txn.ref_type)
        if (
            txn.ref_type in VALID_REF_MODELS
            and target_model is not None
            and txn.ref_id is not None
        ):
            if db.get(target_model, txn.ref_id) is None:
                reasons.append("missing_ref_target")

        if reasons:
            invalid_rows.append(
                {
                    "inventory_txn_id": txn.id,
                    "batch_id": txn.batch_id,
                    "ref_type": txn.ref_type,
                    "ref_id": txn.ref_id,
                    "txn_type": txn.txn_type,
                    "reasons": reasons,
                }
            )

    return invalid_rows
