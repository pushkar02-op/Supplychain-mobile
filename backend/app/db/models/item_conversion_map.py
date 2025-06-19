from sqlalchemy import Column, Integer, Float, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin


class ItemConversionMap(Base, AuditMixin):
    __tablename__ = "item_conversion_map"
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    source_unit = Column(String, nullable=False)
    target_unit = Column(String, nullable=False)
    conversion_factor = Column(Float, nullable=False)
    __table_args__ = (
        UniqueConstraint(
            "item_id", "source_unit", "target_unit", name="uq_item_unit_conversion"
        ),
    )
