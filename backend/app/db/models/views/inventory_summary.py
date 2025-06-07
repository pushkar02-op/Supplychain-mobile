from sqlalchemy import Column, Integer, String, Float
from ..base_class import Base


class InventorySummary(Base):
    __tablename__ = "inventory_summary"
    __table_args__ = {"extend_existing": True}

    item_id = Column(Integer, primary_key=True)
    item_name = Column(String)
    unit = Column(String)
    available_quantity = Column(Float)
