from sqlalchemy import Column, Date, Float, Integer
from .base_class import Base
from .mixins import AuditMixin

class DailySummary(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, unique=True, nullable=False)
    total_purchase = Column(Float, default=0.0)
    total_sales = Column(Float, default=0.0)
    labor_cost = Column(Float, default=0.0)
    other_cost = Column(Float, default=0.0)
    profit = Column(Float, default=0.0)
