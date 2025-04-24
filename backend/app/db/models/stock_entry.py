from sqlalchemy import Column, Integer, ForeignKey, Date, String, Float
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin

class StockEntry(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False) 
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=False)
    received_date = Column(Date, nullable=False)
    source = Column(String, nullable=True)
    price_per_unit = Column(Float, nullable=False)
    total_cost = Column(Float, nullable=False)
    quantity = Column(Float, nullable=False)
    unit = Column(String, nullable=False)
    
    item = relationship("Item")
    batch = relationship("Batch")
