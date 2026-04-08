"""
Unit tests for the normalization rule engine.

Tests the decision matrix that maps (billing_hint, suffix, item_stock_uom)
to a rule_type and rule_value.

These are pure-function tests that don't need a database.
"""

from decimal import Decimal

import pytest

from app.services.norm_rule_engine import (
    NormSuggestion,
    RuleType,
    SuggestionSource,
    _determine_rule_from_parser,
)
from app.services.suffix_parser import PatternType, SuffixParseResult


def _make_suffix(
    pattern_type: PatternType,
    parsed_value=None,
    parsed_unit=None,
    range_low_kg=None,
    range_high_kg=None,
    suffix_pattern=None,
) -> SuffixParseResult:
    """Helper to create a SuffixParseResult for testing."""
    return SuffixParseResult(
        pattern_type=pattern_type,
        parsed_value=parsed_value,
        parsed_unit=parsed_unit,
        range_low_kg=range_low_kg,
        range_high_kg=range_high_kg,
        suffix_pattern=suffix_pattern,
        raw_suffix="test",
    )


# ── DIRECT_KG (Kilogram billing) ─────────────────────────────────────


class TestDirectKg:
    def test_kilogram_uom_with_kg_stock(self):
        """Kilogram billing + KG stock → DIRECT_KG"""
        suffix = _make_suffix(PatternType.NONE)
        result = _determine_rule_from_parser(
            billing_hint="weight",
            raw_uom="Kilogram",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.DIRECT_KG
        assert result.rule_value == Decimal("1.0")
        assert result.stock_uom == "kg"
        assert result.needs_confirmation == False

    def test_kilogram_uom_with_ea_stock(self):
        """Kilogram billing + EA stock → AMBIGUOUS (can't convert kg to ea from bill)"""
        suffix = _make_suffix(PatternType.NONE)
        result = _determine_rule_from_parser(
            billing_hint="weight",
            raw_uom="Kilogram",
            suffix=suffix,
            item_stock_uom="ea",
        )
        assert result.rule_type == RuleType.AMBIGUOUS_REVIEW
        assert result.stock_uom == "ea"


# ── FIXED_WEIGHT_TO_KG ───────────────────────────────────────────────


class TestFixedWeightToKg:
    def test_500gm_to_kg(self):
        """Count + 500gm suffix + KG stock → FIXED_WEIGHT_TO_KG, 0.5"""
        suffix = _make_suffix(
            PatternType.FIXED_WEIGHT,
            parsed_value=Decimal("0.5"),
            parsed_unit="kg",
            suffix_pattern="{N} gm",
        )
        result = _determine_rule_from_parser(
            billing_hint="count",
            raw_uom="Count",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.FIXED_WEIGHT_TO_KG
        assert result.rule_value == Decimal("0.5")
        assert result.stock_uom == "kg"

    def test_1kg_to_kg(self):
        """Count + 1 Kg suffix + KG stock → FIXED_WEIGHT_TO_KG, 1.0"""
        suffix = _make_suffix(
            PatternType.FIXED_WEIGHT,
            parsed_value=Decimal("1.0"),
            parsed_unit="kg",
            suffix_pattern="{N} kg",
        )
        result = _determine_rule_from_parser(
            billing_hint="count",
            raw_uom="Count",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.FIXED_WEIGHT_TO_KG
        assert result.rule_value == Decimal("1.0")

    def test_250gm_pack_to_kg(self):
        """Pack + 250gm suffix + KG stock → FIXED_WEIGHT_TO_KG, 0.25"""
        suffix = _make_suffix(
            PatternType.FIXED_WEIGHT,
            parsed_value=Decimal("0.25"),
            parsed_unit="kg",
            suffix_pattern="{N} gm",
        )
        result = _determine_rule_from_parser(
            billing_hint="composite",
            raw_uom="Pack",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.FIXED_WEIGHT_TO_KG
        assert result.rule_value == Decimal("0.25")

    def test_fixed_weight_with_ea_stock(self):
        """Count + weight suffix + EA stock → DIRECT_EA (weight is informational)"""
        suffix = _make_suffix(
            PatternType.FIXED_WEIGHT,
            parsed_value=Decimal("0.5"),
            parsed_unit="kg",
        )
        result = _determine_rule_from_parser(
            billing_hint="count",
            raw_uom="Count",
            suffix=suffix,
            item_stock_uom="ea",
        )
        assert result.rule_type == RuleType.DIRECT_EA
        assert result.rule_value == Decimal("1.0")


# ── FIXED_COUNT_TO_EA ─────────────────────────────────────────────────


class TestFixedCountToEa:
    def test_3_pieces_to_ea(self):
        """Pack + 3 Pieces suffix + EA stock → FIXED_COUNT_TO_EA, 3"""
        suffix = _make_suffix(
            PatternType.FIXED_COUNT,
            parsed_value=Decimal("3"),
            parsed_unit="ea",
            suffix_pattern="{N} Pieces",
        )
        result = _determine_rule_from_parser(
            billing_hint="composite",
            raw_uom="Pack",
            suffix=suffix,
            item_stock_uom="ea",
        )
        assert result.rule_type == RuleType.FIXED_COUNT_TO_EA
        assert result.rule_value == Decimal("3")

    def test_5_units_to_ea(self):
        """Per piece + 5 Units suffix + EA stock → FIXED_COUNT_TO_EA, 5"""
        suffix = _make_suffix(
            PatternType.FIXED_COUNT,
            parsed_value=Decimal("5"),
            parsed_unit="ea",
            suffix_pattern="{N} Units",
        )
        result = _determine_rule_from_parser(
            billing_hint="count",
            raw_uom="Per piece",
            suffix=suffix,
            item_stock_uom="ea",
        )
        assert result.rule_type == RuleType.FIXED_COUNT_TO_EA
        assert result.rule_value == Decimal("5")

    def test_count_suffix_with_kg_stock(self):
        """Count + count suffix + KG stock → AMBIGUOUS (can't derive weight from count)"""
        suffix = _make_suffix(
            PatternType.FIXED_COUNT,
            parsed_value=Decimal("3"),
            parsed_unit="ea",
        )
        result = _determine_rule_from_parser(
            billing_hint="count",
            raw_uom="Count",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.AMBIGUOUS_REVIEW


# ── RANGE_WEIGHT_REVIEW ──────────────────────────────────────────────


class TestRangeWeightReview:
    def test_200_250g_with_kg_stock(self):
        """Pack + 200-250g range + KG stock → RANGE_WEIGHT_REVIEW"""
        suffix = _make_suffix(
            PatternType.RANGE_WEIGHT,
            parsed_value=Decimal("0.225"),
            parsed_unit="kg",
            range_low_kg=Decimal("0.2"),
            range_high_kg=Decimal("0.25"),
            suffix_pattern="{N}-{N} gm",
        )
        result = _determine_rule_from_parser(
            billing_hint="composite",
            raw_uom="Pack",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.RANGE_WEIGHT_REVIEW
        assert result.rule_value == Decimal("0.225")
        assert result.needs_confirmation == True

    def test_range_with_ea_stock(self):
        """Pack + range weight + EA stock → DIRECT_EA"""
        suffix = _make_suffix(
            PatternType.RANGE_WEIGHT,
            parsed_value=Decimal("0.225"),
            parsed_unit="kg",
            range_low_kg=Decimal("0.2"),
            range_high_kg=Decimal("0.25"),
        )
        result = _determine_rule_from_parser(
            billing_hint="composite",
            raw_uom="Pack",
            suffix=suffix,
            item_stock_uom="ea",
        )
        assert result.rule_type == RuleType.DIRECT_EA
        assert result.rule_value == Decimal("1.0")


# ── COMPOUND_RANGE ────────────────────────────────────────────────────


class TestCompoundRange:
    def test_1_piece_150_200gm_ea_stock(self):
        """Pack + 1 Piece (150-200 gm) + EA stock → DIRECT_EA, 1"""
        suffix = _make_suffix(
            PatternType.COMPOUND_RANGE,
            parsed_value=Decimal("1"),  # piece count
            parsed_unit="ea",
            range_low_kg=Decimal("0.15"),
            range_high_kg=Decimal("0.2"),
        )
        result = _determine_rule_from_parser(
            billing_hint="composite",
            raw_uom="Pack",
            suffix=suffix,
            item_stock_uom="ea",
        )
        assert result.rule_type == RuleType.DIRECT_EA
        assert result.rule_value == Decimal("1")

    def test_1_piece_150_200gm_kg_stock(self):
        """Pack + 1 Piece (150-200 gm) + KG stock → RANGE_WEIGHT_REVIEW, ~0.175"""
        suffix = _make_suffix(
            PatternType.COMPOUND_RANGE,
            parsed_value=Decimal("1"),
            parsed_unit="ea",
            range_low_kg=Decimal("0.15"),
            range_high_kg=Decimal("0.2"),
        )
        result = _determine_rule_from_parser(
            billing_hint="composite",
            raw_uom="Pack",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.RANGE_WEIGHT_REVIEW
        assert result.rule_value == Decimal("0.175")


# ── DIRECT_EA (no suffix, count billing) ──────────────────────────────


class TestDirectEa:
    def test_per_piece_no_suffix_ea_stock(self):
        """Per piece + no suffix + EA stock → DIRECT_EA, 1"""
        suffix = _make_suffix(PatternType.NONE)
        result = _determine_rule_from_parser(
            billing_hint="count",
            raw_uom="Per piece",
            suffix=suffix,
            item_stock_uom="ea",
        )
        assert result.rule_type == RuleType.DIRECT_EA
        assert result.rule_value == Decimal("1.0")


# ── AMBIGUOUS_REVIEW (fallback) ───────────────────────────────────────


class TestAmbiguousReview:
    def test_count_no_suffix_kg_stock(self):
        """Count + no suffix + KG stock → AMBIGUOUS (can't determine weight)"""
        suffix = _make_suffix(PatternType.NONE)
        result = _determine_rule_from_parser(
            billing_hint="count",
            raw_uom="Count",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.AMBIGUOUS_REVIEW
        assert result.rule_value is None

    def test_composite_no_suffix_kg_stock(self):
        """Pack + no suffix + KG stock → AMBIGUOUS"""
        suffix = _make_suffix(PatternType.NONE)
        result = _determine_rule_from_parser(
            billing_hint="composite",
            raw_uom="Pack",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.AMBIGUOUS_REVIEW

    def test_no_billing_hint(self):
        """Unknown UOM + no suffix → AMBIGUOUS"""
        suffix = _make_suffix(PatternType.NONE)
        result = _determine_rule_from_parser(
            billing_hint=None,
            raw_uom="Unknown",
            suffix=suffix,
            item_stock_uom="kg",
        )
        assert result.rule_type == RuleType.AMBIGUOUS_REVIEW
