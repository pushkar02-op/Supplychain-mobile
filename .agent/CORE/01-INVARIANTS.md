# AGRO Repository — Invariants

> **These rules override anything in `.agent/legacy/` or `docs/_pending_rewrite/`.**
> If a legacy skill contradicts an invariant here, this file wins.

## How to Read This File

Each invariant has a fixed structure:

- **Rule** — one sentence, imperative, no hedge words
- **Rationale** — why it exists; what bug it prevents
- **Enforcement points** — real files and tests that catch violations
- **When triggered** — specific scenarios that activate this invariant
- **Stop condition** — when to halt and report to the human
- **Source** — where the rule was distilled from

**"STOP if..."** means: do not proceed. Write a FACT REPORT, surface it
in SESSION CLOSE, and wait for human instruction. A paused executor is
always correct. An executor that guesses is often wrong.

The 26 invariants are grouped into six categories. A Triggered-By Index
at the end maps common tasks to the invariants that apply.

---

## LEDGER & INVENTORY INTEGRITY

### LED-001: Every Mutation Creates One InventoryTxn

**Rule:** Every inventory-affecting operation MUST create exactly one
`InventoryTxn` record via `create_inventory_txn` before the operation
commits.

**Rationale:** `InventoryTxn` is the audit spine of the entire system.
Without a txn record, mutations become invisible — there is no way to
reconstruct how a batch balance reached a given state. The project
experienced multiple "wrong stock" bugs before this rule was formalized;
the common cause was code that mutated `batch.quantity` directly without
writing a ledger entry.

**Enforcement points:**
- `backend/app/services/inventory_txn.py::create_inventory_txn` — the
  single authorized write path for txn creation
- `backend/app/services/stock_entry.py::_create_stock_entry_impl` —
  calls `create_inventory_txn` before commit
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl` —
  calls `create_inventory_txn` before commit
- `backend/app/services/rejection_entry.py::create_rejection_entry` —
  calls `create_inventory_txn` before commit
- `backend/tests/test_inventory_invariants.py::test_stock_entry_creates_ledger_record` — asserts txn count after stock entry
- `backend/tests/test_inventory_invariants.py::test_dispatch_entry_creates_ledger_record` — asserts txn count after dispatch

**When triggered:**
- Writing or modifying any service function that changes `batch.quantity`
- Adding a new event type (adjustment, write-off, transfer) that affects
  inventory
- Debugging a "wrong stock balance" complaint

**Stop condition:** STOP if a proposed change mutates `batch.quantity`
or any batch-adjacent balance without calling `create_inventory_txn`
first.

**Source:** `docs/business_rules_and_enforcement.md §1 (BP-001)`,
           `.agent/legacy/skills/ledger-invariant-enforcer/SKILL.md`

---

### LED-002: InventoryTxn Is Append-Only

**Rule:** `InventoryTxn` rows MUST never be modified or deleted after
insertion; no UPDATE or DELETE statement may target the `inventory_txn`
table.

**Rationale:** The ledger is the audit trail. An UPDATE or DELETE
destroys the evidence it is meant to preserve. If the ledger can be
edited, it cannot be trusted — and every "wrong stock" investigation
becomes unfalsifiable. Historical data integrity depends entirely on
this constraint holding unconditionally.

**Enforcement points:**
- `backend/app/db/models/inventory_txn.py` — model has no update
  service method; absence of mutation path is the enforcement
- `backend/app/services/inventory_txn.py` — exposes only
  `create_inventory_txn` and `get_inventory_txns`; no update/delete
  function exists
- N/A — no automated test currently checks for the absence of
  UPDATE/DELETE on this table; flagged in Unenforced Invariants section

**When triggered:**
- Any time a bug is "fixed" by editing an existing txn row
- When a migration attempts to backfill or correct txn data
- When adding a new service that touches `inventory_txn`

**Stop condition:** STOP if any proposed SQL, ORM call, or migration
issues an UPDATE or DELETE against the `inventory_txn` table for any
reason.

**Source:** `docs/business_rules_and_enforcement.md §5 (LED-001)`,
           `.agent/legacy/skills/ledger-invariant-enforcer/SKILL.md`

---

### LED-003: Batch.quantity Is Mutable State; InventoryTxn Is Truth

**Rule:** `Batch.quantity` MUST be treated as a derived cache; the
authoritative record of inventory is the sum of `InventoryTxn` entries
for that batch.

**Rationale:** `Batch.quantity` is updated in-place as a convenience for
fast reads. It is not the source of truth. Treating it as truth causes
drift bugs: code that reads `batch.quantity` directly and makes business
decisions from it (without re-summing txns) will produce wrong answers
whenever the cache falls behind. This distinction caused multiple
UX-visible stock errors before the rule was locked.

**Enforcement points:**
- `backend/tests/test_ledger_invariants.py::test_no_direct_batch_mutation` —
  asserts that no code directly mutates `batch.quantity` outside service
  layer
- `docs/business_rules_and_enforcement.md §2 (BP-002)` — classifies
  `batch.quantity` explicitly as "Derived cache"
- N/A — no automated test verifies that business logic re-sums from
  txns rather than reading the cache; flagged in Unenforced Invariants

**When triggered:**
- Writing query logic that reads `batch.quantity` to make a blocking
  decision (e.g., "can we dispatch this?")
- Debugging a stock balance discrepancy between UI and txn history
- Designing a reporting feature that shows stock levels

**Stop condition:** STOP if you discover a code path that presents
`batch.quantity` as the canonical answer to an audit or financial query
without cross-checking against `inventory_txn` sums.

**Source:** `docs/business_rules_and_enforcement.md §2 (BP-002)`,
           `.agent/legacy/skills/receipt-batch-separation-guard/SKILL.md`

---

### LED-004: Sum of InventoryTxn Must Equal Batch.quantity

**Rule:** The sum of all `InventoryTxn.base_qty` records for a given
batch MUST equal `Batch.quantity` at all times; any divergence is a
ledger drift error.

**Rationale:** Drift between the cache (`Batch.quantity`) and the ledger
sum means a mutation occurred without a corresponding txn entry. This is
a data integrity failure, not a display bug. Drift compounds: once a
batch quantity is off by one unit, all downstream availability checks,
dispatch decisions, and financial reports become wrong. The system must
either prevent drift or detect it immediately.

**Enforcement points:**
- `backend/tests/test_inventory_invariants.py::test_ledger_drift_detection` —
  asserts that post-mutation batch quantity matches txn sum
- `backend/app/services/inventory_txn.py::create_inventory_txn` —
  enforces that every mutation goes through the single write path,
  making drift structurally harder to introduce

**When triggered:**
- After any code change to inventory-mutating services
- When investigating a stock balance complaint
- When writing a migration that touches quantity columns

**Stop condition:** STOP if post-change batch quantity does not equal the
re-summed `InventoryTxn.base_qty` for that batch; report the delta and
the code path that caused it.

**Source:** `docs/business_rules_and_enforcement.md §1 (BP-001)`,
           `backend/tests/test_inventory_invariants.py`

---

### LED-005: Quantities Are Normalized to Canonical UOM Before Ledger Write

**Rule:** All inventory mutations MUST convert input quantities to the
item's canonical UOM via `item_conversion_map` before calling
`create_inventory_txn`.

**Rationale:** The ledger stores quantities in a single canonical unit
per item. If raw units leak into `InventoryTxn`, summation across entries
becomes meaningless — you cannot add "5 kg" and "3 bags" without first
converting both to the same unit. One leak causes every inventory balance
for that item to be wrong. UOM normalization must happen before the ledger
write, not after.

**Enforcement points:**
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl` —
  computes `canonical_qty = raw_qty * factor` (line ~393) before calling
  `create_inventory_txn`
