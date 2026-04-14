# AGRO Repository — System Map

> **This file is canonical.** It describes entity structure, relationships,
> core execution flows, state transitions, and invariant touchpoints.
> It is a factual map of the codebase as it exists — not a design proposal.
> For layer rules and enforcement contracts, read `02-ARCHITECTURE.md`.
> For individual invariant text, read `01-INVARIANTS.md`.

---

## Section 1 — Entity Definitions

### Entity: Item

**Purpose:** The product catalog entry. Every physical good in the system
traces back to an Item. Items are warehouse-independent — the same Item
can exist as Batches in multiple warehouses.

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `name` | String (unique) | Canonical product name |
| `item_code` | String (nullable) | Supplier or SKU code |
| `creation_intent` | String (nullable) | `"REGULAR"` or `"ONE_OFF"` |
| `status` | Enum | `ACTIVE` or `INACTIVE` |
| `default_uom_id` | FK → UOM | Default unit of measure |

**Relationships:**
- `Item` → `Batch` (1:N) — one item may have many batch records across warehouses
- `Item` → `ItemAlias` (1:N) — mart-specific names that resolve to this item
- `Item` → `ItemConversionMap` (1:N) — UOM conversion factors for this item

**Model:** `backend/app/db/models/item.py`

---

### Entity: Batch

**Purpose:** A physical lot of an Item held at a specific Warehouse.
`batch.quantity` is the authoritative running balance for that lot.
Every inventory mutation must update this field AND write an `InventoryTxn`
in the same transaction.

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `item_id` | FK → Item | Which product this lot contains |
| `warehouse_id` | FK → Warehouse | Which warehouse holds it |
| `quantity` | Numeric(18,6) | Current on-hand balance (analytical precision) |
| `unit` | String | Storage unit for this batch |
| `expiry_date` | Date (nullable) | Shelf-life expiry |
| `received_at` | Date (nullable) | Date goods arrived |

**Relationships:**
- `Batch` → `Item` (N:1)
- `Batch` → `Warehouse` (N:1)
- `Batch` → `InventoryTxn` (1:N) — all ledger rows reference the batch

**Model:** `backend/app/db/models/batch.py`

---

### Entity: InventoryTxn

**Purpose:** The append-only audit ledger. One row per inventory event.
Rows are never updated or deleted — reversals are new rows with opposite
sign. The ledger reconstructs the balance history of any batch from
its rows alone.

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `item_id` | FK → Item | Denormalized for query convenience |
| `batch_id` | FK → Batch (nullable) | Batch this txn belongs to |
| `warehouse_id` | FK → Warehouse | Warehouse context |
| `txn_type` | String(16) | `IN`, `OUT`, `ADJUST`, etc. |
| `raw_qty` | Numeric(10,3) | Quantity in the source unit |
| `raw_unit` | String(16) | Source unit |
| `base_qty` | Numeric(10,3) | Quantity converted to base unit |
| `base_unit` | String(16) | Base unit |
| `ref_type` | String(32) | Source type: `stock_entry`, `dispatch_entry`, `manual` |
| `ref_id` | Integer | ID of the source record |
| `created_at` | DateTime | Write timestamp (UTC) |
| `remarks` | String(255) (nullable) | Human note |

**Relationships:**
- `InventoryTxn` → `Item` (N:1)
- `InventoryTxn` → `Batch` (N:1)
- `InventoryTxn` → `Warehouse` (N:1)

**Model:** `backend/app/db/models/inventory_txn.py`

---

### Entity: Order

**Purpose:** A mart's purchase order for a specific item. Tracks how much
was ordered and how much has been dispatched. Drives the ORD-007 guard —
dispatches cannot exceed `quantity_ordered - quantity_dispatched`.

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `item_id` | FK → Item | Which item was ordered |
| `mart_id` | FK → Mart | Which mart placed the order |
| `warehouse_id` | FK → Warehouse | Fulfilling warehouse |
| `order_date` | Date | Date of the order |
| `quantity_ordered` | Numeric(10,3) | Original ordered quantity |
| `quantity_dispatched` | Numeric(10,3) | Running dispatched total (updated on each dispatch/reversal) |
| `status` | String | `Pending`, `Partially Completed`, `Completed`, `Cancelled` |
| `unit` | String | Order unit |

