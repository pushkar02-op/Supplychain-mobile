"""
Decimal enforcement utilities for ledger-safe arithmetic.
Phase G1 Governance — NUM-001 Compliance.

All inventory quantities must remain Decimal through the domain layer.
float() conversion is ONLY permitted at the API serialization boundary.
"""

from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

LEDGER_QUANTIZE = Decimal("0.001")


def enforce_decimal(value) -> Decimal:
    """
    Safely convert any numeric input to Decimal via string intermediary.
    Prevents float→Decimal precision loss.

    Args:
        value: Any numeric value (int, float, Decimal, str, or None).

    Returns:
        Decimal: The value as a Decimal.

    Raises:
        ValueError: If value cannot be converted to Decimal.
    """
    if value is None:
        return Decimal("0")
    if isinstance(value, Decimal):
        return value
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError) as e:
        raise ValueError(f"Cannot convert {value!r} to Decimal: {e}") from e


def quantize_ledger(value) -> Decimal:
    """
    Quantize a value to ledger precision (0.001) using ROUND_HALF_UP.

    Args:
        value: Any numeric value.

    Returns:
        Decimal: Quantized to 3 decimal places.
    """
    return enforce_decimal(value).quantize(LEDGER_QUANTIZE, rounding=ROUND_HALF_UP)


def assert_decimal(value) -> Decimal:
    """
    Runtime assertion that value is already a Decimal.

    Args:
        value: Expected Decimal value.

    Returns:
        Decimal: The same value, confirmed as Decimal.

    Raises:
        TypeError: If value is not a Decimal instance.
    """
    if not isinstance(value, Decimal):
        raise TypeError(f"Expected Decimal, got {type(value).__name__}: {value!r}")
    return value
