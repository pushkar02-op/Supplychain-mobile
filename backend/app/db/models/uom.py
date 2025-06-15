from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime
from .base_class import Base
from .mixins import AuditMixin


class UOM(Base, AuditMixin):
    __tablename__ = "uom"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(10), unique=True, nullable=False)
    description = Column(Text, nullable=True)
