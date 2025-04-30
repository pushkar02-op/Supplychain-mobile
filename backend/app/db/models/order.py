from sqlalchemy import Column, Integer, String, ForeignKey, Date, Float, UniqueConstraint
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin

class Order(Base, AuditMixin):
    __tablename__ = "order"
    __table_args__ = (
            UniqueConstraint("item_id", "order_date", "mart_name", name="uq_order_unique_combination"),
        )
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    mart_name = Column(String, nullable=False)
    order_date = Column(Date, nullable=False)
    quantity_ordered = Column(Float, nullable=False)
    quantity_dispatched = Column(Float, default=0.0)  # updated as dispatch happens
    status = Column(String, default="Pending")  # Pending, Partially Completed, Completed
    unit = Column(String, nullable=False)
    
    item = relationship("Item")
