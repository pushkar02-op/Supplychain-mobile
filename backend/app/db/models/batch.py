from sqlalchemy import Column, Date, ForeignKey, Index, Integer, Numeric, String
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class Batch(Base, AuditMixin):
    __tablename__ = "batch"

    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False, index=True)
    quantity = Column(Numeric(18, 6, asdecimal=True), nullable=False)
    unit = Column(String, nullable=False)
    expiry_date = Column(Date, nullable=True)
    received_at = Column(Date, nullable=True)
    remarks = Column(String, nullable=True)

    # Index for faster queries on item_id and received_at
    __table_args__ = (
        Index("ix_batch_item_id", "item_id"),
        Index("ix_batch_received_at", "received_at"),
    )

    item = relationship("Item")

    @property
    def item_name(self):
        # Assumes joined load of item if needed
        return self.item.name if hasattr(self, "item") and self.item else None
