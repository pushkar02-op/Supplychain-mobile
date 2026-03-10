import logging
from datetime import date, datetime
from typing import List, Optional

from app.db.models.audit_log import AuditLog
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def log_action(
    db: Session,
    actor_user_id: int | None,
    action_type: str,
    entity_type: str,
    entity_id: int | None = None,
    metadata: dict | None = None,
) -> AuditLog | None:
    if actor_user_id is None:
        return None

    payload = metadata or {}
    try:
        with db.begin_nested():
            entry = AuditLog(
                actor_user_id=actor_user_id,
                action_type=action_type,
                entity_type=entity_type,
                entity_id=entity_id,
                event_metadata=payload,
            )
            db.add(entry)
            db.flush()
            return entry
    except Exception:
        logger.warning(
            "Audit write failed action_type=%s entity_type=%s",
            action_type,
            entity_type,
            exc_info=True,
        )
        return None


def get_audit_logs(
    db: Session,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    actor_user_id: Optional[int] = None,
    entity_type: Optional[str] = None,
) -> List[AuditLog]:
    query = db.query(AuditLog)
    if start_date is not None:
        query = query.filter(
            AuditLog.created_at >= datetime.combine(start_date, datetime.min.time())
        )
    if end_date is not None:
        query = query.filter(
            AuditLog.created_at <= datetime.combine(end_date, datetime.max.time())
        )
    if actor_user_id is not None:
        query = query.filter(AuditLog.actor_user_id == actor_user_id)
    if entity_type is not None:
        query = query.filter(AuditLog.entity_type == entity_type)
    return query.order_by(AuditLog.created_at.desc()).all()
