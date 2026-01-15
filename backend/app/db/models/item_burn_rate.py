"""
Item Burn Rate Model - Phase 9

Stores computed daily outflow averages for forecasting.
Read-only with respect to core domain models.
"""

from datetime import datetime

from app.db.models.base_class import Base
from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer


class ItemBurnRate(Base):
    __tablename__ = "item_burn_rate"

    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False, unique=True)

    # Average daily outflow over different windows
    avg_daily_outflow_7d = Column(Float, default=0.0)
    avg_daily_outflow_14d = Column(Float, default=0.0)
    avg_daily_outflow_30d = Column(Float, default=0.0)

    calculated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<ItemBurnRate(item_id={self.item_id}, 7d={self.avg_daily_outflow_7d})>"