- `backend/app/services/stock_entry.py::_create_stock_entry_impl` —
  resolves canonical unit via `item_conversion_map` service before write
- `backend/app/services/item_conversion_map.py` — provides the
  conversion factor lookup
- `docs/business_rules_and_enforcement.md §4 (INV-005)` — rule definition

**When triggered:**
- Writing a new mutation path for any inventory event type
- Adding a new UOM or conversion factor
- Handling an order or dispatch where the input unit differs from the
  item's canonical unit

**Stop condition:** STOP if a proposed service function writes to
`create_inventory_txn` using the raw input quantity without first
looking up and applying the conversion factor from `item_conversion_map`.

**Source:** `docs/business_rules_and_enforcement.md §6 (UOM-001, UOM-003)`,
           `.agent/legacy/skills/ledger-invariant-enforcer/SKILL.md`

---

### LED-006: Every Mutation Respects warehouse_id Isolation

**Rule:** Every `InventoryTxn` MUST carry a non-NULL `warehouse_id`; any
mutation that cannot resolve a warehouse MUST fail before writing.

**Rationale:** The system supports multiple warehouses. A txn without a
`warehouse_id` is unattributable — it cannot be included in
warehouse-scoped reports, KPI calculations, or financial summaries.
Historically, NULL `warehouse_id` records caused silent data gaps in
per-warehouse stock views, which only surfaced during month-end audits.

**Enforcement points:**
- `backend/app/services/inventory_txn.py::create_inventory_txn` —
  raises `AppException` if `warehouse_id` resolves to None (lines ~55-59)
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl` —
  checks `batch.warehouse_id` and validates against provided
  `warehouse_id` before proceeding (lines ~282-290)
- `backend/app/services/stock_entry.py::_create_stock_entry_impl` —
  resolves `warehouse_id` via `resolve_system_warehouse_id` before write

**When triggered:**
- Adding any new inventory mutation endpoint
- Testing a path where warehouse context is optional or implicit
- Writing a migration that creates `InventoryTxn` rows directly

**Stop condition:** STOP if any code path reaches `create_inventory_txn`
with `warehouse_id=None` and does not raise before the write.

**Source:** `docs/business_rules_and_enforcement.md §2 (BP-002)`,
           `backend/app/services/inventory_txn.py`

---

### LED-007: Reversals Are New Ledger Entries, Never Modifications

**Rule:** Corrections to dispatch or rejection events MUST create new
`InventoryTxn` entries with opposite sign; the original txn MUST remain
unchanged.

**Rationale:** Modifying an existing txn to "undo" a transaction destroys
the audit trail. The reversal itself is an event that happened at a
specific time, created by a specific user. That event must be recorded.
Additive reversals mean the ledger always shows the full history: original
event, reversal event, and net balance — with no gaps.

**Enforcement points:**
- `backend/app/services/dispatch_entry.py::create_reversal_entry` —
  creates a new `DispatchReversal` and calls `create_inventory_txn` with
  a positive `base_qty` to restore stock
- `backend/app/services/rejection_entry.py::reverse_rejection_entry` —
  creates a compensating entry, does not modify the original rejection
  txn
- `docs/business_rules_and_enforcement.md §14 (D-002, D-004)` — dispatch
  correction model

**When triggered:**
- Implementing any "undo", "correct", or "cancel" action on a dispatched
  or rejected quantity
- A user asks to "edit" a dispatch or rejection entry

**Stop condition:** STOP if a proposed correction path issues an UPDATE
or DELETE against any `InventoryTxn` row rather than inserting a new
compensating entry.

**Source:** `docs/business_rules_and_enforcement.md §14 (D-002)`,
           `.agent/legacy/skills/immutable-event-correction/SKILL.md`

---

### LED-008: Dispatch Cannot Exceed Remaining Order Quantity

**Rule:** A dispatch entry MUST be rejected with HTTP 409 if its quantity
would cause `SUM(dispatch.quantity)` to exceed `order.quantity_ordered`
for that order.

**Rationale:** Over-dispatch indicates order integrity failure. If more
goods leave the warehouse than were ordered, the order relationship is
corrupt and financial reconciliation against mart bills becomes
impossible. The check must happen before any inventory mutation — if it
fails, inventory must remain untouched. This is business rule ORD-007.

**Enforcement points:**
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl` —
  ORD-007 enforcement block at lines ~297-375; checks
  `existing_dispatched + dispatch_qty <= quantity_ordered` and raises
  before any batch mutation
