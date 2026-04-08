"""
Raw UOM Map.

Maps supplier-specific UOM text (e.g. "Kilogram", "Per piece")
to a billing hint that guides the normalization rule engine.

Only 2 internal stock UOMs exist: kg and ea.
"Pack" and "Count" are billing-only units whose actual meaning
is determined by parsing the item name suffix.
"""

from sqlalchemy import Column, Integer, String, UniqueConstraint

from .base_class import Base


class RawUomMap(Base):
    __tablename__ = "raw_uom_map"

    id = Column(Integer, primary_key=True, index=True)
    format_type = Column(String, nullable=False)  # "zomato", "reliance"
    raw_uom_text = Column(
        String, nullable=False
    )  # "Kilogram", "Per piece", "Count", "Pack"
    billing_hint = Column(String, nullable=False)  # "weight" | "count" | "composite"

    __table_args__ = (
        UniqueConstraint("format_type", "raw_uom_text", name="uq_format_raw_uom"),
    )
