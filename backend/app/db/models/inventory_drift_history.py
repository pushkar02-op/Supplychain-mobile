from datetime import datetime

from app.db.models.base_class import Base
from sqlalchemy import Column, DateTime, Integer, Numeric, String


class InventoryDriftHistory(Base):
    __tablename__ = "inventory_drift_history"

    id = Column(Integer, primary_key=True, index=True)
    batch_id = Column(Integer, nullable=False)
    drift = Column(Numeric(10, 3), nullable=False)
    severity = Column(String, nullable=False)  # "LOW", "MEDIUM", "HIGH"
    resolved_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    resolution_type = Column(String, nullable=False)  # e.g. "ADJUSTMENT", "IGNORE"

    def __repr__(self):
        return f"<DriftHistory(batch={self.batch_id}, drift={self.drift})>"
