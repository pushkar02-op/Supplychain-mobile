"""
Stock Depletion Forecast Model - Phase 9

Stores computed stockout forecasts for items.
Read-only with respect to core domain models.
"""

from datetime import datetime

from app.db.models.base_class import Base
from sqlalchemy import Column, Date, DateTime, Float, ForeignKey, Integer, String


class StockDepletionForecast(Base):
    __tablename__ = "stock_depletion_forecast"

    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False, unique=True)

    current_ledger_qty = Column(Float, default=0.0)
    avg_daily_outflow = Column(Float, default=0.0)

    # Computed forecast values
    days_to_zero = Column(Float, nullable=True)  # None if avg_outflow = 0
    projected_stockout_date = Column(Date, nullable=True)
    confidence_window_days = Column(Integer, default=7)
    signal = Column(
        String(20), default="STABLE"
    )  # STABLE, WATCH, REORDER_SOON, CRITICAL

    calculated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<StockDepletionForecast(item_id={self.item_id}, days_to_zero={self.days_to_zero})>"
