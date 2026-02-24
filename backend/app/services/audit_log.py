"""
Service functions for audit log management.
Handles retrieval of audit log entries from the database.
"""

import logging
from typing import List

from app.core.exceptions import AppException
from app.db.models.audit_log import AuditLog
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def get_all_audit_logs(db: Session) -> List[AuditLog]:
    """
    Fetch all audit log entries, ordered by timestamp descending.

    Args:
        db (Session): Database session.

    Returns:
        List[AuditLog]: List of audit log records.
    """
    logger.info("Retrieving all audit logs")
    try:
        logs = db.query(AuditLog).order_by(AuditLog.created_at.desc()).all()
        logger.debug(f"Retrieved {len(logs)} audit logs")
        return logs
    except Exception:
        logger.exception("Failed to fetch audit logs")
        raise AppException("Could not fetch audit logs", status_code=500)
