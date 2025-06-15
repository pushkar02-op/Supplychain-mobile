from sqlalchemy import Column, Integer, String, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin


class ItemAlias(Base, AuditMixin):
    __tablename__ = "item_alias"
    __table_args__ = (
        UniqueConstraint("alias_code", "alias_name", name="uq_alias_code_name"),
    )

    id = Column(Integer, primary_key=True, index=True)
    master_item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    alias_code = Column(String, nullable=True)
    alias_name = Column(String, nullable=True)
    alias_unit = Column(String, nullable=True)

    master_item = relationship("Item", back_populates="aliases")
