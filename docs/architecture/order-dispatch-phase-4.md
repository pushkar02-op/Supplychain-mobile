# Architecture Phase 4: Order ↔ Dispatch Intent Integrity

**Status**: Active / Enforced
**Branch**: `arch/phase-4-order-dispatch`
**Models**: `DispatchEntry` (added `order_id`)

## Context
Previously, `DispatchEntry` was linked to `Order` only via heuristic matching (Item + Mart + Pending).
This caused ambiguity when multiple orders existed or when reversing historical dispatches.

## Changes

### 1. Explicit Linkage
- Added `dispatch_entry.order_id` (Nullable Foreign Key).
- **Behavior**:
    - **New Records**: Explicitly populated at creation time. Even if implicit (Legacy API), the system infers and **persists** the link immediately.
    - **Old Records**: Remain `NULL`. No backfill performed (safe history).

### 2. Intent Preservation
- **Creation**: `create_dispatch_entry` now saves the `order_id`.
- **Reversal**: `create_reversal_entry` checks `dispatch.order_id` **first**.
    - If present: Credits that specific order (Intent Integrity).
    - If missing (Legacy): Falls back to heuristic (Latest Pending Order).

## Migration Strategy
- **Forward-Only**: No database migration script to backfill `NULL` values.
- **Safety**: Historical data is untouched. 
- **Convergence**: Over time, active data becomes fully linked.

## Invariants
- `DispatchEntry` MUST NOT be reassigned to a different order once linked.
- Reversal MUST NOT guess order if explicitly linked.