**Unique constraint:** `(item_id, order_date, mart_id)` — one order per
item per mart per day.

**Relationships:**
- `Order` → `Item` (N:1)
- `Order` → `Mart` (N:1)
- `Order` → `Warehouse` (N:1)
- `Order` → `DispatchEntry` (1:N, via `dispatch_entry.order_id`)

**Model:** `backend/app/db/models/order.py`

---

### Entity: DispatchEntry

**Purpose:** Records a single dispatch event — goods sent from a batch to
a mart. Immutable after creation. Reversals are separate `DispatchReversal`
records that restore the batch quantity and adjust the order's
`quantity_dispatched`.

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `batch_id` | FK → Batch | Source batch |
| `item_id` | FK → Item | Denormalized item reference |
| `warehouse_id` | FK → Warehouse | Originating warehouse |
| `dispatch_date` | Date | Date of dispatch |
| `mart_id` | FK → Mart | Destination mart |
| `quantity` | Numeric(10,3) | Quantity dispatched |
| `unit` | String | Dispatch unit |
| `order_id` | FK → Order (nullable) | Linked order, if dispatched against an order |

**Unique constraint:** `(batch_id, dispatch_date, mart_id)` — one dispatch
entry per batch per mart per day.

**Relationships:**
- `DispatchEntry` → `Batch` (N:1)
- `DispatchEntry` → `Item` (N:1)
- `DispatchEntry` → `Mart` (N:1)
- `DispatchEntry` → `Order` (N:1, nullable)
- `DispatchEntry` → `InventoryTxn` (1:1 logical, via `ref_type="dispatch_entry"`, `ref_id=dispatch.id`)

**Model:** `backend/app/db/models/dispatch_entry.py`

---

### Entity: StockEntry

**Purpose:** Records goods received into warehouse stock from a supplier.
Creates a Batch record and writes an `InventoryTxn` of type `IN`.
Immutable after creation — corrections require a separate adjustment entry.

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `item_id` | FK → Item | Item received |
| `batch_id` | FK → Batch | Batch created or incremented |
| `warehouse_id` | FK → Warehouse | Receiving warehouse |
| `source_bill_item_id` | FK → MartBillItem (nullable) | Invoice line that generated this entry |
| `received_date` | Date | Date goods arrived |
| `source` | String (nullable) | Supplier name or reference |
| `price_per_unit` | Numeric(18,6) | Unit cost at time of receipt |
| `total_cost` | Numeric(18,6) | `price_per_unit × quantity` |
| `quantity` | Numeric(10,3) | Quantity received |
| `unit` | String | Received unit |
| `is_active` | Boolean | Soft-delete flag |

**Relationships:**
- `StockEntry` → `Item` (N:1)
- `StockEntry` → `Batch` (N:1)
- `StockEntry` → `Warehouse` (N:1)
- `StockEntry` → `MartBillItem` (N:1, nullable, via `source_bill_item_id`)
- `StockEntry` → `InventoryTxn` (1:1 logical, via `ref_type="stock_entry"`, `ref_id=stock_entry.id`)

**Model:** `backend/app/db/models/stock_entry.py`

---

### Entity: MartBill

**Purpose:** A mart's dispatch confirmation — a PDF invoice uploaded by the
mart to confirm what was dispatched. Not a purchase invoice. Parsed to
extract line items (MartBillItem). Drives reconciliation.

