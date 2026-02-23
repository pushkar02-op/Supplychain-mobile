from typing import List

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.reconciliation import (
    ReconciliationRecordRead,
    ReconciliationRecordResolve,
)
from app.db.session import get_db
from app.services.reconciliation import (
    create_drift_record,
    get_all_reconciliation_records,
    resolve_drift,
)
from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

router = APIRouter(prefix="/admin/reconciliation", tags=["Admin Reconciliation"])


def set_no_cache(response: Response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"


@router.get("/records", response_model=List[ReconciliationRecordRead])
def list_reconciliation_records(
    response: Response,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    List all reconciliation records (drift history).
    """
    set_no_cache(response)
    records = get_all_reconciliation_records(db)
    return records


@router.post("/records/{batch_id}", response_model=ReconciliationRecordRead)
def create_reconciliation_record(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    Manually create a reconciliation record for a batch if drift is detected.
    """
    record = create_drift_record(db, batch_id)
    if not record:
        raise AppException(
            status_code=400,
            detail="No drift detected for this batch or batch not found",
            rule_id=None,
            metadata={},
        )
    return record


@router.post("/resolve", response_model=ReconciliationRecordRead)
def resolve_reconciliation_drift(
    data: ReconciliationRecordResolve,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
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
        raise AppException(
            detail=result["error"], status_code=400, rule_id=None, metadata={}
        )
    return result["record"]
