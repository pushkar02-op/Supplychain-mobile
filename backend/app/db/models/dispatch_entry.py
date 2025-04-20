from sqlalchemy import Column, Integer, ForeignKey, Date, Float, String
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin

class DispatchEntry(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=False)
    dispatch_date = Column(Date, nullable=False)
    mart_name = Column(String, nullable=False)
    quantity = Column(Integer, nullable=False)
    unit = Column(String, nullable=False)
    sell_price_per_unit = Column(Float, nullable=False)
    total_revenue = Column(Float, nullable=False)

    batch = relationship("Batch")