**Database table:** `invoice` (legacy naming — the entity is a dispatch
confirmation, not a purchase bill)

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `mart_id` | FK → Mart | Issuing mart |
| `warehouse_id` | FK → Warehouse | Warehouse context |
| `invoice_date` | Date | Date on the invoice |
| `file_path` | String | Storage path of the uploaded PDF |
| `file_hash` | String (unique) | SHA-256 of file bytes — prevents duplicate upload |
| `total_amount` | Numeric(18,6) (nullable) | Parsed total from invoice |
| `status` | String | `PROCESSING`, `NEEDS_REVIEW`, or `VERIFIED` |
| `locked_at` | DateTime (nullable) | Timestamp when bill was locked for editing |
| `locked_by` | String (nullable) | User who locked the bill |
| `format_type` | String (nullable) | Detected invoice format (parser variant) |

**Relationships:**
- `MartBill` → `Mart` (N:1)
- `MartBill` → `Warehouse` (N:1)
- `MartBill` → `MartBillItem` (1:N, cascades delete)

**Model:** `backend/app/db/models/mart_bill.py`

---

### Entity: MartBillItem

**Purpose:** A single line item parsed from a MartBill PDF. Linked to an
Item once resolved. Unresolved items block bill verification. Once
resolved and verified, MartBillItems are used to drive StockEntry creation.

**Database table:** `invoice_item`

**Key fields:**
| Field | Type | Meaning |
|-------|------|---------|
| `id` | Integer PK | Internal identifier |
| `invoice_id` | FK → MartBill | Parent bill |
| `item_id` | FK → Item (nullable) | Resolved Item — null until mapped |
| `resolution_status` | String | `UNRESOLVED` or `MAPPED` |
| `warehouse_id` | FK → Warehouse | Warehouse context |
| `item_name` | String | Raw name from invoice (verbatim) |
| `quantity` | Numeric(10,3) | Parsed quantity |
| `uom` | String | Parsed unit |
| `price` | Numeric(18,6) | Parsed price per unit |
| `total` | Numeric(18,6) | Parsed line total |
| `invoice_date` | DateTime | Line-item date from invoice |
| `store_name` | String | Store name from invoice |

**Relationships:**
- `MartBillItem` → `MartBill` (N:1, `back_populates="items"`)
- `MartBillItem` → `Item` (N:1, nullable)
- `MartBillItem` → `Warehouse` (N:1)
- `MartBillItem` ← `StockEntry` (1:1, via `stock_entry.source_bill_item_id`)

**Model:** `backend/app/db/models/mart_bill_item.py`

---

## Section 2 — Entity Relationships

```
UOM ─────────────────────────────────┐
                                     │ default_uom
Warehouse ──┬────────────────────────┼───────────── Item ──────── ItemAlias
            │                        │                │
            │                        └───── Batch ────┘
            │                                │
            │                         InventoryTxn  ◄── ref_id (stock_entry)
            │                         (append-only)  ◄── ref_id (dispatch_entry)
            │
            ├── StockEntry ──── Batch
            │       │
            │       └── MartBillItem ◄── invoice_id ── MartBill ──── Mart
            │                │
            │                └── Item (nullable, resolved)
            │
            ├── DispatchEntry ──── Batch
            │       │
            │       └── Order ──── Mart
            │
            └── Order ──── Mart
```

**Cardinalities:**

| From | To | Cardinality | Key constraint |
|------|----|-------------|----------------|
| Item | Batch | 1:N | Each Batch belongs to exactly one Item |
| Batch | InventoryTxn | 1:N | All ledger rows for a batch reference its id |
| StockEntry | InventoryTxn | 1:1 (logical) | `ref_type="stock_entry"`, `ref_id=stock_entry.id` |
| DispatchEntry | InventoryTxn | 1:1 (logical) | `ref_type="dispatch_entry"`, `ref_id=dispatch.id` |
| Order | DispatchEntry | 1:N | One order may be fulfilled across many dispatch events |
| MartBill | MartBillItem | 1:N | Bill is parent; items cascade-delete with the bill |
| MartBillItem | Item | N:1 (nullable) | Null until alias resolution maps the raw name to an Item |
| MartBillItem | StockEntry | 1:1 (optional) | `stock_entry.source_bill_item_id` links back |

