from sqlalchemy import Column, Date, Float
from ..base_class import Base


class PnlSummary(Base):
    __tablename__ = "pnl_summary"
    __table_args__ = {"extend_existing": True}

    date = Column(Date, primary_key=True)
    total_purchase = Column(Float)
    total_sales = Column(Float)
    profit = Column(Float)
