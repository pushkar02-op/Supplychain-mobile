from typing import Dict, List

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.session import get_db
from app.services.reconciliation import get_ledger_health_report
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

router = APIRouter(prefix="/admin/ledger", tags=["Admin Ledger"])


def set_no_cache(response: Response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"


@router.get("/health", summary="Get high-level ledger health summary")
def get_health_summary(
    response: Response,
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> Dict:
    """
    Returns a summary of ledger health.
    Strictly read-only. Non-cacheable.
    """
    set_no_cache(response)
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    report = get_ledger_health_report(db, warehouse_id=resolved_warehouse_id)

    # Actually get_ledger_health_report returns only drifted/issues
    # Let's get counts
    from app.db.models.batch import Batch

    all_batch_count = (
        db.query(Batch).filter(Batch.warehouse_id == resolved_warehouse_id).count()
    )
    drifted_count = len([r for r in report if r.get("is_drifted")])
    negative_count = len([r for r in report if r.get("state_qty", 0) < 0])

    return {
        "status": "warning" if drifted_count > 0 or negative_count > 0 else "healthy",
        "total_batches": all_batch_count,
        "drifted_batches": drifted_count,
        "negative_stock_batches": negative_count,
        "unhealthy_records": len(report),
    }


@router.get(
    "/reconcile", summary="Get detailed drift report for all problematic batches"
)
def get_reconciliation_report(
    response: Response,
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> List[Dict]:
    """
    Returns detailed drift records for any batch with health issues.
    Strictly read-only. Non-cacheable.
    """
    set_no_cache(response)
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_ledger_health_report(db, warehouse_id=resolved_warehouse_id)
