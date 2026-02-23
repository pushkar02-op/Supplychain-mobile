from sqlalchemy import Column, Date, Integer, Numeric, String

from ..base_class import Base


class PnlSummary(Base):
    __tablename__ = "pnl_summary"
    __table_args__ = {"extend_existing": True}

    warehouse_id = Column(Integer, primary_key=True)
    mart_id = Column(Integer, primary_key=True)
    mart_name = Column(String)
    date = Column(Date, primary_key=True)
    total_purchase = Column(Numeric(18, 6))
    total_sales = Column(Numeric(18, 6))
    profit = Column(Numeric(18, 6))
