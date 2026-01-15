# Phase 9: Forecasting & Decision Signals

## Purpose

Phase 9 introduces **deterministic forecasting** based on existing ledger truth and Phase 8 projections. This is NOT machine learning or probabilistic prediction—it is explainable, auditable math.

> **Key Question Answered**: "If nothing changes, what will run out, when, and why?"

---

## What Phase 9 IS

- **Read-only** with respect to core domain models (Item, Batch, InventoryTxn)
- **Deterministic math** only (no ML, no probabilistic logic)
- **Explainable signals** (STABLE, WATCH, REORDER_SOON, CRITICAL)
- **Advisory only** (displays information, does not trigger actions)
- **Auditable** (all inputs traceable to Phase 6-8 read models)

## What Phase 9 is NOT

❌ Auto-replenishment  
❌ Background jobs modifying state  
❌ Machine learning predictions  
❌ Frontend inference or calculations  
❌ Commands or actions  

---

## Architecture

### Data Flow

```
InventoryFlowDaily (Phase 8)
        │
        ▼
  compute_burn_rate()
        │
        ▼
    ItemBurnRate (table)
        │
        ▼
  compute_depletion_forecast()
        │
        ▼
  StockDepletionForecast (table)
        │
        ▼
    classify_signal()
        │
        ▼
   STABLE / WATCH / REORDER_SOON / CRITICAL
```

### Signal Classification

| Signal | Days to Stockout | Meaning |
|--------|-----------------|---------|
| CRITICAL | < 3 days | Immediate attention needed |
| REORDER_SOON | < 7 days | Should reorder this week |
| WATCH | < 14 days | Monitor closely |
| STABLE | >= 14 days or no outflow | No action needed |

---

## Core Formulas

### Burn Rate (Average Daily Outflow)

```python
avg_daily_outflow_7d = SUM(out_qty over last 7 days) / 7
```

Source: `InventoryFlowDaily` (Phase 8 projection)

### Days to Zero

```python
if avg_outflow > 0:
    days_to_zero = ledger_qty / avg_outflow
else:
    days_to_zero = None  # STABLE
```

### Stockout Date

```python
projected_stockout_date = today + days_to_zero
```

---

## API Endpoints

### GET /admin/forecasting/summary

Returns all item forecasts with signals.

```json
{
  "items": [
    {
      "item_id": 1,
      "current_ledger_qty": 100.0,
      "avg_daily_outflow": 10.0,
      "days_to_zero": 10.0,
      "projected_stockout_date": "2026-01-25",
      "signal": "WATCH"
    }
  ]
}
```

### POST /admin/forecasting/refresh

Refreshes all forecasts. Idempotent.

---

## How to Interpret Signals

| Signal | Admin Action |
|--------|--------------|
| CRITICAL | Verify stock, consider emergency reorder |
| REORDER_SOON | Plan reorder within the week |
| WATCH | Add to monitoring list |
| STABLE | No action required |

> **Important**: These are signals, not commands. The system does NOT auto-reorder.

---

## Limitations

1. Forecasts assume **current trends continue unchanged**
2. No seasonality or demand spikes considered
3. Confidence based on historical window (7/14/30 days)
4. Forecasts are **snapshots**, not real-time

---

## Governance

- All forecast computations are logged
- No mutation of core inventory tables
- Forecasts can be regenerated at any time
- Signals are computed on-read, not stored
