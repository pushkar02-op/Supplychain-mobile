from datetime import datetime
from enum import Enum

from app.db.models.base_class import Base
from sqlalchemy import JSON, Column, DateTime
from sqlalchemy import Enum as SAEnum
from sqlalchemy import Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship


class MismatchType(str, Enum):
    IDENTITY = "IDENTITY"
    QUANTITY = "QUANTITY"
    UOM = "UOM"
    PRICE = "PRICE"
    MISSING_ENTRY = "MISSING_ENTRY"  # In Invoice but not in System
    MISSING_INVOICE = "MISSING_INVOICE"  # In System but not in Invoice (Advanced)


class MismatchStatus(str, Enum):
    OPEN = "OPEN"
    RESOLVED_SYSTEM = "RESOLVED_SYSTEM"  # Admin accepted System value
    RESOLVED_MART = "RESOLVED_MART"  # Admin accepted Mart value (requires manual fix)
    IGNORED = "IGNORED"


class ReconciliationMismatch(Base):
    __tablename__ = "reconciliation_mismatch"

    id = Column(Integer, primary_key=True, index=True)

    # Context
    invoice_item_id = Column(
        Integer, ForeignKey("invoice_item.id"), nullable=False, index=True
    )
    batch_id = Column(
        Integer, ForeignKey("batch.id"), nullable=True, index=True
    )  # Null if MISSING_ENTRY

    # Details
    mismatch_type = Column(SAEnum(MismatchType), nullable=False)

    # Snapshots (JSON for detailed comparisons)
    system_value = Column(JSON, nullable=True)  # e.g. {"qty": 10, "uom": "kg"}
    mart_value = Column(JSON, nullable=True)  # e.g. {"qty": 12, "uom": "kg"}

    # Meta
    confidence_score = Column(Float, nullable=False, default=0.0)  # 0.0 to 1.0
    status = Column(
        SAEnum(MismatchStatus), default=MismatchStatus.OPEN, nullable=False, index=True
    )
    resolution_notes = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )
    resolved_at = Column(DateTime, nullable=True)
    resolved_by = Column(String, nullable=True)

    # Relationships
    invoice_item = relationship("InvoiceItem")
    batch = relationship("Batch")
