from sqlalchemy import (
    Column,
    Date,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class DispatchEntry(Base, AuditMixin):
    __tablename__ = "dispatch_entry"
    __table_args__ = (
        UniqueConstraint(
            "batch_id", "dispatch_date", "mart_id", name="uq_dispatch_entry"
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=False)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    warehouse_id = Column(
        Integer, ForeignKey("warehouse.id"), nullable=False, index=True
    )
    dispatch_date = Column(Date, nullable=False)
    mart_id = Column(Integer, ForeignKey("mart.id"), nullable=False)
    quantity = Column(Numeric(10, 3), nullable=False)
    unit = Column(String, nullable=False)
    remarks = Column(String, nullable=True)
    order_id = Column(Integer, ForeignKey("order.id"), nullable=True)

    batch = relationship("Batch")
    item = relationship("Item")
    mart = relationship("Mart")
    order = relationship("Order")
    warehouse = relationship("Warehouse")

    @property
    def mart_name(self):
        return self.mart.name if self.mart else None
