from sqlalchemy import Column, Integer, String, DateTime, Text
from datetime import datetime
from .base_class import Base

class AuditLog(Base):
    __tablename__ = "audit_log"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    action_type = Column(String, nullable=False)
    table_name = Column(String, nullable=False)
    record_id = Column(Integer, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
    changes = Column(Text, nullable=True)
