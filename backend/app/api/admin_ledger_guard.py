from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.session import get_db
from app.services.ledger_guard import check_inventory_drift, check_ledger_integrity
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter(prefix="/admin/ledger", tags=["Admin Ledger Guard"])


@router.get("/health", summary="Runtime ledger guard health")
def get_ledger_guard_health(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> dict:
    drift_batches = check_inventory_drift(db)
    invalid_refs = check_ledger_integrity(db)
    ledger_status = "healthy" if not drift_batches and not invalid_refs else "unhealthy"
    return {
        "drift_batches": drift_batches,
        "invalid_refs": invalid_refs,
        "ledger_status": ledger_status,
    }
