"""
Suffix Parser Service.

Parses the suffix portion of supplier item names to extract
structured weight, count, and range information.

Only 2 internal stock UOMs: kg and ea.
All weights are normalized to kg. All counts are normalized to ea.

Example item names (Zomato format):
  "BH - Garlic, 500 gm"          → FIXED_WEIGHT, 0.5 kg
  "BH - Onion, 1 Kg"             → FIXED_WEIGHT, 1.0 kg
  "BH-Banana , 3 Pieces"         → FIXED_COUNT, 3 ea
  "BH - Betel Leaves, 5 Units"   → FIXED_COUNT, 5 ea
  "BH - Red Globe Grapes, 200 - 250 g"  → RANGE_WEIGHT, midpoint 0.225 kg
  "BH-Avocado, 1 Piece (150 - 200 gm)"  → COMPOUND_RANGE, 1 ea + range 0.175 kg
"""

import logging
import re
from dataclasses import dataclass
from decimal import Decimal
from enum import Enum
from typing import Optional

logger = logging.getLogger(__name__)


class PatternType(str, Enum):
    FIXED_WEIGHT = "FIXED_WEIGHT"
    FIXED_COUNT = "FIXED_COUNT"
    RANGE_WEIGHT = "RANGE_WEIGHT"
    COMPOUND_RANGE = "COMPOUND_RANGE"
    NONE = "NONE"


@dataclass
class SuffixParseResult:
    """Structured result from parsing an item name suffix."""

    pattern_type: PatternType
    # For FIXED_WEIGHT: value in kg. For FIXED_COUNT: count as integer.
    # For RANGE_WEIGHT: midpoint in kg. For COMPOUND_RANGE: piece count.
    parsed_value: Optional[Decimal] = None
    parsed_unit: Optional[str] = None  # "kg" or "ea"
    # For ranges: low and high in kg
    range_low_kg: Optional[Decimal] = None
    range_high_kg: Optional[Decimal] = None
    # The structural pattern template for rule keying
    suffix_pattern: Optional[str] = None
    # Raw suffix text that was parsed
    raw_suffix: Optional[str] = None


# Weight unit normalization: everything → grams, then convert to kg
WEIGHT_UNITS_TO_GRAMS = {
    "gm": Decimal("1"),
    "gms": Decimal("1"),
    "g": Decimal("1"),
    "gram": Decimal("1"),
    "grams": Decimal("1"),
    "kg": Decimal("1000"),
    "kgs": Decimal("1000"),
    "kilogram": Decimal("1000"),
    "kilograms": Decimal("1000"),
}

# Count unit normalization
COUNT_UNITS = {"piece", "pieces", "pcs", "pc", "unit", "units"}

# Regex patterns ordered by specificity (most specific first)
# All patterns are case-insensitive

# Compound: "1 Piece (150 - 200 gm)" or "2 Pcs (300 - 400 g)"
_RE_COMPOUND_RANGE = re.compile(
    r"(\d+)\s*(?:pieces?|pcs?|units?)\s*"
    r"\(\s*(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)\s*"
    r"(gm|gms|g|gram|grams|kg|kgs|kilogram|kilograms)\s*\)",
    re.IGNORECASE,
)

# Range weight: "200 - 250 g" or "500 - 700 gm"
_RE_RANGE_WEIGHT = re.compile(
    r"(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)\s*"
    r"(gm|gms|g|gram|grams|kg|kgs|kilogram|kilograms)\b",
    re.IGNORECASE,
)

# Fixed weight: "500 gm", "1 Kg", "100 g", "1.5 kg"
_RE_FIXED_WEIGHT = re.compile(
    r"(\d+(?:\.\d+)?)\s*(gm|gms|g|gram|grams|kg|kgs|kilogram|kilograms)\b",
    re.IGNORECASE,
)

# Fixed count: "3 Pieces", "5 Units", "1 Piece", "2 Pcs"
_RE_FIXED_COUNT = re.compile(
    r"(\d+)\s*(pieces?|pcs?|units?)\b",
    re.IGNORECASE,
)


def _grams_to_kg(value_grams: Decimal) -> Decimal:
    """Convert grams to kg with 6 decimal places."""
    return (value_grams / Decimal("1000")).quantize(Decimal("0.000001"))


def _normalize_weight_to_kg(value: str, unit: str) -> Decimal:
    """Convert a numeric value + weight unit string to kg."""
    unit_lower = unit.lower().strip()
    grams_per_unit = WEIGHT_UNITS_TO_GRAMS.get(unit_lower)
    if grams_per_unit is None:
        raise ValueError(f"Unknown weight unit: {unit}")
    total_grams = Decimal(value) * grams_per_unit
    return _grams_to_kg(total_grams)


