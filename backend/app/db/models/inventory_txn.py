from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from .base_class import Base
from datetime import datetime


class InventoryTxn(Base):
    __tablename__ = "inventory_txn"

    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    batch_id = Column(Integer, ForeignKey("batch.id"), nullable=True)
    txn_type = Column(String(16), nullable=False)  # IN, OUT, ADJUST, etc.
    raw_qty = Column(Float, nullable=False)
    raw_unit = Column(String(16), nullable=False)
    base_qty = Column(Float, nullable=False)
    base_unit = Column(String(16), nullable=False)
    ref_type = Column(String(32), nullable=True)  # 'stock_entry', 'invoice_item', etc.
    ref_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    remarks = Column(String(255), nullable=True)

    item = relationship("Item")
    batch = relationship("Batch")
