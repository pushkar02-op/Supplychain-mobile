from sqlalchemy import Column, Integer, Float, ForeignKey, String
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin


class ItemConversionMap(Base, AuditMixin):
    __tablename__ = "item_conversion_map"

    id = Column(Integer, primary_key=True, index=True)
    source_item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    target_item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    conversion_factor = Column(
        Float, nullable=False
    )  # how many source units = 1 target unit
    source_unit = Column(String, nullable=False)
    target_unit = Column(String, nullable=False)

    source_item = relationship("Item", foreign_keys=[source_item_id])
    target_item = relationship("Item", foreign_keys=[target_item_id])
