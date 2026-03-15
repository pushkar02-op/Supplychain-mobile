from typing import List

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.reconciliation import (
    DriftResolutionRequest,
    DriftResolutionResult,
    ReconciliationRecordRead,
)
from app.db.session import get_db
from app.services.reconciliation import (
    create_drift_record,
    get_all_reconciliation_records,
    resolve_drift,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

router = APIRouter(prefix="/admin/reconciliation", tags=["Admin Reconciliation"])


def set_no_cache(response: Response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"


@router.get("/records", response_model=List[ReconciliationRecordRead])
def list_reconciliation_records(
    response: Response,
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    List all reconciliation records (drift history).
    """
    set_no_cache(response)
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    records = get_all_reconciliation_records(db, warehouse_id=resolved_warehouse_id)
    return records


@router.post("/records/{batch_id}", response_model=ReconciliationRecordRead)
def create_reconciliation_record(
    batch_id: int,
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    Manually create a reconciliation record for a batch if drift is detected.
    """
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "create"
    )
    record = create_drift_record(db, batch_id, warehouse_id=resolved_warehouse_id)
    if not record:
        raise AppException(
            status_code=400,
            detail="No drift detected for this batch or batch not found",
            rule_id=None,
            metadata={},
        )
    return record


@router.post("/resolve", response_model=DriftResolutionResult)
def resolve_reconciliation_drift(
    data: DriftResolutionRequest,
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    Resolve a drift item directly from the drift report.

    Current reconciliation semantics support adjusting the ledger to match the
    current batch state. "state_to_ledger" therefore creates a reconciliation
    record (if needed) and posts an adjusting transaction against the ledger.
    """
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )

    if data.resolution_type != "state_to_ledger":
        raise AppException(
            detail=(
                "ledger_to_state is not supported by the current "
                "reconciliation semantics"
            ),
            status_code=400,
            rule_id=None,
            metadata={},
        )

    record = create_drift_record(db, data.batch_id, warehouse_id=resolved_warehouse_id)
    if not record:
        raise AppException(
            detail="No drift detected for this batch or batch not found",
            status_code=400,
            rule_id=None,
            metadata={},
        )

    result = resolve_drift(
        db,
        record_id=record.id,
        adjustment_qty=record.drift_amount,
        user_id=current_user.id,
        apply_to_batch=False,
        warehouse_id=resolved_warehouse_id,
    )
    if "error" in result:
        raise AppException(
            detail=result["error"], status_code=400, rule_id=None, metadata={}
        )
    resolved_record = result["record"]
    adjustment_txn_id = resolved_record.resolution_txn_id
    if adjustment_txn_id is None:
        raise AppException(
            detail="Resolution completed without an adjustment transaction",
            status_code=500,
            rule_id=None,
            metadata={},
        )
    return DriftResolutionResult(success=True, adjustment_txn_id=adjustment_txn_id)
