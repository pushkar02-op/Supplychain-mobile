from app.db.models.base_class import Base
from sqlalchemy import Column, Integer, Numeric


class InventorySignal(Base):
    __tablename__ = "inventory_signal_view"
    __table_args__ = {"info": {"is_view": True}}

    warehouse_id = Column(Integer, primary_key=True)
    item_id = Column(Integer, primary_key=True)
    out_last_7d = Column(Numeric(10, 3))
    out_prev_7d = Column(Numeric(10, 3))

    def __repr__(self):
        return (
            f"<InventorySignal(item_id={self.item_id}, out_last_7d={self.out_last_7d})>"
        )