**The InventoryTxn link is logical, not a FK column.** `ref_type` + `ref_id`
form a polymorphic reference — they identify the source record by type
and integer ID, but SQLAlchemy does not enforce referential integrity on
this pair. Code must ensure `ref_id` is populated from a flushed record's
`.id` before commit.

---

## Section 3 — Core Flows

### Flow 1: Stock Entry Flow

**Trigger:** POST `/stock-entries` with a `StockEntryCreate` payload.

| Step | Action | Layer |
|------|--------|-------|
| 1 | Receive and validate `StockEntryCreate` payload | API Layer |
| 2 | Check financial lock for the warehouse + date | Service Layer |
| 3 | Resolve or create `Batch` for (item, warehouse); `db.flush()` → batch.id available | Service Layer |
| 4 | Create `StockEntry` record; `db.flush()` → `stock_entry.id` available | Service Layer |
| 5 | Call `create_inventory_txn(txn_type="IN", ref_type="stock_entry", ref_id=stock_entry.id)` | Service → Ledger Layer |
| 6 | Quantize `raw_qty` and `base_qty` to `Decimal("0.001")`; validate warehouse provenance | Ledger Layer |
| 7 | `db.add(InventoryTxn(...))` + `db.flush()` | Ledger Layer |
| 8 | Emit `DomainEvent` of type `InventoryTxnCommitted` | Ledger Layer |
| 9 | Update `batch.quantity += base_qty` | Service Layer |
| 10 | Call `log_action` (audit write, same session) | Service → Audit Layer |
| 11 | `db.commit()` — single, atomic; all above writes commit together | Service Layer |
| 12 | Return created `StockEntry` as JSON response | API Layer |

**Service function:** `backend/app/services/stock_entry.py::create_stock_entry`

---

### Flow 2: Dispatch Flow

**Trigger:** POST `/dispatch-entries` with a `DispatchEntryCreate` payload.

| Step | Action | Layer |
|------|--------|-------|
| 1 | Receive and validate `DispatchEntryCreate` payload | API Layer |
| 2 | Validate `Idempotency-Key` header present | API Layer |
| 3 | Check financial lock for warehouse + dispatch_date | Service Layer |
| 4 | Load and validate `Batch` — confirm warehouse ownership | Service Layer |
| 5 | **ORD-007 guard:** if `order_id` provided, load `Order`; verify `dispatch_qty ≤ (quantity_ordered - quantity_dispatched)`; raise `AppException(rule_id="ORD-007")` if violated — at this point no mutation has occurred | Service Layer |
| 6 | **ORD-007 guard:** verify `Order.status` not in `["Cancelled", "Completed"]`; raise if blocked | Service Layer |
| 7 | Create `DispatchEntry` record; `db.flush()` → `dispatch.id` available | Service Layer |
| 8 | Compute `canonical_qty = raw_qty × unit_conversion_factor` | Service Layer |
| 9 | Call `create_inventory_txn(txn_type="OUT", ref_type="dispatch_entry", ref_id=dispatch.id)` | Service → Ledger Layer |
| 10 | Quantize quantities; validate warehouse provenance | Ledger Layer |
| 11 | `db.add(InventoryTxn(...))` + `db.flush()` | Ledger Layer |
| 12 | Emit `DomainEvent` of type `DispatchCompleted` | Ledger Layer |
| 13 | Decrement `batch.quantity -= canonical_qty` | Service Layer |
| 14 | Update `order.quantity_dispatched` and derive `order.status` from new total | Service Layer |
| 15 | Call `log_action` (audit write, same session) | Service → Audit Layer |
| 16 | `db.commit()` — single, atomic | Service Layer |
| 17 | Return created `DispatchEntry` as JSON response | API Layer |

**Service function:** `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl`

---

### Flow 3: Mart Bill Processing Flow

**Trigger:** POST `/mart-bills` with a multipart PDF upload.

