"""
Normalization Rule Engine.

Takes a MartBillItem + resolved Item + format_type and produces
a normalization suggestion that converts billed units to stock units (kg or ea).

Resolution order:
1. Look up confirmed rule by (company, item_code, raw_uom, suffix_pattern)
2. Look up confirmed rule by (company, item_code, raw_uom) without suffix
3. Run suffix parser + combine with item's stock unit
4. Fall through to AMBIGUOUS_REVIEW

Output is ALWAYS kg or ea — no other internal units.
"""

import logging
from dataclasses import dataclass
from decimal import Decimal
from enum import Enum
from typing import Optional

from app.db.models.raw_uom_map import RawUomMap
from app.db.models.supplier_item_norm_rule import SupplierItemNormRule
from app.services.suffix_parser import PatternType, SuffixParseResult, parse_suffix
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


class RuleType(str, Enum):
    DIRECT_KG = "DIRECT_KG"
    DIRECT_EA = "DIRECT_EA"
    FIXED_WEIGHT_TO_KG = "FIXED_WEIGHT_TO_KG"
    FIXED_COUNT_TO_EA = "FIXED_COUNT_TO_EA"
    RANGE_WEIGHT_REVIEW = "RANGE_WEIGHT_REVIEW"
    AMBIGUOUS_REVIEW = "AMBIGUOUS_REVIEW"


class SuggestionSource(str, Enum):
    CONFIRMED_RULE = "confirmed_rule"
    PARSER = "parser"
    AMBIGUOUS = "ambiguous"


@dataclass
class NormSuggestion:
    """A normalization suggestion for a bill item."""

    rule_type: RuleType
    rule_value: Optional[
        Decimal
    ]  # conversion factor per billed unit (null for AMBIGUOUS)
    stock_uom: str  # "kg" or "ea"
    stock_qty: Optional[Decimal]  # computed: billed_qty * rule_value
    source: SuggestionSource
    existing_rule_id: Optional[int] = None
    needs_confirmation: bool = True
    suffix_pattern: Optional[str] = None
    # For range types: the range bounds
    range_low_kg: Optional[Decimal] = None
    range_high_kg: Optional[Decimal] = None


def _get_billing_hint(db: Session, format_type: str, raw_uom: str) -> Optional[str]:
    """Look up the billing hint for a raw UOM text."""
    row = (
        db.query(RawUomMap)
        .filter(
            RawUomMap.format_type == format_type.lower(),
            RawUomMap.raw_uom_text == raw_uom,
        )
        .first()
    )
    return row.billing_hint if row else None


def _lookup_confirmed_rule(
    db: Session,
    company_name: str,
    item_code: Optional[str],
    raw_uom: str,
    suffix_pattern: Optional[str],
    warehouse_id: int,
) -> Optional[SupplierItemNormRule]:
    """Look up an existing confirmed rule.

    Priority:
    1. Exact match: (company, item_code, raw_uom, suffix_pattern)
    2. Broad match: (company, item_code, raw_uom) without suffix
    """
    if item_code:
        # Priority 1: Exact match with suffix pattern
        if suffix_pattern:
            rule = (
                db.query(SupplierItemNormRule)
                .filter(
                    SupplierItemNormRule.company_name == company_name,
                    SupplierItemNormRule.item_code == item_code,
                    SupplierItemNormRule.raw_uom == raw_uom,
                    SupplierItemNormRule.suffix_pattern == suffix_pattern,
                    SupplierItemNormRule.warehouse_id == warehouse_id,
                    SupplierItemNormRule.confirmed == True,  # noqa: E712
                )
                .first()
            )
            if rule:
                return rule

        # Priority 2: Match without suffix pattern
        rule = (
            db.query(SupplierItemNormRule)
            .filter(
                SupplierItemNormRule.company_name == company_name,
                SupplierItemNormRule.item_code == item_code,
                SupplierItemNormRule.raw_uom == raw_uom,
                SupplierItemNormRule.warehouse_id == warehouse_id,
                SupplierItemNormRule.confirmed == True,  # noqa: E712
            )
            .first()
        )
        if rule:
            return rule

    return None


