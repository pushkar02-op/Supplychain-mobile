import logging
from datetime import date
from typing import List, Optional

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.audit_log import AuditLogRead
from app.db.session import get_db
from app.services.audit import get_audit_logs
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin Audit"])


@router.get(
    "/audit-log",
    response_model=List[AuditLogRead],
    response_model_by_alias=False,
)
def read_admin_audit_log(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    actor_user_id: Optional[int] = Query(None),
    entity_type: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> List[AuditLogRead]:
    logger.info("Fetching admin audit log")
    return get_audit_logs(
        db=db,
        start_date=start_date,
        end_date=end_date,
        actor_user_id=actor_user_id,
        entity_type=entity_type,
    )
