from datetime import datetime

from sqlalchemy import Column, DateTime, Integer, String


class AuditMixin:
    created_by = Column(String, nullable=True)
    created_by_id = Column(Integer, nullable=True)  # Added in migration f9e8d7c6b5a4
    updated_by = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
