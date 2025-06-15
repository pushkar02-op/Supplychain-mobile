from sqlalchemy import Column, ForeignKey, Integer, String
from .base_class import Base
from .mixins import AuditMixin
from sqlalchemy.orm import relationship


class Item(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    item_code = Column(String, unique=False, nullable=True)
    default_uom_id = Column(Integer, ForeignKey("uom.id"), nullable=True)
    aliases = relationship(
        "ItemAlias", back_populates="item", cascade="all, delete-orphan"
    )
    default_uom = relationship("UOM")