| Step | Action | Layer |
|------|--------|-------|
| 1 | Receive PDF upload; read file bytes | API Layer |
| 2 | Compute `file_hash = SHA-256(file_bytes)`; query for existing MartBill with same hash; raise `AppException(409)` if duplicate found | Service Layer |
| 3 | Save PDF bytes to storage (`backend/app/core/storage/`) | Service Layer |
| 4 | Validate PDF structure (`validate_invoice_structure`) | Service Layer |
| 5 | Parse PDF → extract DataFrame of line items, `invoice_date`, `mart_name` | Service Layer |
| 6 | Detect format type (Reliance, Blinkit, Zomato, etc.) | Service Layer |
| 7 | Check financial lock for warehouse + invoice_date | Service Layer |
| 8 | Resolve `Mart` by `mart_name`; raise `AppException(404)` if not found | Service Layer |
| 9 | Create `MartBill` with `status="NEEDS_REVIEW"`; `db.flush()` → `bill.id` available | Service Layer |
| 10 | For each parsed line: attempt alias resolution (MartItemAlias lookup) to find `item_id` | Service Layer |
| 11 | Create `MartBillItem` per line; set `resolution_status="MAPPED"` if `item_id` resolved, else `"UNRESOLVED"` | Service Layer |
| 12 | `db.commit()` — single, atomic | Service Layer |
| 13 | Return `{invoice_id, success, filename}` | API Layer |
| 14 | Human reviews `NEEDS_REVIEW` bill; resolves `UNRESOLVED` items via admin UI (manual step, separate API calls) | Mobile Layer → API Layer |
| 15 | `verify_mart_bill()` called: asserts all items are `MAPPED`; sets `status="VERIFIED"` | API → Service Layer |

**Service function:** `backend/app/services/mart_bill.py::save_and_process_mart_bill`

---

## Section 4 — State Machines

### State Machine: Order

```
                      ┌────────────────────────────────────────┐
                      │                                        │
                  [Pending] ─────────────────────────────► [Cancelled]
                      │                                        │
                      │  first dispatch created                │ (no recovery path —
                      │  0 < dispatched < ordered              │  cancelled orders
                      ▼                                        │  block ORD-007)
            [Partially Completed] ◄────────────────────────────┘
                      │   ▲
                      │   │  reversal reduces dispatched
                      │   │  below ordered (but > 0)
                      │   │
                      │   │  reversal reduces dispatched to 0
                      │   └──────────────────── [Pending] ◄──────────────────────┐
                      │                                                           │
                      │  dispatched == ordered                                    │
                      ▼                                                           │
                 [Completed] ──────────────────────────────────────────────────► │
                              reversal reduces dispatched below ordered
```

**Transitions:**

| From | To | Trigger | Code location |
|------|----|---------|---------------|
| `Pending` | `Partially Completed` | Dispatch created; `0 < quantity_dispatched < quantity_ordered` | `backend/app/services/order.py` — `compute_order_status` |
| `Pending` / `Partially Completed` | `Completed` | Dispatch created; `quantity_dispatched == quantity_ordered` | `backend/app/services/order.py` — `recompute_order_status` |
| `Pending` / `Partially Completed` | `Cancelled` | Explicit cancel API call | `backend/app/services/order.py` |
| `Completed` | `Partially Completed` | Reversal reduces `quantity_dispatched` below `quantity_ordered` | `backend/app/services/dispatch_entry.py::create_reversal_entry` → `update_order_status_after_reversal` |
| `Partially Completed` | `Pending` | Reversal reduces `quantity_dispatched` to 0 | `backend/app/services/order.py::update_order_status_after_reversal` |

**Guard:** ORD-007 blocks dispatch against any order with `status` in
`["Cancelled", "Completed"]`. Cancelled orders have no recovery path —
they permanently block further dispatch.

---

### State Machine: MartBill

```
    [Upload PDF]
         │
         ▼
   [NEEDS_REVIEW] ◄──────────────────── [VERIFIED]
         │                    unverify_mart_bill()
         │                    or file replaced
         │
         │  All items MAPPED
         │  verify_mart_bill() called
         ▼
    [VERIFIED]
```

