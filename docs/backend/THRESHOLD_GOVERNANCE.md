# Threshold Governance Model

## Centralization Principle

Threshold values used by backend drift, forecasting, and inventory signaling are centralized in:

- `backend/app/core/governance.py`

Runtime loading uses:

- `load_governance_thresholds()`
- singleton `thresholds`

## Drift Thresholds

Configured under `DriftThresholds`:

- `critical_ratio` (default `0.05`, Decimal, must be `> 0`)

Used by drift policy classification in `backend/app/domain/drift_policy.py`.

## Forecast Thresholds

Configured under `ForecastThresholds`:

- `critical_days` (default `3`)
- `reorder_soon_days` (default `7`)
- `watch_days` (default `14`)

Backward-compatible aliases in `backend/app/services/forecasting.py`:

- `SIGNAL_CRITICAL`
- `SIGNAL_REORDER_SOON`
- `SIGNAL_WATCH`

## Inventory Signal Thresholds

Configured under `InventorySignalThresholds`:

- `fast_depletion_ratio` (default `1.5`)
- `low_stock_ratio` (default `0.2`)
- `absolute_low_stock` (default `10.0`)

Used in reporting/inventory signal paths (for example `backend/app/services/reports.py`).

## Environment Overrides

Current environment-backed settings:

- `DRIFT_CRITICAL_RATIO`
- `FORECAST_CRITICAL_DAYS`
- `FORECAST_REORDER_SOON_DAYS`
- `FORECAST_WATCH_DAYS`

Settings source:

- `backend/app/core/config.py`

## Validation Rules

Validation is enforced by Pydantic field constraints and model validators:

- Drift ratio must be positive.
- Inventory signal thresholds must be positive.
- Forecast ordering must satisfy:
  `critical_days < reorder_soon_days < watch_days`

Invalid values raise validation errors at load/initialization time.

## Prohibitions

- No hardcoded drift/forecast/inventory threshold values inside service logic.
- No inline magic-number threshold branching in domain services.