- `backend/tests/test_phase4c_ord007.py::test_ord007_block_over_dispatch` —
  asserts 409 on over-dispatch
- `backend/tests/test_phase4c_ord007.py::test_ord007_no_inventory_mutation_on_failure` —
  asserts batch quantity is unchanged after a blocked dispatch
- `backend/tests/test_phase4c_ord007.py::test_ord007_block_dispatch_cancelled_order` —
  asserts cancelled orders cannot receive dispatch

**When triggered:**
- Writing or modifying `create_dispatch_entry` or
  `create_dispatch_from_order`
- Adding a bulk dispatch feature
- Handling an edge case where order status is Cancelled or Completed

**Stop condition:** STOP if a proposed dispatch path reaches inventory
mutation code without first executing the ORD-007 quantity guard.

**Source:** `docs/business_rules_and_enforcement.md §9 (ORD-007)`,
           `backend/tests/test_phase4c_ord007.py`

---

## NUMERIC SAFETY

### NUM-001: All Quantity/Price Math Uses Decimal, Never float

**Rule:** All arithmetic involving inventory quantities, prices, costs,
or financial totals MUST use `decimal.Decimal` operands; Python `float`
is forbidden in this arithmetic path.

**Rationale:** IEEE 754 floating-point arithmetic introduces rounding
errors that accumulate across operations. In inventory math, `0.1 + 0.2`
evaluates to `0.30000000000000004` in float — not `0.3`. Over hundreds of
transactions, these errors produce ledger drift that cannot be traced to
any single mutation. The `TypeError: unsupported operand type(s) for *:
'decimal.Decimal' and 'float'` error is the runtime symptom; silent
precision loss is the real risk.

**Enforcement points:**
- `backend/tests/test_governance_decimal_safety.py::test_no_float_cast_in_services` —
  scans all service files for `float(...)` calls and fails if found
- `backend/tests/test_governance_decimal_safety.py::test_no_float_schema_fields` —
  checks Pydantic schema annotations for float on quantity/price fields
- `backend/tests/test_governance_no_float_models.py::test_no_float_columns_in_models_except_forecast` —
  scans SQLAlchemy models for `Column(Float)` outside the allowlist
- `backend/tests/test_decimal_integrity.py::test_decimal_summation_preserves_precision` —
  verifies precision is preserved across real DB roundtrips

**When triggered:**
- Writing any arithmetic expression involving quantity, price, amount,
  cost, rate, or total
- Adding a new field to a schema that represents a monetary or quantity value
- Consuming an external API or file that returns numeric strings

**Stop condition:** STOP if you write or encounter `float(qty)`,
`float(price)`, or any arithmetic expression mixing `Decimal` and `float`
operands.

**Source:** `docs/business_rules_and_enforcement.md §10 (NUM-001)`,
           `.agent/legacy/skills/decimal-purity-enforcement/SKILL.md`

---

### NUM-002: Database Columns for Money/Quantity Use Numeric(18,6) with asdecimal=True

**Rule:** SQLAlchemy columns storing quantity or price values MUST use
`Numeric(18, 6, asdecimal=True)` for analytical models and
`Numeric(10, 3, asdecimal=True)` for ledger storage; `Float` or
`DOUBLE PRECISION` are forbidden outside the forecast allowlist.

**Rationale:** Without `asdecimal=True`, SQLAlchemy returns Python
`float` from DB reads — negating all Decimal discipline in service code.
Without the correct precision/scale, values are silently truncated on
write. The `InventoryTxn` ledger uses `Numeric(10,3)` (accepting
quantization noise < 0.001); analytical models (`Batch`, `Order`,
`Rejection`) use `Numeric(18,6)` for financial precision.

**Enforcement points:**
- `backend/tests/test_governance_no_float_models.py::test_no_float_columns_in_models_except_forecast` —
  blocks `Column(Float)` in models outside the allowlist
- `backend/tests/test_governance_no_float_models.py::test_no_double_precision_in_view_sql_definitions` —
  blocks `DOUBLE PRECISION` in view SQL
