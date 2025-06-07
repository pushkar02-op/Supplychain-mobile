"""
API endpoints for audit log management.
Provides retrieval of audit log entries.
"""

import logging
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.db.schemas.audit_log import AuditLogRead
from app.services.audit_log import get_all_audit_logs
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


@router.get("/", response_model=List[AuditLogRead])
def read_logs(db: Session = Depends(get_db)) -> List[AuditLogRead]:
    """
    Retrieve all audit logs.

    Args:
        db (Session): Database session dependency.

    Returns:
        List[AuditLogRead]: List of audit log entries.
    """
    logger.info("Fetching all audit logs")
    return get_all_audit_logs(db)
