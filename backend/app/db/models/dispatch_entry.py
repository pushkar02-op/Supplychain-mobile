from sqlalchemy import Column, Integer, ForeignKey, Date, Float, String, UniqueConstraint
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin

class DispatchEntry(Base, AuditMixin):
    __table_args__ = (
    UniqueConstraint('batch_id', 'dispatch_date', 'mart_name', name='uq_dispatch_entry'),
)

    id = Column(Integer, primary_key=True, index=True)
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=False)
    dispatch_date = Column(Date, nullable=False)
    mart_name = Column(String, nullable=False)
    quantity = Column(Integer, nullable=False)
    unit = Column(String, nullable=False)

    batch = relationship("Batch")
