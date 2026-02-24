"""
API endpoints for audit log management.
"""

import logging
from typing import List

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.audit_log import AuditLogRead
from app.db.session import get_db
from app.services.audit import get_audit_logs
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


@router.get(
    "/",
    response_model=List[AuditLogRead],
    response_model_by_alias=False,
)
def read_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> List[AuditLogRead]:
    logger.info("Fetching all audit logs")
    return get_audit_logs(db=db)
