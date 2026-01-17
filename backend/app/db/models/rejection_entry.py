from sqlalchemy import Boolean, Column, Date, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class RejectionEntry(Base, AuditMixin):
    __tablename__ = "rejection_entries"
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=True)
    quantity = Column(Numeric(18, 6, asdecimal=True), nullable=False)

    reason = Column(Text, nullable=True)
    rejection_date = Column(Date, nullable=False)
    rejected_by = Column(String, nullable=True)
    item = relationship("Item")
    batch = relationship("Batch")
    unit = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
