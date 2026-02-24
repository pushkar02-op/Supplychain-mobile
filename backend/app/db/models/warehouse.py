from datetime import datetime

from sqlalchemy import Boolean, Column, Date, DateTime, Integer, String
from sqlalchemy.orm import relationship

from .base_class import Base


class Warehouse(Base):
    __tablename__ = "warehouse"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    code = Column(String, unique=True, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    financial_lock_date = Column(Date, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    labour_cost_entries = relationship(
        "LabourCostDaily",
        back_populates="warehouse",
        cascade="all, delete-orphan",
    )
    transport_cost_entries = relationship(
        "TransportCostDaily",
        back_populates="warehouse",
        cascade="all, delete-orphan",
    )
