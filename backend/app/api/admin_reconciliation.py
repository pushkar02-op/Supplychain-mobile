from typing import List

from app.core.auth import get_current_active_admin
from app.db.models.reconciliation_record import ReconciliationRecord
from app.db.models.user import User
from app.db.schemas.reconciliation import (
    ReconciliationRecordRead,
    ReconciliationRecordResolve,
)
from app.db.session import get_db
from app.services.reconciliation import create_drift_record, resolve_drift
from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

router = APIRouter(prefix="/admin/reconciliation", tags=["Admin Reconciliation"])


def set_no_cache(response: Response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"


@router.get("/records", response_model=List[ReconciliationRecordRead])
def list_reconciliation_records(
    response: Response,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin),
):
    """
    List all reconciliation records (drift history).
    """
    set_no_cache(response)
    records = db.scalars(
        select(ReconciliationRecord).order_by(ReconciliationRecord.detected_at.desc())
    ).all()
    return records


@router.post("/records/{batch_id}", response_model=ReconciliationRecordRead)
def create_reconciliation_record(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin),
):
    """
    Manually create a reconciliation record for a batch if drift is detected.
    """
    record = create_drift_record(db, batch_id)
    if not record:
        raise HTTPException(
            status_code=400,
            detail="No drift detected for this batch or batch not found",
        )
    return record


@router.post("/resolve", response_model=ReconciliationRecordRead)
def resolve_reconciliation_drift(
    data: ReconciliationRecordResolve,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin),
):
    """
    Resolve a drift record by creating an adjustment transaction.
    """
    result = resolve_drift(
        db,
        record_id=data.record_id,
        adjustment_qty=data.adjustment_qty,
        user_id=current_user.id,
        apply_to_batch=data.apply_to_batch,
    )
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result["record"]