**Transitions:**

| From | To | Trigger | Code location |
|------|----|---------|---------------|
| *(new)* | `NEEDS_REVIEW` | `save_and_process_mart_bill` — explicit `status="NEEDS_REVIEW"` on creation | `backend/app/services/mart_bill.py:159` |
| `NEEDS_REVIEW` | `VERIFIED` | `verify_mart_bill()` — all `MartBillItem.resolution_status == "MAPPED"` | `backend/app/services/mart_bill.py::_verify_mart_bill_impl:599` |
| `VERIFIED` | `NEEDS_REVIEW` | `unverify_mart_bill()` | `backend/app/services/mart_bill.py::_unverify_mart_bill_impl:673` |
| `NEEDS_REVIEW` | `NEEDS_REVIEW` | `replace_mart_bill_file()` — file replacement resets to NEEDS_REVIEW | `backend/app/services/mart_bill.py:820` |

**`PROCESSING` status note:** The `MartBill` model defines `status`
with `default="PROCESSING"`. In practice, `save_and_process_mart_bill`
sets `status="NEEDS_REVIEW"` explicitly on creation. `PROCESSING` may
appear in older records or direct DB inserts. It is a valid status in
the query layer but is not produced by any current service function.

**Blocked actions in `VERIFIED` state:**
- Edit (`update_mart_bill`) — raises `AppException(400)` if `status == "VERIFIED"`
- Delete (`delete_mart_bill`) — blocked if `status == "VERIFIED"`
- Both are unblocked by calling `unverify_mart_bill` first

---

## Section 5 — Invariant Touchpoints

Each core flow activates a set of invariants. These are the invariants
a reviewer or executor MUST check before modifying code in that flow.

### Stock Entry Flow

| Invariant | Where it applies in the flow |
|-----------|------------------------------|
| LED-001 | Step 5: `create_inventory_txn` must be called exactly once per stock entry |
| LED-002 | Steps 5–8: `InventoryTxn` row is INSERT-only; no UPDATE may be issued against it |
| LED-003 | Implicit: stock entry does not deduplicate by hash, but unique constraints on Batch prevent phantom stock |
| NUM-001 | Step 6: ledger quantities quantized to `Numeric(10,3)` |
| NUM-002 | Step 9: `batch.quantity` stored as `Numeric(18,6)` — analytical precision |
| NUM-003 | Step 6: `Decimal(str(...))` conversion applied before quantization |
| IMM-001 | Post-commit: `update_stock_entry` unconditionally raises `AppException(409)` |
| TXN-001 | Step 11: single `db.commit()` at end; all mutations atomic |

### Dispatch Flow

| Invariant | Where it applies in the flow |
|-----------|------------------------------|
| LED-001 | Step 9: `create_inventory_txn` must be called exactly once per dispatch |
| LED-002 | Steps 9–12: ledger row is INSERT-only |
| IMM-002 | Post-commit: dispatches are immutable; reversals go through `create_reversal_entry` |
| NUM-001 | Step 10: ledger quantities quantized to `Numeric(10,3)` |
| NUM-003 | Step 10: `Decimal(str(...))` conversion at system boundary |
| TXN-001 | Step 16: single `db.commit()` |
| PRC-001 | Steps 5–6: ORD-007 guard runs before any mutation (steps 7+); if it raises, no inventory has changed |
| LED-007 | Step 14: `batch.quantity` decrement and `InventoryTxn` write occur in the same transaction — if one fails, both roll back |

### Mart Bill Processing Flow

| Invariant | Where it applies in the flow |
|-----------|------------------------------|
| LED-004 | Step 2: duplicate file_hash check prevents double ledger entry from re-upload |
| IMM-003 | Steps 15 (VERIFIED state): verified bills block edit and delete |
| TXN-001 | Step 12: single `db.commit()` covers MartBill + all MartBillItems |
| PRC-004 | Step 14 (human review): UNRESOLVED items are surfaced with a resolution path (map via admin UI) — user is never left in a dead-end state |

