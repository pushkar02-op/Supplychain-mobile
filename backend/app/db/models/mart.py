from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class Mart(Base, AuditMixin):
    __tablename__ = "mart"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    company_name = Column(String, nullable=False)

    orders = relationship("Order", back_populates="mart")
