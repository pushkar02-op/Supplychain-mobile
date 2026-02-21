from decimal import Decimal

DRIFT_RATIO_CRITICAL = Decimal("0.05")
DRIFT_RATIO_MAJOR = Decimal("0.05")

DRIFT_ABS_HIGH = Decimal("50")
DRIFT_ABS_MEDIUM = Decimal("10")


def classify_drift_ratio(ratio: Decimal) -> str:
    """
    Central drift severity classification for ratio-based checks.
    Preserves existing behavior: > 5% => CRITICAL, else MAJOR.
    """
    if ratio > DRIFT_RATIO_CRITICAL:
        return "CRITICAL"
    return "MAJOR"


def classify_drift_amount(drift_amount: Decimal) -> str:
    """
    Central drift severity classification for absolute-amount checks.
    Preserves existing thresholds used by drift history projection.
    """
    abs_drift = abs(drift_amount)
    if abs_drift > DRIFT_ABS_HIGH:
        return "HIGH"
    if abs_drift > DRIFT_ABS_MEDIUM:
        return "MEDIUM"
    return "LOW"
