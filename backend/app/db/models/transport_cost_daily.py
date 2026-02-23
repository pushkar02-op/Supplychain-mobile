from datetime import datetime

from sqlalchemy import (
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from .base_class import Base


class TransportCostDaily(Base):
    __tablename__ = "transport_cost_daily"
    __table_args__ = (
        UniqueConstraint(
            "warehouse_id",
            "date",
            name="uq_transport_cost_daily_warehouse_date",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    warehouse_id = Column(
        Integer,
        ForeignKey("warehouse.id", name="fk_transport_cost_daily_warehouse_id"),
        nullable=False,
        index=True,
    )
    date = Column(Date, nullable=False, index=True)
    total_cost = Column(Numeric(18, 6), nullable=False)
    notes = Column(String, nullable=True)
    created_by = Column(
        Integer, ForeignKey("user.id", name="fk_transport_cost_daily_created_by")
    )
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    warehouse = relationship("Warehouse", back_populates="transport_cost_entries")
    creator = relationship("User")
