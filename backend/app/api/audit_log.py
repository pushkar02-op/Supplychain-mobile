from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.db.schemas.audit_log import AuditLogRead
from app.services.audit_log import get_all_audit_logs
from app.db.session import get_db

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])

@router.get("/", response_model=List[AuditLogRead])
def read_logs(db: Session = Depends(get_db)):
    return get_all_audit_logs(db)
