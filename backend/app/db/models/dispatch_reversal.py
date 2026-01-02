from datetime import datetime

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from .base_class import Base


class DispatchReversal(Base):
    __tablename__ = "dispatch_reversal"

    id = Column(Integer, primary_key=True, index=True)
    dispatch_entry_id = Column(Integer, ForeignKey("dispatch_entry.id"), nullable=False)
    quantity = Column(Float, nullable=False)
    reason = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_by = Column(String, nullable=True)

    dispatch_entry = relationship("DispatchEntry", backref="reversals")
