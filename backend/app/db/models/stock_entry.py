from decimal import Decimal

from sqlalchemy import Boolean, Column, Date, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class StockEntry(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=False)
    warehouse_id = Column(
        Integer, ForeignKey("warehouse.id"), nullable=False, index=True
    )
    source_bill_item_id = Column(
        Integer, ForeignKey("invoice_item.id"), nullable=True, index=True
    )
    received_date = Column(Date, nullable=False)
    source = Column(String, nullable=True)
    price_per_unit = Column(Numeric(18, 6), nullable=False)
    total_cost = Column(Numeric(18, 6), nullable=False)
    quantity = Column(Numeric(10, 3), nullable=False, default=Decimal("0.000"))
    unit = Column(String, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    item = relationship("Item")
    batch = relationship("Batch")
    warehouse = relationship("Warehouse")
