import enum
from datetime import datetime

from app.db.models.base_class import Base
from sqlalchemy import Column, DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship


class DriftStatus(str, enum.Enum):
    OPEN = "OPEN"
    RESOLVED = "RESOLVED"
    IGNORED = "IGNORED"


class ReconciliationRecord(Base):
    __tablename__ = "reconciliation_record"

    id = Column(Integer, primary_key=True, index=True)
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=False)
    warehouse_id = Column(
        Integer, ForeignKey("warehouse.id"), nullable=False, index=True
    )

    # Observed Facts (Immutable snapshot)
    observed_ledger_qty = Column(Numeric(10, 3), nullable=False)
    observed_state_qty = Column(Numeric(10, 3), nullable=False)
    drift_amount = Column(Numeric(10, 3), nullable=False)

    status = Column(
        String(32), default=DriftStatus.OPEN, nullable=False
    )  # stored as string or enum

    # Audit
    detected_at = Column(DateTime, default=datetime.utcnow)
    resolution_txn_id = Column(Integer, ForeignKey("inventory_txn.id"), nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    resolved_by = Column(Integer, nullable=True)  # User ID

    batch = relationship("Batch")
    warehouse = relationship("Warehouse")
    resolution_txn = relationship("InventoryTxn")