- `backend/app/services/inventory_txn.py::create_inventory_txn` —
  quantizes inputs to 3 decimal places before write (lines ~25-29)

**When triggered:**
- Adding a new SQLAlchemy model column for quantity, price, or cost
- Writing a migration that alters column types
- Adding a new SQL view or materialized view

**Stop condition:** STOP if a proposed model column for quantity or price
uses `Float`, `DOUBLE PRECISION`, or `Numeric` without `asdecimal=True`.

**Source:** `docs/business_rules_and_enforcement.md §10 (NUM-001)`,
           `.agent/legacy/skills/decimal-purity-enforcement/SKILL.md`

---

### NUM-003: Input Conversion Uses Decimal(str(value)), Never float()

**Rule:** When converting external input (API payload, file data, env
var) to a numeric type, code MUST use `Decimal(str(value))` and MUST NOT
use `float(value)` as an intermediate step.

**Rationale:** `Decimal(float_value)` inherits the float's imprecision —
`Decimal(0.1)` yields `Decimal('0.1000000000000000055511151231257827021181583404541015625')`.
The safe path is always `Decimal(str(value))`, which parses the decimal
string representation without floating-point contamination. This pattern
is required at every system boundary: API input, file parsing, env-var
reading, and test fixture creation.

**Enforcement points:**
- `backend/tests/test_governance_decimal_safety.py::test_no_float_cast_in_services` —
  scans service layer for `float(...)` invocations
- `backend/app/services/inventory_txn.py::create_inventory_txn` —
  uses `Decimal(str(data.raw_qty))` and `Decimal(str(data.base_qty))`
  (lines ~25-29)
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl` —
  uses `Decimal(str(...))` for quantity calculations

**When triggered:**
- Reading any numeric value from an HTTP request body or query parameter
- Parsing a CSV, JSON, or Excel file containing quantities or prices
- Reading a numeric threshold from an environment variable

**Stop condition:** STOP if you write `float(value)` where `value` is a
quantity, price, or financial amount and the result feeds into any
arithmetic or ledger write.

**Source:** `.agent/legacy/skills/decimal-purity-enforcement/SKILL.md`,
           `backend/app/services/inventory_txn.py`

---

## IMMUTABILITY & CORRECTION

### IMM-001: Stock Entries Are Immutable After Creation

**Rule:** Stock entry records MUST NOT be modified after creation; the
`update_stock_entry` service function raises `AppException` and the PUT
endpoint exists solely to surface that error.

**Rationale:** A stock entry represents a physical receipt of goods at a
specific time. Editing it retroactively corrupts the audit trail and
makes historical reconciliation against supplier invoices impossible.
Corrections are handled via `create_stock_adjustment`, which creates a
new `InventoryTxn` entry documenting the delta.

**Enforcement points:**
- `backend/app/services/stock_entry.py::update_stock_entry` — raises
  `AppException("Stock entries are immutable. Use adjustment or reversal.",
  status_code=409)` unconditionally
- `backend/app/api/stock_entry.py::update` — routes PUT requests to
  `update_stock_entry`; always returns 409
- `backend/tests/test_stock_entry_invariants.py::test_stock_entry_is_immutable` —
  asserts 409 on PUT attempt

**When triggered:**
- A user requests to edit a received quantity or date on an existing
  stock entry
- Writing a migration or admin script that attempts to "fix" a stock
  entry record
- Reviewing a PR that adds or restores a non-blocking update path for
  stock entries

**Stop condition:** STOP if any proposed change removes the
`AppException` raise from `update_stock_entry` or adds a new service
path that mutates an existing `StockEntry` row's core fields.

**Source:** `.agent/legacy/skills/immutable-event-correction/SKILL.md`,
           `backend/app/services/stock_entry.py`

---

### IMM-002: Dispatch Entries Are Immutable; Corrections Use DispatchReversal

**Rule:** Dispatch entry records MUST NOT be edited or physically deleted;
any correction MUST create a `DispatchReversal` entry via
`create_reversal_entry`.

**Rationale:** A dispatch entry represents a delivery of goods to a mart.
That event happened. Editing it would misrepresent operational history
and break the order quantity tracking (`quantity_dispatched` is derived
from dispatch records). Reversals restore inventory through the ledger and
update order status via `update_order_status_after_reversal`.

**Enforcement points:**
- `backend/app/services/dispatch_entry.py::create_reversal_entry` —
  creates `DispatchReversal`, calls `create_inventory_txn` with positive
  qty to restore stock, calls `update_order_status_after_reversal`
- `backend/app/api/dispatch_entry.py` — no PUT endpoint exists for
  dispatch entries; absence of route is the enforcement
- `docs/business_rules_and_enforcement.md §14 (D-001, D-002)` — dispatch
  immutability and correction model

**When triggered:**
- A user reports "wrong dispatch quantity" and requests a correction
- Building a dispatch history or audit screen
- Adding a new route to the dispatch API

**Stop condition:** STOP if a proposed change adds a PUT or PATCH route
to `dispatch_entry.py`, or modifies an existing `DispatchEntry` row
outside of the `create_reversal_entry` path.

**Source:** `docs/business_rules_and_enforcement.md §14 (D-001, D-002)`,
           `.agent/legacy/skills/immutable-event-correction/SKILL.md`

---

### IMM-003: Rejections Are Immutable; Corrections Use Compensating Adjustments

**Rule:** Rejection entry records MUST NOT be edited; corrections MUST
use `reverse_rejection_entry`, which creates a new compensating
`InventoryTxn` entry.

**Rationale:** A rejection entry records goods refused at delivery — a
physical, auditable event. Editing it would break the rejection audit
trail and potentially corrupt warehouse stock levels if the original
txn's inventory effect is not properly reversed. The compensating entry
model preserves full history.

**Enforcement points:**
- `backend/app/services/rejection_entry.py::reverse_rejection_entry` —
  creates a compensating entry, calls `create_inventory_txn`, does not
  touch the original rejection row
- `backend/app/api` — no PUT endpoint exists for rejection entries
- `backend/tests/test_rejection_reversal.py` — tests the reversal path
  end-to-end

**When triggered:**
- A user reports a rejection was recorded against the wrong item or
  quantity
- Adding any "edit" or "correct" feature to the rejections screen
- Writing a migration that touches the `rejection_entry` table

**Stop condition:** STOP if any proposed path issues an UPDATE against an
existing `RejectionEntry` row rather than calling `reverse_rejection_entry`.

**Source:** `docs/business_rules_and_enforcement.md §14`,
           `.agent/legacy/skills/immutable-event-correction/SKILL.md`

---

## TRANSACTIONAL & PERSISTENCE

### TXN-001: Service Functions Follow create→flush→mutate→commit Order

**Rule:** Service functions that create a primary record and then
reference its database-generated ID MUST call `db.flush()` after the
initial `db.add()` and before using `.id` on the new object.

**Rationale:** SQLAlchemy does not assign a database-generated primary
key until the INSERT is executed. Calling `db.flush()` sends the INSERT
to the database within the current transaction, making the `.id`
available without committing. Using `.id` before `flush()` produces
`None`, causing `ref_id=None` in the dependent `InventoryTxn` — a
constraint violation or silent null reference.

**Enforcement points:**
- `backend/app/services/stock_entry.py::_create_stock_entry_impl` —
  calls `db.flush()` at line ~105 and ~213 before using
  `ref_id=stock_entry.id`
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl` —
  calls `db.flush()` at line ~427 and ~444 before using dispatch `.id`
