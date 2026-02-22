import os
import subprocess
import sys
from decimal import Decimal

import pytest

from app.core.governance import (
    DriftThresholds,
    ForecastThresholds,
    GovernanceThresholds,
    InventorySignalThresholds,
    thresholds,
)
from app.domain.drift_policy import classify_drift_ratio


def test_default_thresholds_match_expected_values():
    assert thresholds.drift.critical_ratio == Decimal("0.05")
    assert thresholds.forecast.critical_days == 3
    assert thresholds.forecast.reorder_soon_days == 7
    assert thresholds.forecast.watch_days == 14
    assert thresholds.inventory.fast_depletion_ratio == Decimal("1.5")
    assert thresholds.inventory.low_stock_ratio == Decimal("0.2")
    assert thresholds.inventory.absolute_low_stock == Decimal("10.0")


def test_forecast_ordering_validation_works():
    with pytest.raises(ValueError):
        GovernanceThresholds(
            forecast=ForecastThresholds(
                critical_days=7, reorder_soon_days=3, watch_days=14
            )
        )


def test_drift_threshold_positive_validation_works():
    with pytest.raises(ValueError):
        DriftThresholds(critical_ratio=Decimal("0"))


def test_inventory_threshold_positive_validation_works():
    with pytest.raises(ValueError):
        InventorySignalThresholds(low_stock_ratio=Decimal("0"))


def test_drift_classification_behavior_unchanged_with_defaults():
    assert classify_drift_ratio(Decimal("0.051")) == "CRITICAL"
    assert classify_drift_ratio(Decimal("0.05")) == "MAJOR"


def test_env_override_for_thresholds_works():
    env = os.environ.copy()
    env["DRIFT_CRITICAL_RATIO"] = "0.07"
    env["FORECAST_CRITICAL_DAYS"] = "4"
    env["FORECAST_REORDER_SOON_DAYS"] = "8"
    env["FORECAST_WATCH_DAYS"] = "15"

    code = (
        "from app.core.governance import thresholds\n"
        "print(thresholds.drift.critical_ratio)\n"
        "print(thresholds.forecast.critical_days)\n"
        "print(thresholds.forecast.reorder_soon_days)\n"
        "print(thresholds.forecast.watch_days)\n"
    )
    result = subprocess.run(
        [sys.executable, "-c", code],
        capture_output=True,
        text=True,
        check=True,
        cwd=os.path.dirname(__file__) + "/..",
        env=env,
    )

    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    assert lines == ["0.07", "4", "8", "15"]
