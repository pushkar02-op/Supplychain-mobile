# UX Truth Model: Phase 5 Alignment

## Overview
Phase 5 ensures that the Admin UX and general Frontend views are strictly aligned with the backend's canonical truth. This eliminates "client-side health inference" and ensures that drift, ambiguity, or negative stock are explicitly exposed as reported by the backend ledger and state models.

## Core Principles
1. **Backend as Sole Source of Truth**: The UI must not calculate drift, status, or severity. It must consume these values directly from the backend APIs.
2. **Standardized Vocabulary**: All layers use `ledger_qty` (transactional balance), `state_qty` (batch/physical balance), and `drift` (difference).
3. **No Hidden Drift**: Small drifts are no longer hidden by "fuzzy" healthy states in the UI. If the backend detects drift, the UI displays it according to the backend-calculated severity.

## Truth Definitions
| Field | Definition | Source |
| :--- | :--- | :--- |
| `ledger_qty` | Sum of all `InventoryTxn` records for a batch/item. | `app.services.reconciliation.calculate_ledger_qty` |
| `state_qty` | The current `quantity` field on the `Batch` model. | `Batch.quantity` |
| `drift` | `state_qty - ledger_qty`. | `app.services.reconciliation.check_batch_drift` |
| `reconciliation_status` | `HEALTHY` (drift=0) or `DRIFT` (drift!=0). | `app.services.reconciliation.check_batch_drift` |
| `severity` | `CRITICAL`, `MAJOR`, `MINOR`, or `NONE`. | `app.services.reconciliation.calculate_severity` |

## Severity Logic (Backend)
- **NONE**: `drift == 0`.
- **CRITICAL**: `ledger_qty < 0` OR `abs(drift) / abs(ledger_qty) > 5%`.
- **MAJOR**: `abs(drift) / abs(ledger_qty) <= 5%` but `drift != 0`.

## UI Alignment
- **Inventory Screen**: Replaces `current_stock` and `available_stock` with `ledger_qty` and `state_qty`. Uses `status` and `severity` from the backend to render badges.
- **Admin Drift Screen**: Consumes standardized keys and use backend-provided severity for sorting and coloring.
- **Detail Views**: Display raw breakdown of ledger vs state without local re-calculations.

## Admin Reconciliation API
New endpoints were added to manage the lifecycle of drift:
- `GET /admin/reconciliation/records`: List history of detected drift.
- `POST /admin/reconciliation/resolve`: Resolve a specific drift record with an adjustment transaction.