---

## Section 6 — Critical Paths

### Critical Path 1: Dispatch Pipeline

**Files:**
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl`
- `backend/app/services/inventory_txn.py::create_inventory_txn`
- `backend/app/services/order.py::update_order_status_after_reversal`

**Why high risk:** A single dispatch transaction touches four entities
(DispatchEntry, InventoryTxn, Batch, Order) in a specific order, all
within one commit. The risks compound:

1. **Partial commit** — if `db.commit()` is called after `DispatchEntry`
   is flushed but before `create_inventory_txn` executes, the dispatch
   record exists permanently but the ledger has no matching row. The
   batch balance becomes incorrect and there is no automated recovery.

2. **ORD-007 bypass** — if the guard (steps 5–6) is moved to run after
   any mutation (step 7+), a partial dispatch is possible even if the
   guard later fails. The guard must always run before the first `db.add`.

3. **Model-level bypass** — direct assignment `batch.quantity -= qty`
   without calling `create_inventory_txn` issues a silent UPDATE with no
   ledger entry. This is the most common form of ledger divergence.

4. **Double `create_inventory_txn` call** — calling the ledger writer
   twice for the same event inflates the running balance permanently.

---

### Critical Path 2: Inventory Mutation Pipeline

**Files:**
- `backend/app/services/inventory_txn.py::create_inventory_txn`
- `backend/app/db/models/batch.py` (Batch.quantity — the bypass target)
- `backend/app/db/models/inventory_txn.py` (InventoryTxn — the ledger table)

**Why high risk:** `create_inventory_txn` is the single chokepoint for
all stock changes. It enforces `Numeric(10,3)` precision, validates
warehouse provenance, and emits the `DomainEvent`. Bypassing it — for
any reason — leaves the ledger incomplete.

The bypass is silent: SQLAlchemy does not raise when `batch.quantity`
is mutated directly. No test catches it at runtime unless a governance
test specifically scans for direct `batch.quantity` assignments outside
`inventory_txn.py`. The cost of a bypass is a permanent ledger gap that
compounds on every future query of the batch balance.

---

### Critical Path 3: Invoice Resolution Pipeline

**Files:**
- `backend/app/services/mart_bill.py::save_and_process_mart_bill`
- `backend/app/utils/invoice_parser.py` (and format variants)
- `backend/app/db/models/mart_bill_item.py` (resolution_status field)

**Why high risk:** The invoice resolution pipeline converts a PDF binary
into structured `MartBillItem` rows that drive downstream reconciliation.
Three failure modes are non-obvious:

1. **Alias resolution failure** — if an item name in the invoice has no
   matching `MartItemAlias`, the `MartBillItem` is created with
   `resolution_status="UNRESOLVED"`. Unresolved items block
   `verify_mart_bill` permanently until a human maps them. If the alias
   mapping is never done, the bill stays in `NEEDS_REVIEW` indefinitely.

2. **Duplicate upload** — without the `file_hash` deduplication guard
   (step 2), the same invoice would generate double `MartBillItem` rows,
   inflating the reconciliation totals. The guard is the sole protection;
   removing it breaks reconciliation correctness.

3. **Financial lock race** — the financial lock check (step 7) runs
   after file storage (step 3). If the lock raises, the file has already
   been saved but no DB record exists. The storage backend retains an
   orphaned file. This is a known design trade-off — the file is
   recoverable but creates storage clutter.

---

## Footer

**This file covers:** entity definitions, entity relationships, core
execution flows (step-by-step), state machines, invariant touchpoints,
and critical path risk analysis.

**What it does not cover:** layer rules and enforcement contract (see
`02-ARCHITECTURE.md`), individual invariant text (see `01-INVARIANTS.md`),
term definitions (see `04-GLOSSARY.md`).

**Next file to read:** `.agent/CORE/04-GLOSSARY.md`