def _determine_rule_from_parser(
    billing_hint: Optional[str],
    raw_uom: str,
    suffix: SuffixParseResult,
    item_stock_uom: str,
) -> NormSuggestion:
    """Determine the normalization rule from parser results + item stock unit.

    This is the core decision matrix that maps:
    (billing_hint, suffix_pattern_type, item_stock_uom) → (rule_type, rule_value, stock_uom)
    """

    # Case 1: Billing hint is "weight" (raw UOM is Kilogram)
    # Bill qty is already in kg → DIRECT_KG
    if billing_hint == "weight":
        if item_stock_uom == "kg":
            return NormSuggestion(
                rule_type=RuleType.DIRECT_KG,
                rule_value=Decimal("1.0"),
                stock_uom="kg",
                stock_qty=None,  # computed by caller
                source=SuggestionSource.PARSER,
                needs_confirmation=False,  # Direct mapping, no ambiguity
                suffix_pattern=suffix.suffix_pattern,
            )
        else:
            # Bill is in KG but item stocks in EA — need kg→ea conversion
            # This is AMBIGUOUS because we don't know pieces per kg from the bill
            return NormSuggestion(
                rule_type=RuleType.AMBIGUOUS_REVIEW,
                rule_value=None,
                stock_uom="ea",
                stock_qty=None,
                source=SuggestionSource.AMBIGUOUS,
                needs_confirmation=True,
                suffix_pattern=suffix.suffix_pattern,
            )

    # Case 2: Suffix has a fixed weight (e.g., "500 gm", "1 Kg")
    if suffix.pattern_type == PatternType.FIXED_WEIGHT:
        if item_stock_uom == "kg":
            return NormSuggestion(
                rule_type=RuleType.FIXED_WEIGHT_TO_KG,
                rule_value=suffix.parsed_value,  # already in kg
                stock_uom="kg",
                stock_qty=None,
                source=SuggestionSource.PARSER,
                needs_confirmation=True,  # First time: confirm
                suffix_pattern=suffix.suffix_pattern,
            )
        else:
            # Suffix has weight but item stocks in EA
            # The suffix weight is informational; 1 billed unit = 1 ea typically
            return NormSuggestion(
                rule_type=RuleType.DIRECT_EA,
                rule_value=Decimal("1.0"),
                stock_uom="ea",
                stock_qty=None,
                source=SuggestionSource.PARSER,
                needs_confirmation=True,
                suffix_pattern=suffix.suffix_pattern,
            )

    # Case 3: Suffix has a fixed count (e.g., "3 Pieces", "5 Units")
    if suffix.pattern_type == PatternType.FIXED_COUNT:
        if item_stock_uom == "ea":
            return NormSuggestion(
                rule_type=RuleType.FIXED_COUNT_TO_EA,
                rule_value=suffix.parsed_value,  # count per billed unit
                stock_uom="ea",
                stock_qty=None,
                source=SuggestionSource.PARSER,
                needs_confirmation=True,
                suffix_pattern=suffix.suffix_pattern,
            )
        else:
            # Suffix has count but item stocks in KG
            # Can't determine weight from count alone → AMBIGUOUS
            return NormSuggestion(
                rule_type=RuleType.AMBIGUOUS_REVIEW,
                rule_value=None,
                stock_uom="kg",
                stock_qty=None,
                source=SuggestionSource.AMBIGUOUS,
                needs_confirmation=True,
                suffix_pattern=suffix.suffix_pattern,
            )

    # Case 4: Suffix has a weight range (e.g., "200-250 g")
    if suffix.pattern_type == PatternType.RANGE_WEIGHT:
        if item_stock_uom == "kg":
            return NormSuggestion(
                rule_type=RuleType.RANGE_WEIGHT_REVIEW,
                rule_value=suffix.parsed_value,  # midpoint in kg
                stock_uom="kg",
                stock_qty=None,
                source=SuggestionSource.PARSER,
                needs_confirmation=True,  # Always confirm ranges
                suffix_pattern=suffix.suffix_pattern,
                range_low_kg=suffix.range_low_kg,
                range_high_kg=suffix.range_high_kg,
            )
        else:
            # Range weight but item stocks in EA → 1 pack = 1 ea
            return NormSuggestion(
                rule_type=RuleType.DIRECT_EA,
                rule_value=Decimal("1.0"),
                stock_uom="ea",
                stock_qty=None,
                source=SuggestionSource.PARSER,
                needs_confirmation=True,
                suffix_pattern=suffix.suffix_pattern,
            )

    # Case 5: Compound range (e.g., "1 Piece (150-200 gm)")
    if suffix.pattern_type == PatternType.COMPOUND_RANGE:
        if item_stock_uom == "ea":
            # Use the piece count from the compound pattern
            return NormSuggestion(
                rule_type=RuleType.DIRECT_EA,
                rule_value=suffix.parsed_value,  # piece count
                stock_uom="ea",
                stock_qty=None,
                source=SuggestionSource.PARSER,
                needs_confirmation=True,
                suffix_pattern=suffix.suffix_pattern,
            )
        else:
            # Item stocks in KG, and we have a weight range
            midpoint = (
                (suffix.range_low_kg + suffix.range_high_kg) / Decimal("2")
                if suffix.range_low_kg and suffix.range_high_kg
                else None
            )
            # Multiply by piece count if > 1
            piece_count = suffix.parsed_value or Decimal("1")
            total_midpoint = midpoint * piece_count if midpoint else None
            return NormSuggestion(
                rule_type=RuleType.RANGE_WEIGHT_REVIEW,
                rule_value=total_midpoint,
                stock_uom="kg",
                stock_qty=None,
                source=SuggestionSource.PARSER,
                needs_confirmation=True,
                suffix_pattern=suffix.suffix_pattern,
                range_low_kg=(
                    suffix.range_low_kg * piece_count if suffix.range_low_kg else None
                ),
                range_high_kg=(
                    suffix.range_high_kg * piece_count if suffix.range_high_kg else None
                ),
            )

    # Case 6: No suffix pattern matched
    # Check if the billing hint + raw UOM gives us enough info
    if billing_hint == "count" and item_stock_uom == "ea":
        # "Per piece" or "Count" with no suffix → likely 1 billed unit = 1 ea
        # But only if no weight info was expected
        return NormSuggestion(
            rule_type=RuleType.DIRECT_EA,
            rule_value=Decimal("1.0"),
            stock_uom="ea",
            stock_qty=None,
            source=SuggestionSource.PARSER,
            needs_confirmation=True,
            suffix_pattern=None,
        )

    # Fallback: AMBIGUOUS_REVIEW
    return NormSuggestion(
        rule_type=RuleType.AMBIGUOUS_REVIEW,
        rule_value=None,
        stock_uom=item_stock_uom,
        stock_qty=None,
        source=SuggestionSource.AMBIGUOUS,
        needs_confirmation=True,
        suffix_pattern=None,
    )


