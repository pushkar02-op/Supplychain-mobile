# Architecture Phase 3: Reconciliation & Resolution Semantics

**Status**: Active / Enforced
**Source**: `backend/tests/test_phase3_resolution.py`
**Models**: `ReconciliationRecord`

## Core Concepts

### 1. Reconciliation Record (The Fact)
Drift is not just a calculation; it is a stored **Fact**.
- `ReconciliationRecord` immutably captures `observed_ledger_qty` vs `observed_state_qty` at a point in time.
- No resolution is allowed without an OPEN record.

### 2. Resolution Semantics
Drift usually implies a divergence between "System History" (Ledger) and "Current Reality" (Batch/State).

**Scenario: Ledger is Wrong (Source Lag)**
- Batch (State) is correct (e.g. 100).
- Ledger is lagging (e.g. 80).
- **Resolution**: `resolve_drift(apply_to_batch=False)`.
- **Effect**: Creates an `ADJUST` transaction (+20) to backfill the history. Does **NOT** update Batch (it is already correct).
- **Result**: Ledger=100. Batch=100. Drift=0.

**Scenario: Standard Adjustment (Found Stock)**
- Batch (90), Ledger (90). Both wrong.
- User counts 100.
- **Action**: This is **Stock Entry** or **Adjustment**, NOT "Reconciliation".
- Use standard paths types.

### 3. Invariants
- **No Silent Fixes**: All fixes create an `InventoryTxn`.
- **No Auto-Repair**: System detects drift, Humans resolve it.
- **Ledger Backing**: Batch quantity can only change if justified by a Tax (or explicit logic).

## Operations
- **Detect**: Run `check_batch_drift`.
- **Record**: Run `create_drift_record` (if drift > 0).
- **Resolve**: Admin runs `resolve_drift`.

## Non-Goals
- "Sync Batch to Ledger" (Cache Refresh) is a separate maintenance task, distinct from "Resolving Drift" (Logic Repair).
