from typing import List
from sqlalchemy.orm import Session
from app.db.models.audit_log import AuditLog

def get_all_audit_logs(db: Session) -> List[AuditLog]:
    return db.query(AuditLog).order_by(AuditLog.timestamp.desc()).all()
