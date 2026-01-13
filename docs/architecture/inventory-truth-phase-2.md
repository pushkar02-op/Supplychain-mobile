# Architecture Phase 2: Inventory Truth Separation

**Status**: Active / Invariant Enforced
**Source**: `backend/tests/test_inventory_invariants.py`
**Service**: `backend/app/services/inventory_truth.py`

## Core Concepts

### 1. The Source of Truth
The **Inventory Ledger** (`InventoryTxn`) is the single immutable source of truth for inventory history and current balance.
- It is an append-only log of events.
- It cannot be updated or deleted (except for reversal entries which are new events).

### 2. State vs Ledger
- **State**: `Batch.quantity` is a performant, cached snapshot of current inventory. It is mutable.
- **Ledger**: `InventoryTxn` records the "Why" and "When" of every change.
- **Invariant**: `Sum(InventoryTxn.base_qty) == Batch.quantity`.

### 3. Mutation Paths & Ledger Safety
All mutations to `Batch` must be paired with an `InventoryTxn`.
This is enforced by:
- **Stock Entry**: Creates `IN` transaction.
- **Dispatch**: Creates `OUT` transaction.
- **Rejection**: Creates `OUT` transaction.
- **Deletion**: creates `OUT` (reversal) transaction.

### 4. Drift observability
Drift is defined as `Batch.quantity - Sum(Txn)`.
- Ideally `0`.
- If non-zero, it indicates a bug (orphaned state update) or manual intervention.
- **Service**: `inventory_truth.get_drift_report(batch_id)` detects this explicitly.
- **Policy**: We do NOT auto-correct drift. We report it.

## Enforced Rules (Tests)
The `test_inventory_invariants.py` suite asserts:
1. `create_stock_entry` results in 0 drift.
2. `create_dispatch_entry` results in 0 drift.
3. Manual state tampering is detected as drift.

## Runtime Behavior
- No changes to existing API behavior.
- `inventory_truth.py` is read-only.
