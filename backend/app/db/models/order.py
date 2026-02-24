from decimal import Decimal

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


class Order(Base, AuditMixin):
    __tablename__ = "order"
    __table_args__ = (
        UniqueConstraint(
            "item_id", "order_date", "mart_id", name="uq_order_unique_combination"
        ),
    )
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    mart_id = Column(Integer, ForeignKey("mart.id"), nullable=False)
    warehouse_id = Column(
        Integer, ForeignKey("warehouse.id"), nullable=False, index=True
    )
    order_date = Column(Date, nullable=False)
    quantity_ordered = Column(Numeric(10, 3), nullable=False)
    quantity_dispatched = Column(
        Numeric(10, 3), default=Decimal("0.000")
    )  # updated as dispatch happens
    status = Column(
        String, default="Pending"
    )  # Pending, Partially Completed, Completed
    unit = Column(String, nullable=False)

    item = relationship("Item")
    mart = relationship("Mart", back_populates="orders")
    warehouse = relationship("Warehouse")
