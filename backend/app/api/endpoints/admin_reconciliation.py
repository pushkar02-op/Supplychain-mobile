"""
Admin API for Reconciliation & Dispute Handling (Phase 3).
Adheres to REC-001 (read-only for inventory) and REC-004 (admin workflow).
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.reconciliation_mismatch import ReconciliationMismatch, MismatchStatus
from app.services.reconciliation import run_invoice_reconciliation, resolve_mismatch

router = APIRouter(prefix="/admin/reconciliation", tags=["Admin - Reconciliation"])


# --- Schemas ---

class ReconciliationRunRequest(BaseModel):
    invoice_id: int


class MismatchResolveRequest(BaseModel):
    mismatch_id: int
    resolution: str  # "SYSTEM" | "MART" | "IGNORED"
    notes: str = None


class MismatchRead(BaseModel):
    id: int
    invoice_item_id: int
    batch_id: int | None
    mismatch_type: str
    confidence_score: float
    status: str
    mart_value: dict
    system_value: dict

    class Config:
        from_attributes = True


# --- Endpoints ---

@router.post("/run")
def trigger_reconciliation(
    payload: ReconciliationRunRequest,
    db: Session = Depends(get_db)
):
    """
    Triggers reconciliation for a specific Invoice.
    Compares InvoiceItems against StockEntries.
    Creates ReconciliationMismatch records for discrepancies.
    Does NOT mutate inventory (REC-001).
    """
    results = run_invoice_reconciliation(db, payload.invoice_id)
    if results and "error" in results[0]:
        raise HTTPException(status_code=404, detail=results[0]["error"])
    return {"invoice_id": payload.invoice_id, "results": results}


@router.get("/mismatches", response_model=List[MismatchRead])
def list_open_mismatches(
    status: str = "OPEN",
    db: Session = Depends(get_db)
):
    """
    Lists reconciliation mismatches filtered by status.
    """
    try:
        status_enum = MismatchStatus(status)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid status: {status}")

    mismatches = (
        db.query(ReconciliationMismatch)
        .filter(ReconciliationMismatch.status == status_enum)
        .order_by(ReconciliationMismatch.created_at.desc())
        .all()
    )
    return mismatches


@router.post("/resolve")
def resolve_dispute(
    payload: MismatchResolveRequest,
    db: Session = Depends(get_db)
):
    """
    Admin workflow to resolve a mismatch (REC-004).
    Options: "SYSTEM" (accept system), "MART" (accept mart claim), "IGNORED".
    Does NOT mutate inventory.
    """
    # TODO: Add authentication to get current_user
    resolved_by = "admin"  # Placeholder

    result = resolve_mismatch(
        db,
        payload.mismatch_id,
        payload.resolution,
        resolved_by,
        payload.notes
    )

    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])

    return result
