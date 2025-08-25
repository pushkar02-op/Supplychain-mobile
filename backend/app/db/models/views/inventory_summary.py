from sqlalchemy import Column, Float, Integer, String

from ..base_class import Base


class InventorySummary(Base):
    __tablename__ = "inventory_summary"
    __table_args__ = {"extend_existing": True}

    item_id = Column(Integer, primary_key=True)
    name = Column(String)
    unit = Column(String)
    current_stock = Column(Float)
