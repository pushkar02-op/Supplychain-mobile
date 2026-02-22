from decimal import Decimal

from app.db.models.base_class import Base
from sqlalchemy import Column, Date, Integer, Numeric


class InventoryFlowDaily(Base):
    __tablename__ = "inventory_flow_daily"

    date = Column(Date, primary_key=True)
    item_id = Column(Integer, primary_key=True)
    in_qty = Column(Numeric(10, 3), default=Decimal("0.000"), nullable=False)
    out_qty = Column(Numeric(10, 3), default=Decimal("0.000"), nullable=False)
    net_qty = Column(Numeric(10, 3), default=Decimal("0.000"), nullable=False)

    def __repr__(self):
        return f"<InventoryFlowDaily(date={self.date}, item={self.item_id})>"
