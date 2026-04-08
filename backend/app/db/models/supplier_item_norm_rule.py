"""
Supplier Item Normalization Rule.

Stores learned conversion rules that map a supplier's billing unit
to an internal stock unit (kg or ea) for a specific item.

Key: (company_name, item_code, raw_uom, suffix_pattern)
"""

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class SupplierItemNormRule(Base, AuditMixin):
    __tablename__ = "supplier_item_norm_rule"

    id = Column(Integer, primary_key=True, index=True)

    # Scope: company-level (from Mart.company_name), optional mart override
    company_name = Column(String, nullable=False, index=True)
    mart_id = Column(Integer, ForeignKey("mart.id"), nullable=True)

    # Identity keys from the bill
    item_code = Column(String, nullable=True, index=True)
    item_name_stem = Column(String, nullable=True)  # normalized name before comma
    raw_uom = Column(
        String, nullable=False
    )  # e.g. "Count", "Kilogram", "Per piece", "Pack"
    suffix_pattern = Column(
        String, nullable=True
    )  # e.g. "{N} gm", "{N} Pieces", "{N}-{N} g"

    # What this maps to
    target_item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    rule_type = Column(
        String, nullable=False
    )  # DIRECT_KG, DIRECT_EA, FIXED_WEIGHT_TO_KG, FIXED_COUNT_TO_EA, RANGE_WEIGHT_REVIEW, AMBIGUOUS_REVIEW
    rule_value = Column(
        Numeric(18, 6), nullable=True
    )  # conversion factor per billed unit (null for AMBIGUOUS)

    # Confirmation state
    confirmed = Column(Boolean, default=False, nullable=False)
    confirmed_by = Column(Integer, nullable=True)
    confirmed_at = Column(DateTime, nullable=True)

    # Warehouse scope
    warehouse_id = Column(
        Integer, ForeignKey("warehouse.id"), nullable=False, index=True
    )

    # Relationships
    mart = relationship("Mart")
    target_item = relationship("Item")
    warehouse = relationship("Warehouse")

    __table_args__ = (
        # Company-wide rules (mart_id IS NULL) are unique by these keys
        UniqueConstraint(
            "company_name",
            "item_code",
            "raw_uom",
            "suffix_pattern",
            "warehouse_id",
            name="uq_company_norm_rule",
        ),
    )
