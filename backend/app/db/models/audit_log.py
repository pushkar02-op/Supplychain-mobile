from datetime import datetime

from sqlalchemy import JSON, Column, DateTime, ForeignKey, Index, Integer, String, desc

from .base_class import Base


class AuditLog(Base):
    __tablename__ = "audit_log"
    __table_args__ = (
        Index(
            "ix_audit_log_warehouse_created_at",
            "warehouse_id",
            desc("created_at"),
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    actor_user_id = Column(Integer, ForeignKey("user.id"), nullable=False)
    warehouse_id = Column(Integer, nullable=True, index=True)
    action_type = Column(String, nullable=False)
    entity_type = Column(String, nullable=False)
    entity_id = Column(Integer, nullable=True)
    event_metadata = Column("metadata", JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
