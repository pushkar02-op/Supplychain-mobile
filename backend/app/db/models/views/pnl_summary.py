from sqlalchemy import Column, Date, Numeric

from ..base_class import Base


class PnlSummary(Base):
    __tablename__ = "pnl_summary"
    __table_args__ = {"extend_existing": True}

    date = Column(Date, primary_key=True)
    total_purchase = Column(Numeric(18, 6))
    total_sales = Column(Numeric(18, 6))
    profit = Column(Numeric(18, 6))