def suggest_normalization(
    db: Session,
    item_name: str,
    item_code: Optional[str],
    raw_uom: str,
    billed_qty: Decimal,
    target_item_id: int,
    target_item_stock_uom: str,
    company_name: str,
    warehouse_id: int,
    format_type: str = "zomato",
) -> NormSuggestion:
    """Generate a normalization suggestion for a bill item.

    Resolution order:
    1. Look up confirmed rule by (company, item_code, raw_uom, suffix_pattern)
    2. Look up confirmed rule by (company, item_code, raw_uom) without suffix
    3. Run suffix parser + combine with item's stock unit
    4. Fall through to AMBIGUOUS_REVIEW

    Args:
        db: Database session
        item_name: Full item name from bill (e.g., "BH - Garlic, 500 gm")
        item_code: Item code from bill (e.g., "CCF6184E")
        raw_uom: Raw UOM text from bill (e.g., "Count", "Kilogram")
        billed_qty: Quantity from the bill
        target_item_id: Resolved master item ID
        target_item_stock_uom: The item's default_uom_code (e.g., "kg", "ea")
        company_name: Supplier company name (from Mart.company_name)
        warehouse_id: Warehouse scope
        format_type: Parser format (e.g., "zomato")

    Returns:
        NormSuggestion with the suggested rule and computed stock quantity.
    """
    # Step 1: Parse suffix first (needed for rule lookup key)
    suffix = parse_suffix(item_name, format_type)

    # Step 2: Look up existing confirmed rule
    existing_rule = _lookup_confirmed_rule(
        db,
        company_name=company_name,
        item_code=item_code,
        raw_uom=raw_uom,
        suffix_pattern=suffix.suffix_pattern,
        warehouse_id=warehouse_id,
    )

    if existing_rule and existing_rule.confirmed:
        rule_value = (
            Decimal(str(existing_rule.rule_value))
            if existing_rule.rule_value is not None
            else None
        )
        stock_qty = billed_qty * rule_value if rule_value is not None else None
        stock_uom = (
            "kg"
            if existing_rule.rule_type
            in (
                RuleType.DIRECT_KG,
                RuleType.FIXED_WEIGHT_TO_KG,
                RuleType.RANGE_WEIGHT_REVIEW,
            )
            else "ea"
        )

        return NormSuggestion(
            rule_type=RuleType(existing_rule.rule_type),
            rule_value=rule_value,
            stock_uom=stock_uom,
            stock_qty=stock_qty,
            source=SuggestionSource.CONFIRMED_RULE,
            existing_rule_id=existing_rule.id,
            needs_confirmation=False,  # Already confirmed!
            suffix_pattern=existing_rule.suffix_pattern,
        )

    # Step 3: Get billing hint from raw_uom_map
    billing_hint = _get_billing_hint(db, format_type, raw_uom)

    # Step 4: Determine rule from parser + item stock unit
    suggestion = _determine_rule_from_parser(
        billing_hint=billing_hint,
        raw_uom=raw_uom,
        suffix=suffix,
        item_stock_uom=target_item_stock_uom,
    )

    # Step 5: Compute stock_qty if we have a rule_value
    if suggestion.rule_value is not None:
        suggestion.stock_qty = billed_qty * suggestion.rule_value

    return suggestion
