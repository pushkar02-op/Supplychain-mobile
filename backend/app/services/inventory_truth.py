"""
Inventory Truth Service (Phase 2)
Responsibility: strict, read-only calculation of inventory truth from the Ledger (InventoryTxn).
Invariant: The Ledger is the source of truth. The Batch.quantity is a cached state.
"""

from decimal import Decimal
from typing import Dict

from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from sqlalchemy.orm import Session


def calculate_ledger_balance(db: Session, batch_id: int) -> Decimal:
    """
    Sum all base_qty from InventoryTxn for a given batch.
    IN adds to balance, OUT subtracts.
    """
    txns = db.query(InventoryTxn).filter(InventoryTxn.batch_id == batch_id).all()
    balance = Decimal("0")

    for txn in txns:
        if txn.txn_type == "IN":
            balance += txn.base_qty
        elif txn.txn_type in ["OUT", "REJECT", "DISPATCH"]:
            balance -= txn.base_qty
        elif txn.txn_type == "ADJUST":
            balance += txn.base_qty

    return balance


def get_drift_report(db: Session, batch_id: int) -> Dict:
    """
    Compares Ledger Balance vs Batch State.
    Returns explicit drift details.
    """
    batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if not batch:
        return {"error": "Batch not found"}

    ledger_qty = calculate_ledger_balance(db, batch_id)
    drift = batch.quantity - ledger_qty

    return {
        "batch_id": batch_id,
        "state_quantity": batch.quantity,
        "ledger_quantity": ledger_qty,
        "drift": drift,
        "is_drifted": drift != Decimal("0"),
    }
