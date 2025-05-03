from sqlalchemy import Column, Integer, ForeignKey, String, Date
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin

class Batch(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    unit = Column(String, nullable=False)
    expiry_date = Column(Date, nullable=True)
    received_at = Column(Date, nullable=True) 
    remarks = Column(String, nullable=True)

    item = relationship("Item")
    
    @property
    def item_name(self):
        return self.item.name if self.item else None