- `backend/app/services/inventory_txn.py::create_inventory_txn` —
  calls `db.flush()` at line ~69 to ensure warehouse assignment
- N/A — no automated governance test verifies the flush-before-ref_id
  pattern; flagged in Unenforced Invariants

**When triggered:**
- Writing a new service function that creates a record and passes its
  `.id` to a second `db.add()` call
- Modifying `create_inventory_txn` or any of its callers

**Stop condition:** STOP if you write code that references `.id` on a
newly `db.add()`-ed object before calling `db.flush()`.

**Source:** `backend/app/services/inventory_txn.py`,
           `backend/app/services/stock_entry.py`

---

### TXN-002: One Commit Per Service Function; Rollback on Any Failure

**Rule:** Each service function MUST contain exactly one `db.commit()`
call and MUST call `db.rollback()` in the exception path before
re-raising.

**Rationale:** Multiple commits in a single function make partial
completion possible: the first commit succeeds, the second fails, and the
DB is left in an inconsistent half-written state with no recovery path.
Missing rollback means a failed transaction leaves the session dirty,
which can corrupt subsequent operations in the same request. Both
patterns have caused production data integrity issues.

**Enforcement points:**
- `backend/tests/test_governance_transactions.py::test_no_multiple_commit_calls_per_service_function` —
  scans 6 critical service files for functions with more than one
  `db.commit()` call
- `backend/tests/test_governance_transactions.py::test_rollback_present_in_exception_paths` —
  checks that listed wrapper functions contain `db.rollback(`
- `backend/tests/test_governance_transaction_policy.py::test_no_multiple_db_commits_per_function` —
  scans all service files for multiple-commit violations

**When triggered:**
- Writing any new service function that calls `db.commit()`
- Modifying an existing service function in the scoped list
  (`auth.py`, `dispatch_entry.py`, `mart_bill.py`, `reconciliation.py`,
  `stock_entry.py`, `event_relay.py`)
- Refactoring a service function that calls a helper that commits

**Stop condition:** STOP if a governance test in this category fails
after your change; do not merge until the test is green.

**Source:** `backend/tests/test_governance_transactions.py`,
           `backend/tests/test_governance_transaction_policy.py`

---

### TXN-003: ref_id on InventoryTxn Must Never Be NULL

**Rule:** The `ref_id` field on every `InventoryTxn` row MUST be set to
the integer primary key of the causing record before `db.commit()` is
called; `ref_id=None` is a data integrity failure.

**Rationale:** `ref_id` links each ledger entry back to its cause (stock
entry, dispatch, rejection, adjustment). A NULL `ref_id` makes the txn
unattributable — it cannot be traced during an audit, and it breaks the
ability to reconstruct events by cause. The fix is always `db.flush()`
before reading `.id` (see TXN-001), not setting `ref_id` after commit.

**Enforcement points:**
- `backend/app/services/stock_entry.py::_create_stock_entry_impl` —
  passes `ref_id=stock_entry.id` after `db.flush()` at line ~208
- `backend/app/services/dispatch_entry.py::_create_dispatch_entry_impl` —
  passes `ref_id=dispatch.id` at line ~464 after flush
