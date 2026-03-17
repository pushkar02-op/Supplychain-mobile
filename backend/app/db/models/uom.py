from sqlalchemy import Boolean, Column, Integer, String, Text
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class UOM(Base, AuditMixin):
    __tablename__ = "uom"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(10), unique=True, nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    default_for_items = relationship("Item", back_populates="default_uom")
