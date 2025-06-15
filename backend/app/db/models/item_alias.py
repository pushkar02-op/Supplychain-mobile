from sqlalchemy import Column, Integer, String, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin


class ItemAlias(Base, AuditMixin):
    __tablename__ = "item_alias"

    id = Column(Integer, primary_key=True, index=True)
    master_item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    alias_code = Column(String, nullable=True)
    alias_name = Column(String, nullable=True)

    item = relationship("Item", back_populates="aliases")