- N/A — no automated test asserts that `inventory_txn.ref_id` is never
  NULL; flagged in Unenforced Invariants

**When triggered:**
- Adding a new event type that creates `InventoryTxn` records
- Modifying the call sequence in `_create_stock_entry_impl` or
  `_create_dispatch_entry_impl`
- Writing a migration that inserts `InventoryTxn` rows directly

**Stop condition:** STOP if a proposed code path calls
`create_inventory_txn` with `ref_id=None` or with a variable whose value
has not yet been populated by a `db.flush()`.

**Source:** `backend/app/services/inventory_txn.py`,
           `backend/app/services/stock_entry.py`

---

### TXN-004: Alembic Migrations Must Have Exactly One Head Revision

**Rule:** At all times, `alembic heads` MUST return exactly one revision;
any state with multiple heads MUST be resolved with a merge migration
before new work proceeds.

**Rationale:** Multiple Alembic heads block `alembic upgrade head` from
running deterministically. CI failures with "Multiple head revisions"
stall all deployments. The problem is caused by two branches both
creating migrations with the same `down_revision`, which happens when
working off a shared base without checking the current head first. It
takes longer to untangle than to prevent.

**Enforcement points:**
- `backend/alembic/versions/` — migration files; `down_revision` must
  reference the current single head
- N/A — no automated governance test runs `alembic heads`; flagged in
  Unenforced Invariants
- Manual check: run `alembic heads` before creating any migration

**When triggered:**
- Creating a new Alembic migration
- Merging a branch that contains a migration
- Resolving a CI failure that mentions "multiple head revisions"

**Stop condition:** STOP if `alembic heads` returns more than one
revision; create a merge migration (`alembic merge heads`) and verify
`alembic heads` returns one before proceeding.

**Source:** `.agent/legacy/skills/alembic-chain-integrity/SKILL.md`

---

## TEST DISCIPLINE

### TST-001: Tests Create All Their Own Fixture Data

**Rule:** Every test function MUST create all data it depends on within
its own scope; no test may rely on data created by another test or on
shared global state.

**Rationale:** Tests that share state fail non-deterministically based on
execution order. "Works in isolation, fails in suite" is the signature
symptom. The `conftest.py::db_session` fixture uses `scope="function"`
and calls `Base.metadata.drop_all()` on teardown, giving each test a
clean schema. Any test that assumes pre-existing data bypasses this
guarantee and becomes a flaky test waiting to surface in CI.

**Enforcement points:**
- `backend/tests/conftest.py::db_session` — `scope="function"` fixture
  that creates tables on entry and drops all on exit, enforcing isolation
  structurally
- `backend/tests/conftest.py::client` — also `scope="function"`, ensures
  each test gets a fresh HTTP client and clean dependency overrides
- `.agent/legacy/skills/test-isolation-enforcement/SKILL.md` — step-by-step
  enforcement strategy

**When triggered:**
- Writing any new test that touches the database
- Debugging a test that passes alone but fails in the full suite
- Adding a pytest fixture to `conftest.py`

**Stop condition:** STOP if a test you are writing calls a query for data
it did not create within that function (or a fixture called by that
function); restructure to create the dependency explicitly.

**Source:** `.agent/legacy/skills/test-isolation-enforcement/SKILL.md`,
           `backend/tests/conftest.py`

---

### TST-002: Test Payloads Include Every Required Field from Pydantic *Create Schemas

**Rule:** Every test payload that exercises a `*Create` schema endpoint
MUST include all fields that lack a default value in that schema; missing
required fields MUST be fixed before the test runs.

**Rationale:** Tests with missing required fields fail with
`ValidationError: Field required` — not a business logic failure, just
an incomplete test. These failures are indistinguishable from real
validation failures in CI logs and waste debugging time. Schema drift
(a new required field added to the schema) silently breaks existing
tests if they were already missing fields.

**Enforcement points:**
- `backend/tests/test_governance_decimal_safety.py::test_no_float_schema_fields` —
  scans schemas for float annotations (adjacent concern; no direct
  required-field enforcement test exists)
- `.agent/legacy/skills/test-schema-compliance/SKILL.md` — step-by-step
  enforcement strategy: locate the `*Create` schema, list fields without
  defaults, verify test payload includes all of them
- N/A — no automated test checks that all test payloads include required
  fields; flagged in Unenforced Invariants

**When triggered:**
- Writing a new test for any endpoint that accepts a `*Create` schema
- Modifying a `*Create` schema to add or remove a required field
- Debugging a `ValidationError: Field required` failure in a test

**Stop condition:** STOP if a test fails with `ValidationError: Field
required`; identify the missing field in the schema before adding it to
the payload.

**Source:** `.agent/legacy/skills/test-schema-compliance/SKILL.md`

---

### TST-003: Governance Tests Must Remain Green

**Rule:** All tests in `backend/tests/test_governance_*.py` MUST pass
after every code change; a governance test failure is a blocking error,
not a warning.

**Rationale:** Governance tests are not feature tests — they are
structural assertions about the codebase itself. A failing governance
test means the codebase has drifted from its own rules. These tests were
written because the rules they enforce were previously violated and caused
real bugs. A green governance suite is a minimum bar, not a quality
signal.

