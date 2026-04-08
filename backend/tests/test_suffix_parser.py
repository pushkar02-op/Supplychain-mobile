"""
Unit tests for the suffix parser service.

Tests all regex patterns with real item names from the Zomato bill format.
The suffix parser extracts weight, count, and range information from item name suffixes.
"""

from decimal import Decimal

import pytest

from app.services.suffix_parser import (
    PatternType,
    SuffixParseResult,
    extract_item_name_stem,
    extract_suffix,
    parse_suffix,
)


# ── Suffix extraction ─────────────────────────────────────────────────


class TestExtractSuffix:
    def test_standard_comma_suffix(self):
        assert extract_suffix("BH - Garlic, 500 gm") == "500 gm"

    def test_with_spaces(self):
        assert extract_suffix("BH-Banana , 3 Pieces") == "3 Pieces"

    def test_complex_suffix(self):
        result = extract_suffix("BH-Avocado Hass - Tanzania, 1 Piece (150 - 200 gm)")
        assert result == "1 Piece (150 - 200 gm)"

    def test_no_comma(self):
        assert extract_suffix("BH - Tomato") == ""

    def test_multiple_commas(self):
        # Should split on first comma only
        assert extract_suffix("BH - Item, 500 gm, extra") == "500 gm, extra"


class TestExtractItemNameStem:
    def test_standard(self):
        assert extract_item_name_stem("BH - Garlic, 500 gm") == "bh - garlic"

    def test_with_spaces(self):
        assert extract_item_name_stem("BH-Banana , 3 Pieces") == "bh-banana"

    def test_no_comma(self):
        assert extract_item_name_stem("BH - Tomato") == "bh - tomato"


# ── Fixed weight patterns ─────────────────────────────────────────────


class TestFixedWeight:
    def test_grams_500(self):
        result = parse_suffix("BH - Garlic, 500 gm")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("0.500000")
        assert result.parsed_unit == "kg"
        assert result.suffix_pattern == "{N} gm"

    def test_grams_100(self):
        result = parse_suffix("BH-Garlic, 100 gm")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("0.100000")

    def test_grams_250(self):
        result = parse_suffix("BH - Fresh Amla, 250 gm")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("0.250000")

    def test_kg_1(self):
        result = parse_suffix("BH - Onion, 1 Kg")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("1.000000")
        assert result.parsed_unit == "kg"
        assert result.suffix_pattern == "{N} kg"

    def test_grams_g_variant(self):
        result = parse_suffix("BH - Something, 300 g")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("0.300000")

    def test_grams_gms_variant(self):
        result = parse_suffix("BH - Something, 200 gms")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("0.200000")


# ── Fixed count patterns ──────────────────────────────────────────────


class TestFixedCount:
    def test_3_pieces(self):
        result = parse_suffix("BH-Banana , 3 Pieces")
        assert result.pattern_type == PatternType.FIXED_COUNT
        assert result.parsed_value == Decimal("3")
        assert result.parsed_unit == "ea"
        assert result.suffix_pattern == "{N} Pieces"

    def test_5_units(self):
        result = parse_suffix("BH - Betel Leaves, 5 Units")
        assert result.pattern_type == PatternType.FIXED_COUNT
        assert result.parsed_value == Decimal("5")
        assert result.parsed_unit == "ea"
        assert result.suffix_pattern == "{N} Units"

    def test_1_piece(self):
        result = parse_suffix("BH - Muskmelon, 1 Piece")
        assert result.pattern_type == PatternType.FIXED_COUNT
        assert result.parsed_value == Decimal("1")


# ── Range weight patterns ─────────────────────────────────────────────


class TestRangeWeight:
    def test_200_250_g(self):
        result = parse_suffix("BH - Red Globe Grapes , 200 - 250 g")
        assert result.pattern_type == PatternType.RANGE_WEIGHT
        assert result.range_low_kg == Decimal("0.200000")
        assert result.range_high_kg == Decimal("0.250000")
        # Midpoint = 225g = 0.225 kg
        assert result.parsed_value == Decimal("0.225000")
        assert result.parsed_unit == "kg"
        assert result.suffix_pattern == "{N}-{N} gm"

    def test_500_700_gm(self):
        result = parse_suffix("BH - Something, 500 - 700 gm")
        assert result.pattern_type == PatternType.RANGE_WEIGHT
        assert result.range_low_kg == Decimal("0.500000")
        assert result.range_high_kg == Decimal("0.700000")
        assert result.parsed_value == Decimal("0.600000")


# ── Compound range patterns ───────────────────────────────────────────


class TestCompoundRange:
    def test_1_piece_150_200_gm(self):
        result = parse_suffix("BH-Avocado Hass - Tanzania, 1 Piece (150 - 200 gm)")
        assert result.pattern_type == PatternType.COMPOUND_RANGE
        assert result.parsed_value == Decimal("1")  # piece count
        assert result.parsed_unit == "ea"
        assert result.range_low_kg == Decimal("0.150000")
        assert result.range_high_kg == Decimal("0.200000")
        assert result.suffix_pattern == "{N} Piece ({N}-{N} gm)"

    def test_2_pieces_300_400_g(self):
        result = parse_suffix("BH - Fruit, 2 Pieces (300 - 400 g)")
        assert result.pattern_type == PatternType.COMPOUND_RANGE
        assert result.parsed_value == Decimal("2")
        assert result.range_low_kg == Decimal("0.300000")
        assert result.range_high_kg == Decimal("0.400000")


# ── No match (NONE) ──────────────────────────────────────────────────


class TestNoMatch:
    def test_no_suffix(self):
        result = parse_suffix("BH - Tomato")
        assert result.pattern_type == PatternType.NONE

    def test_empty_suffix(self):
        result = parse_suffix("BH - Item,")
        assert result.pattern_type == PatternType.NONE

    def test_no_numbers(self):
        result = parse_suffix("BH - Curry Leaves, Fresh Bunch")
        assert result.pattern_type == PatternType.NONE


# ── Case insensitivity ────────────────────────────────────────────────


class TestCaseInsensitivity:
    def test_uppercase_KG(self):
        result = parse_suffix("BH - Onion, 1 KG")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("1.000000")

    def test_mixed_case_Gm(self):
        result = parse_suffix("BH - Garlic, 100 Gm")
        assert result.pattern_type == PatternType.FIXED_WEIGHT
        assert result.parsed_value == Decimal("0.100000")

    def test_uppercase_PIECES(self):
        result = parse_suffix("BH - Item, 3 PIECES")
        assert result.pattern_type == PatternType.FIXED_COUNT
        assert result.parsed_value == Decimal("3")
