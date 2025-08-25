from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class Item(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    item_code = Column(String, unique=False, nullable=True)
    default_uom_id = Column(Integer, ForeignKey("uom.id"), nullable=True)
    aliases = relationship(
        "ItemAlias", back_populates="item", cascade="all, delete-orphan"
    )
    default_uom = relationship("UOM", back_populates="default_for_items")

    conversions = relationship(
        "ItemConversionMap",
        back_populates="item",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    @property
    def default_uom_code(self) -> str | None:
        """Provides direct access to the UOM code for Pydantic."""
        return self.default_uom.code if self.default_uom else None
