# Walkthrough - Phase 7: Domain Events

## Goal
Introduce a reliable **Domain Event** system using the **Outbox Pattern** to decouple side effects (like notifications, analytics, intra-service sync) from core transactional logic.

## Changes

### 1. Database Schema
- **New Table**: `domain_events`
    - `id`: Serial Primary Key
    - `event_type`: String (e.g., `inventory_txn.committed`)
    - `aggregate_type`: String (e.g., `inventory_txn`)
    - `aggregate_id`: String (Reference to the entity)
    - `payload`: JSON (The event data)
    - `occurred_at`: Timestamp
    - `processed_at`: Timestamp (Nullable, for future consumer use)

### 2. Event Models
Defined Pydantic schemas in `app/schemas/domain_event.py`:
- `InventoryTxnCommitted`
- `DispatchCompleted`
- `OrderFulfilled`
- `ReconciliationResolved`

### 3. Service Integration
Integrated event emission into critical write paths:
- `InventoryTxn.create_inventory_txn` -> Emits `inventory_txn.committed`
- `DispatchEntry.create_dispatch_entry` -> Emits `dispatch.completed`
- `DispatchEntry._update_order_after_dispatch` -> Emits `order.fulfilled` (when complete)
- `Reconciliation.resolve_drift` -> Emits `reconciliation.resolved`

### 4. Verification
- **Test Suite**: `tests/test_phase7_domain_events.py`
    - Verifies that performing the action (e.g., creating a txn) results in a `DomainEvent` row being inserted in the SAME transaction.
    - Verifies the payload matches the expected schema.
- **Regressions**:
    - Fixed `JSONB` vs `JSON` compatibility for SQLite/Postgres.
    - Fixed `Mart` creation in tests to satisfy `company_name` constraints.
    - Fixed `ReconciliationRecord` export in `__init__.py` to ensure schema visibility.
    - Fixed test isolation issues (cascading cleanup of `DispatchReversal`, `DispatchEntry`, `Order`).
- **Result**: All 9 tests in `test_phase7_domain_events.py` and `test_inventory_rules.py` passed.

## Next Steps
- Implement an **Event Publisher** (simulated or real) that polls `domain_events` and pushes to a message broker (RabbitMQ/Kafka) or triggers Webhooks.
- Add `processed_at` updating logic.

# Walkthrough - Phase 8: Event Relay & Analytics

## Goal
Implement a governed **Event Relay** to consume Domain Events and populate read-only **Analytics Projections**, ensuring zero impact on core transactional performance.

## Changes

### 1. Schema & Projections
- **Models**:
  - `DomainEvent` (Updated with `processed_at`)
  - `InventoryFlowDaily` (Aggregation of flux)
  - `InventoryDriftHistory` (Audit of reconciliation)
  - `OrderFulfillmentMetrics` (Performance timing)

### 2. Relay Service
- **Logic**: Implemented `event_relay.py` to poll, lock, processing, and mark events as processed.
- **Handlers**: Implemented logic to update projections idempotently.

### 3. Verification
- **Test Suite**: `tests/test_phase8_event_relay.py`
  - Validated Event -> Relay -> Projection pipeline.
  - Validated Foreign Key consistency and Data Integrity.
  - Verified Idempotency (replay safety).
- **Outcome**: Tests passed (with minor environment warnings, functional logic verified).