def _build_suffix_pattern(pattern_type: PatternType, unit: str) -> str:
    """Build a structural pattern template for rule keying.

    Examples:
      FIXED_WEIGHT with "gm" → "{N} gm"
      FIXED_COUNT with "Pieces" → "{N} Pieces"
      RANGE_WEIGHT with "g" → "{N}-{N} g"
      COMPOUND_RANGE with "gm" → "{N} Piece ({N}-{N} gm)"
    """
    unit_lower = unit.lower().strip()
    if pattern_type == PatternType.FIXED_WEIGHT:
        # Normalize to canonical unit abbreviation
        if unit_lower in ("kg", "kgs", "kilogram", "kilograms"):
            return "{N} kg"
        return "{N} gm"
    elif pattern_type == PatternType.FIXED_COUNT:
        if unit_lower in ("unit", "units"):
            return "{N} Units"
        return "{N} Pieces"
    elif pattern_type == PatternType.RANGE_WEIGHT:
        if unit_lower in ("kg", "kgs", "kilogram", "kilograms"):
            return "{N}-{N} kg"
        return "{N}-{N} gm"
    elif pattern_type == PatternType.COMPOUND_RANGE:
        if unit_lower in ("kg", "kgs", "kilogram", "kilograms"):
            return "{N} Piece ({N}-{N} kg)"
        return "{N} Piece ({N}-{N} gm)"
    return ""


def extract_suffix(item_name: str) -> str:
    """Extract the suffix portion after the first comma.

    "BH - Garlic, 500 gm" → "500 gm"
    "BH-Avocado Hass - Tanzania, 1 Piece (150 - 200 gm)" → "1 Piece (150 - 200 gm)"
    """
    parts = item_name.split(",", 1)
    if len(parts) < 2:
        return ""
    return parts[1].strip()


def extract_item_name_stem(item_name: str) -> str:
    """Extract the normalized name stem (before the comma).

    "BH - Garlic, 500 gm" → "bh - garlic"
    "BH-Banana , 3 Pieces" → "bh-banana"
    """
    parts = item_name.split(",", 1)
    return parts[0].strip().lower()


def parse_suffix(item_name: str, format_type: str = "zomato") -> SuffixParseResult:
    """Parse the suffix of an item name to extract structured conversion info.

    Args:
        item_name: Full item name from the bill (e.g., "BH - Garlic, 500 gm")
        format_type: Parser format identifier (e.g., "zomato", "reliance")

    Returns:
        SuffixParseResult with extracted pattern type, value, and unit.
    """
    suffix = extract_suffix(item_name)

    if not suffix:
        return SuffixParseResult(
            pattern_type=PatternType.NONE,
            raw_suffix="",
        )

    # Try patterns in order of specificity

    # 1. Compound range: "1 Piece (150 - 200 gm)"
    m = _RE_COMPOUND_RANGE.search(suffix)
    if m:
        piece_count = int(m.group(1))
        low_val = m.group(2)
        high_val = m.group(3)
        weight_unit = m.group(4)
        low_kg = _normalize_weight_to_kg(low_val, weight_unit)
        high_kg = _normalize_weight_to_kg(high_val, weight_unit)
        midpoint_kg = (low_kg + high_kg) / Decimal("2")
        return SuffixParseResult(
            pattern_type=PatternType.COMPOUND_RANGE,
            parsed_value=Decimal(str(piece_count)),
            parsed_unit="ea",
            range_low_kg=low_kg,
            range_high_kg=high_kg,
            suffix_pattern=_build_suffix_pattern(
                PatternType.COMPOUND_RANGE, weight_unit
            ),
            raw_suffix=suffix,
        )

    # 2. Range weight: "200 - 250 g"
    m = _RE_RANGE_WEIGHT.search(suffix)
    if m:
        low_val = m.group(1)
        high_val = m.group(2)
        weight_unit = m.group(3)
        low_kg = _normalize_weight_to_kg(low_val, weight_unit)
        high_kg = _normalize_weight_to_kg(high_val, weight_unit)
        midpoint_kg = (low_kg + high_kg) / Decimal("2")
        return SuffixParseResult(
            pattern_type=PatternType.RANGE_WEIGHT,
            parsed_value=midpoint_kg,
            parsed_unit="kg",
            range_low_kg=low_kg,
            range_high_kg=high_kg,
            suffix_pattern=_build_suffix_pattern(PatternType.RANGE_WEIGHT, weight_unit),
            raw_suffix=suffix,
        )

    # 3. Fixed weight: "500 gm", "1 Kg"
    m = _RE_FIXED_WEIGHT.search(suffix)
    if m:
        value = m.group(1)
        weight_unit = m.group(2)
        kg_value = _normalize_weight_to_kg(value, weight_unit)
        return SuffixParseResult(
            pattern_type=PatternType.FIXED_WEIGHT,
            parsed_value=kg_value,
            parsed_unit="kg",
            suffix_pattern=_build_suffix_pattern(PatternType.FIXED_WEIGHT, weight_unit),
            raw_suffix=suffix,
        )

    # 4. Fixed count: "3 Pieces", "5 Units"
    m = _RE_FIXED_COUNT.search(suffix)
    if m:
        count = int(m.group(1))
        count_unit = m.group(2)
        return SuffixParseResult(
            pattern_type=PatternType.FIXED_COUNT,
            parsed_value=Decimal(str(count)),
            parsed_unit="ea",
            suffix_pattern=_build_suffix_pattern(PatternType.FIXED_COUNT, count_unit),
            raw_suffix=suffix,
        )

    # 5. Nothing matched
    logger.debug(f"No pattern matched for suffix: '{suffix}' from item: '{item_name}'")
    return SuffixParseResult(
        pattern_type=PatternType.NONE,
        raw_suffix=suffix,
    )