**Enforcement points:**
- `backend/tests/test_governance_decimal_safety.py` — NUM rules
- `backend/tests/test_governance_no_float_models.py` — NUM rules
- `backend/tests/test_governance_transaction_policy.py` — TXN-002
- `backend/tests/test_governance_transactions.py` — TXN-002
- `backend/tests/test_governance_error_contract.py` — error envelope structure
- `backend/tests/test_governance_observability.py` — structured logging,
  no print statements
- `backend/tests/test_governance_thresholds.py` — no magic threshold literals
- `backend/tests/test_governance_authorization.py` — admin route role
  enforcement

**When triggered:**
- After any change to service files, model files, schema files, or API
  files
- Before creating a PR
- After resolving a merge conflict

**Stop condition:** STOP if any `test_governance_*.py` test fails after
your change; do not push until the governance suite is green.

**Source:** `backend/tests/test_governance_*.py` (all 8 files)

---

## PROCESS & UX

### PRC-001: One Feature = One Branch = One PR; Commits Represent Phases

**Rule:** Each feature or fix MUST live on its own branch and be merged
via exactly one PR; commits within that branch MUST map to discrete
phases of the work, not accumulate mixed concerns.

**Rationale:** Mixed-concern branches create merge conflicts, complicate
reviews, and make `git bisect` useless. When a branch contains both a
bug fix and a refactor, rolling back one without the other becomes
impossible. Single-concern branches and phase-scoped commits are the
minimum unit of reversibility.

**Enforcement points:**
- N/A — currently unenforced, relies on agent discipline
- `.agent/legacy/skills/branch-phase-discipline/SKILL.md` — strategy:
  one branch per phase, clean working tree, no unrelated changes

**When triggered:**
- Starting any new feature or fix
- Noticing that the current branch contains changes unrelated to its
  stated purpose
- Before pushing or creating a PR

**Stop condition:** STOP if the current branch contains uncommitted
changes that belong to a different feature or fix; either stash them or
surface the conflict in SESSION CLOSE.

**Source:** `.agent/legacy/skills/branch-phase-discipline/SKILL.md`

---

### PRC-002: Clean Working Tree Before Any New Phase

**Rule:** `git status` MUST show a clean working tree before starting
any new phase of work; no uncommitted changes may exist when a new
branch is created.

**Rationale:** Starting a new phase with a dirty working tree risks
carrying unrelated changes into the new branch. Those changes may be
committed accidentally or interfere with the new phase's intent.
A clean tree is also the precondition for `git stash`, `git checkout`,
and branch creation to behave predictably.

**Enforcement points:**
- N/A — currently unenforced, relies on agent discipline
- `.agent/legacy/skills/branch-phase-discipline/SKILL.md` — explicit
  step: verify `git status` clean before any push or branch creation

**When triggered:**
- Before creating a new branch
- Before pulling origin
- At the start of every executor session

**Stop condition:** STOP if `git status` shows modified or staged files
when a new phase brief is received; resolve (commit, stash, or discard)
before proceeding.

**Source:** `.agent/legacy/skills/branch-phase-discipline/SKILL.md`

---

### PRC-003: List Endpoints Must Paginate; No Unbounded Reads

**Rule:** Every API endpoint that returns a list of records MUST accept
`skip` and `limit` parameters and MUST NOT call `.all()` on a query
against tables expected to grow unboundedly.

**Rationale:** Unbounded reads are a time-bomb. A query that returns 100
records today returns 100,000 next year. At that scale, it times out,
OOMs the server, or blocks the DB. The pattern `.all()` on a large table
is the exact failure mode this rule prevents. Pagination is cheaper to
add now than to retrofit under load.

**Enforcement points:**
- `backend/app/services/dispatch_entry.py::get_all_dispatch_entries` —
  accepts `skip: int = 0, limit: int = 100`; uses
  `get_pagination_params` and `.offset().limit()` (lines ~924-997)
- `backend/app/services/stock_entry.py::get_all_stock_entries` —
  accepts `skip: int = 0, limit: int = 100`; uses `.offset(skip).limit(limit)` (line ~299)
- `backend/app/api/dispatch_entry.py` — exposes `skip` and `limit` as
  `Query` params (lines ~122-123)
- `.agent/legacy/skills/pagination-before-scale/SKILL.md` — explicit
  enforcement strategy

**When triggered:**
- Adding any new list or history endpoint to the API
- Adding an admin screen that fetches historical records
- Adding a new table that will grow with operational volume

**Stop condition:** STOP if a proposed list endpoint lacks `skip`/`limit`
parameters or calls `.all()` on a table with more than a few hundred
rows of expected data.

**Source:** `.agent/legacy/skills/pagination-before-scale/SKILL.md`,
           `backend/app/services/dispatch_entry.py`

---

### PRC-004: Blocked Actions Must Have a Documented Recovery Path

**Rule:** Any validation error or blocking guardrail that prevents a user
action MUST include a documented recovery path; no blocked action may
leave the user in a state with no forward option.

**Rationale:** The Rejection Void Trap was a major incident: a validation
error blocked a user action, but the error message did not explain how to
resolve the block. The user had no path forward without admin
intervention. "Void traps" — states that are reachable but irreversible
without special access — erode trust and cause support escalations. Every
block must have a corresponding unlock.

**Enforcement points:**
- `backend/tests/test_governance_error_contract.py::test_all_api_errors_have_rule_id_format` —
  asserts all errors carry `rule_id`, `detail`, and `metadata` fields;
  `rule_id` provides the recovery reference
- `backend/app/core/exceptions.py::AppException` — structured error
  model that callers must populate with `detail` explaining the block
