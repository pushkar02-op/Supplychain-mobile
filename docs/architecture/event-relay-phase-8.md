# Phase 8: Event Relay & Analytics

## Overview
Phase 8 introduces the **Event Relay** system, a governed mechanism for asynchronous processing of Domain Events (`domain_events` table). This system enables the derivation of read-only analytics projections without coupling core transactional logic to reporting requirements.

## Components

### 1. Domain Object Model (`DomainEvent`)
- **Table**: `domain_events`
- **Purpose**: Immutable log of business facts.
- **Key Columns**:
  - `event_type`: Dot-separated identifier (e.g., `inventory_txn.committed`).
  - `payload`: JSON blob containing event data.
  - `occurred_at`: Timestamp of the business action.
  - `processed_at`: Timestamp when the relay successfully processed the event (Nullable).

### 2. Event Relay Service (`event_relay.py`)
- **Function**: `process_pending_events()`
- **Behavior**:
  - Polls `domain_events` where `processed_at` is NULL.
  - Locks rows (`SKIP LOCKED`) to allow single-threaded or multi-worker processing.
  - Dispatches events to registered handlers based on `event_type`.
  - Marks event as processed (`processed_at = now`) upon successful handling.
  - **Idempotency**: Guaranteed by the `processed_at` flag. Re-running the relay on processed events has no effect.

### 3. Projections
Read-optimized tables populated by event handlers.

#### Inventory Flow Daily (`inventory_flow_daily`)
- **Source Event**: `inventory_txn.committed`
- **Purpose**: Daily aggregation of inventory movements.
- **Fields**: `date`, `item_id`, `in_qty`, `out_qty`, `net_qty`.
- **Logic**: Aggregates `qty` based on transaction direction (`IN`/`OUT`).

#### Inventory Drift History (`inventory_drift_history`)
- **Source Event**: `reconciliation.resolved`
- **Purpose**: Audit trail of system vs physical discrepancies.
- **Fields**: `batch_id`, `drift` (quantity), `severity` (Low/Medium/High), `resolved_at`.

#### Order Fulfillment Metrics (`order_fulfillment_metrics`)
- **Source Event**: `order.fulfilled`
- **Purpose**: Performance tracking of order processing time.
- **Fields**: `order_id`, `fulfillment_time_minutes`.
- **Logic**: Calculates duration between Order Creation (fetched from DB) and Event Occurrence.

## Safety & Governance
- **Read-Only Projections**: The Relay processes writes ONLY to Projection tables and the `processed_at` flag. It NEVER mutates core domain tables (`Item`, `Order`, `Inventory`).
- **Replayability**: By resetting `processed_at` to NULL, the system can rebuild projections from scratch (if projections are truncated first).
- **Isolation**: Handlers run within the Relay's transaction context. Failure in a handler rolls back the processing flag, ensuring retry.

## Future Extensions
- **Batch Processing**: Currently sequential. Can be optimized for bulk inserts.
- **External Publishing**: Can be extended to publish to Kafka/RabbitMQ for external consumers.
