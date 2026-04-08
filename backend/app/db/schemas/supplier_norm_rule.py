"""Pydantic schemas for Supplier Item Normalization Rules."""

from datetime import datetime
from decimal import Decimal
from typing import List, Optional

from app.db.schemas.base import SchemaModel

# --- Norm Suggestion Response (from engine) ---


class TargetItemBrief(SchemaModel):
    id: int
    name: str
    stock_uom: str  # "kg" or "ea"


class NormSuggestionItem(SchemaModel):
    """A single normalization suggestion for one bill item."""

    bill_item_id: int
    item_name: str
    item_code: Optional[str] = None
    billed_qty: Decimal
    billed_uom: str
    target_item: TargetItemBrief
    # Suggestion details
    rule_type: str  # DIRECT_KG, DIRECT_EA, FIXED_WEIGHT_TO_KG, etc.
    rule_value: Optional[Decimal] = None
    stock_qty: Optional[Decimal] = None
    stock_uom: str  # "kg" or "ea"
    source: str  # "confirmed_rule", "parser", "ambiguous"
    existing_rule_id: Optional[int] = None
    needs_confirmation: bool = True
    suffix_pattern: Optional[str] = None
    # Range info for RANGE_WEIGHT_REVIEW
    range_low_kg: Optional[Decimal] = None
    range_high_kg: Optional[Decimal] = None


class NormSuggestionsResponse(SchemaModel):
    """Response containing norm suggestions for all mapped bill items."""

    bill_id: int
    suggestions: List[NormSuggestionItem]
    auto_count: int = 0  # items with confirmed rules (no action needed)
    confirm_count: int = 0  # items needing first-time confirmation
    review_count: int = 0  # items needing review (range/ambiguous)
    manual_count: int = 0  # items that are fully ambiguous


# --- Rule Confirmation Request ---


class RuleConfirmation(SchemaModel):
    """Confirmation for a single bill item's normalization rule."""

    bill_item_id: int
    rule_type: str
    rule_value: Optional[Decimal] = None
    accepted: bool = True


class RuleConfirmationRequest(SchemaModel):
    """Batch confirmation of normalization rules."""

    bill_id: int
    rules: List[RuleConfirmation]


class RuleConfirmationResponse(SchemaModel):
    """Response from rule confirmation."""

    confirmed_count: int
    created_rules: List[int]  # IDs of newly created/updated rules


# --- Generate Stock Request/Response ---


class GenerateStockItem(SchemaModel):
    """A single stock entry that was generated."""

    bill_item_id: int
    item_name: str
    stock_entry_id: int
    stock_qty: Decimal
    stock_uom: str
    price_per_unit: Decimal
    total_cost: Decimal


class GenerateStockSkipped(SchemaModel):
    """A bill item that was skipped during stock generation."""

    bill_item_id: int
    item_name: str
    reason: str


class GenerateStockResponse(SchemaModel):
    """Response from generating stock entries from a bill."""

    bill_id: int
    created: List[GenerateStockItem]
    skipped: List[GenerateStockSkipped]
    total_created: int
    total_skipped: int


# --- Rule Read (for admin/management) ---


class SupplierNormRuleRead(SchemaModel):
    id: int
    company_name: str
    mart_id: Optional[int] = None
    item_code: Optional[str] = None
    item_name_stem: Optional[str] = None
    raw_uom: str
    suffix_pattern: Optional[str] = None
    target_item_id: int
    rule_type: str
    rule_value: Optional[Decimal] = None
    confirmed: bool
    confirmed_by: Optional[int] = None
    confirmed_at: Optional[datetime] = None
    warehouse_id: int
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