- `.agent/legacy/skills/void-trap-prevention/SKILL.md` — step-by-step
  strategy: identify downstream dependencies, ensure reversal path exists

**When triggered:**
- Implementing any validation that blocks a user action (delete, dispatch,
  cancellation)
- Adding a new guardrail to an existing service
- Designing a UI state where a record is locked or read-only

**Stop condition:** STOP if a proposed guardrail blocks an action but
provides no path for the user to resolve the block; document the recovery
path before implementing the block.

**Source:** `.agent/legacy/skills/void-trap-prevention/SKILL.md`,
           `backend/tests/test_governance_error_contract.py`

---

### PRC-005: Error Copy Must Explain Cause AND Resolution

**Rule:** Every user-facing error message — in API responses, Flutter UI,
and validation dialogs — MUST state what went wrong AND what the user
should do next; generic messages like "Something went wrong" are
forbidden.

**Rationale:** Misleading copy caused user confusion even when the
underlying logic was correct. A user who sees "Something went wrong"
cannot distinguish a network timeout from a business rule violation from
a server crash. They cannot act. An error that names the cause and the
resolution empowers the user to fix the problem without contacting
support.

**Enforcement points:**
- `backend/tests/test_governance_error_contract.py::test_all_api_errors_have_rule_id_format` —
  asserts that every API error has a non-empty `detail` string and a
  `rule_id` that the user or support can look up
- `backend/tests/test_governance_error_contract.py::test_no_raw_http_exception_leaks` —
  asserts no raw `HTTPException` leaks from router layer (which would
  bypass the structured error contract)
- `.agent/legacy/skills/ux-copy-truthfulness/SKILL.md` — enforcement
  strategy: replace generic errors with actionable copy; explain cause +
  resolution; avoid blame language

**When triggered:**
- Writing an error message for any API exception
- Adding a Flutter snackbar, dialog, or inline error message
- Reviewing copy in any confirmation or blocking dialog

**Stop condition:** STOP if a proposed error message contains only a
generic phrase ("Something went wrong", "Error occurred", "Failed") with
no actionable detail; rewrite it to name the cause and the resolution.

**Source:** `.agent/legacy/skills/ux-copy-truthfulness/SKILL.md`,
           `backend/tests/test_governance_error_contract.py`

---

## Triggered-By Index

| If you are doing... | Invariants that apply |
|---|---|
| Writing/editing inventory service code | LED-001, LED-002, LED-003, LED-004, LED-005, LED-006, LED-007, NUM-001, NUM-002, NUM-003, TXN-001, TXN-002, TXN-003 |
| Writing/editing dispatch service code | LED-001, LED-005, LED-006, LED-007, LED-008, IMM-002, NUM-001, NUM-003, TXN-001, TXN-002, TXN-003 |
| Writing/editing stock entry service code | LED-001, LED-005, LED-006, IMM-001, NUM-001, NUM-003, TXN-001, TXN-002, TXN-003 |
| Writing/editing rejection service code | LED-001, LED-005, LED-006, IMM-003, NUM-001, NUM-003, TXN-001, TXN-002, TXN-003 |
| Writing/editing order service code | LED-008, NUM-001, NUM-002, TXN-001, TXN-002 |
| Authoring or modifying tests | TST-001, TST-002, TST-003 |
| Writing an Alembic migration | TXN-004, NUM-002 |
| Adding or modifying an API endpoint | PRC-003, PRC-004, PRC-005, TST-003 |
| Adding a SQLAlchemy model or column | NUM-001, NUM-002 |
| Writing or modifying Pydantic schemas | NUM-001, TST-002 |
| Writing UX copy or error messages | PRC-004, PRC-005 |
| Starting a new phase or feature | PRC-001, PRC-002 |
| Pushing or creating a PR | PRC-001, PRC-002, TST-003 |
| Debugging a stock balance discrepancy | LED-001, LED-002, LED-003, LED-004, LED-006 |
| Implementing a correction or undo flow | LED-007, IMM-001, IMM-002, IMM-003 |

---

## Unenforced Invariants (Future Work)

The following invariants have no automated code enforcement. They rely
entirely on agent discipline and code review. Adding enforcement is
recommended before the codebase scales further.

| Invariant | Gap | Suggested Enforcement |
|---|---|---|
| **LED-002** | No test checks for absence of UPDATE/DELETE on `inventory_txn` | Add a governance test that scans service/migration files for SQL UPDATE or ORM calls targeting `InventoryTxn` |
| **TXN-001** | No test verifies flush-before-ref_id pattern | Add an AST-based governance test scanning for `.id` access after `db.add()` without intervening `db.flush()` |
| **TXN-003** | No test asserts `ref_id` is never NULL on committed rows | Add a DB-level integration test that asserts `inventory_txn.ref_id IS NOT NULL` after each creation path |
| **TXN-004** | No CI step runs `alembic heads` | Add `alembic heads` to CI pre-migration gate; fail if count != 1 |
| **PRC-001** | Branch discipline not checked by tooling | Add a git hook or CI check that validates branch name convention |
| **PRC-002** | Clean tree not verified before phase start | Not automatable without executor runtime hooks |
| **TST-002** | No test checks all `*Create` payloads include required fields | Add a governance test that imports `*Create` schemas and verifies test fixture payloads against required field lists |

---

**Next file to read:** `.agent/CORE/02-ARCHITECTURE.md`
