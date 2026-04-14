# AGRO Repository — System Architecture

> **This file is canonical.** It defines the system's layer structure,
> execution flows, forbidden patterns, and invariant enforcement model.
> It does NOT restate invariants — read `01-INVARIANTS.md` for those.
> It does NOT describe historical state — read the code for that.

---

## Section 1 — System Layers

The system is composed of six layers. Each layer has a defined
responsibility boundary. Crossing that boundary — in either direction,
for any reason — is a structural violation.

---

### Layer 1: API Layer

**Path:** `backend/app/api/`

**Responsibility:** Receive HTTP requests, authenticate the caller,
validate request shape, delegate to the service layer, and return
a structured HTTP response. The API layer owns the HTTP contract.

**Allowed:**
- Parse and validate incoming request bodies via Pydantic schemas
- Authenticate and authorize the caller (via dependency injection from
  `backend/app/core/auth.py`)
- Call exactly one service function per endpoint handler
- Catch `AppException` raised by the service layer and convert it to
  an HTTP response
- Return structured JSON responses with `rule_id`, `detail`, `metadata`
  fields when errors occur

**Must NOT:**
- Contain business logic (quantity guards, immutability checks, ledger
  writes, price calculations)
- Query the database directly — `db` sessions passed to the API layer
  exist only to be forwarded to the service layer
- Raise raw `HTTPException` — all domain errors must be `AppException`
  from `backend/app/core/exceptions.py`
- Call `db.commit()` or `db.flush()` — transaction control belongs to
  the service layer

---

### Layer 2: Service Layer

**Path:** `backend/app/services/`

**Responsibility:** Own all business logic. Enforce every domain rule.
Control the full lifecycle of a database transaction: begin, mutate,
flush, commit, or rollback. This is the only layer that may write
to the database.

**Allowed:**
- Read from and write to the database via SQLAlchemy `Session`
- Call `db.flush()` to make pending inserts visible within the current
  transaction (required for `ref_id` population before commit)
- Call `db.commit()` exactly once per service function — at the final
  step, after all mutations and ledger writes are complete
- Call `create_inventory_txn` from `backend/app/services/inventory_txn.py`
  to write ledger entries
- Raise `AppException` with a `rule_id` to signal any business rule
  violation to the API layer
- Call `log_action` from `backend/app/services/audit.py` for audit trails

**Must NOT:**
- Return data to the API layer before committing — callers must see only
  committed state
- Call `db.commit()` more than once in a single function — each function
  owns exactly one transaction boundary
- Bypass invariants because the caller "seems to need it"
- Silently swallow exceptions — any caught exception must either be
  re-raised or wrapped in `AppException`

---

### Layer 3: Ledger Layer

**Path:** `backend/app/services/inventory_txn.py`
**Entry point:** `create_inventory_txn`

**Responsibility:** Write `InventoryTxn` records. This is the single
authorized path for creating ledger entries. It owns precision
enforcement, warehouse provenance validation, and domain event emission
for inventory mutations.

**Allowed:**
- Create `InventoryTxn` rows via `db.add()` and `db.flush()`
- Quantize `raw_qty` and `base_qty` to `Decimal("0.001")` using
  `ROUND_HALF_UP` before writing
- Validate `warehouse_id` against the parent batch
- Emit `DomainEvent` records of type `InventoryTxnCommitted`

**Must NOT:**
- Be called more than once for a single inventory event (each event
  produces exactly one ledger row)
- Be called after `db.commit()` — ledger writes are pre-commit, always
- Be bypassed by writing directly to `InventoryTxn` via `db.add()` from
  any other location in the codebase

---

### Layer 4: DB Model Layer

**Path:** `backend/app/db/models/`

**Responsibility:** Define the SQLAlchemy ORM models that map to
database tables. Provide column definitions, relationships, and
constraints. Nothing more.

**Allowed:**
- Declare `Column`, `relationship`, `__tablename__`, constraints, and
  indexes
- Define mixins (e.g., `backend/app/db/models/mixins.py`) for shared
  field sets (timestamps, soft-delete flags)

**Must NOT:**
- Contain business logic, validation, or rule enforcement
- Be mutated directly by any code outside the service layer — direct
  ORM attribute assignment (`obj.field = value`) followed by
  `db.flush()` issues a silent UPDATE that bypasses every service-layer
  guard without raising an error
- Override `__setattr__` to enforce immutability — immutability is the
  service layer's responsibility

---

### Layer 5: Audit Layer

**Paths:** `backend/app/utils/audit.py`,
           `backend/app/services/audit.py`,
           `backend/app/services/audit_log.py`

**Responsibility:** Record a durable, human-readable log of every
state-changing action, including actor identity, action type, and
affected entity. Audit writes are part of the same transaction as the
mutation they record.

**Allowed:**
- Resolve user identity via `resolve_user_audit` in
  `backend/app/utils/audit.py`
- Write `AuditLog` records within the same `db` session as the
  originating mutation
- Return `(username, user_id)` tuples for use in model fields
  (`created_by`, `created_by_id`)

**Must NOT:**
- Issue its own `db.commit()` — the audit write must commit atomically
  with the mutation it records
- Fail silently — an audit write failure must propagate, not be swallowed

---

### Layer 6: Mobile Layer

**Path:** `mobile/lib/`

**Responsibility:** Provide the Flutter mobile interface for warehouse
staff. Communicate with the backend exclusively via HTTP API calls.
Present data to users and collect input.

**Allowed:**
- Call backend API endpoints via repository classes in
  `mobile/lib/repositories/`
- Manage local UI state via providers in `mobile/lib/providers/`
- Display data returned by the API
- Submit user input to the API layer and handle the structured error
  response

**Must NOT:**
- Implement business logic that duplicates backend rules — all
  validation and enforcement lives in the service layer
- Cache inventory balances locally for use in business decisions — the
  backend is the authoritative source of truth
- Interpret internal `rule_id` values as UI presentation logic — `rule_id`
  values are for debugging, not for branching mobile UI behavior

---

## Section 2 — Allowed Execution Flow

Every state-changing operation in this system follows this canonical
sequence. Any deviation from this sequence is a structural violation.

```
HTTP Request
    │
    ▼
[API Layer]  backend/app/api/<domain>.py
    │  • Validate request shape (Pydantic)
    │  • Authenticate caller
    │  • Forward db session to service
    │
    ▼
[Service Layer]  backend/app/services/<domain>.py
    │  • Enforce all business rules
    │  • Validate preconditions (ORD-007, financial lock, etc.)
    │  • Mutate ORM objects
    │  • Call create_inventory_txn if inventory is affected
    │  • Call db.flush() to make INSERT visible within transaction
    │    (required before using .id for ref_id population)
    │  • Call log_action (audit write, same session)
    │  • Call db.commit() — exactly once, at the end
    │
    ├──► [Ledger Layer]  backend/app/services/inventory_txn.py
    │       • Quantize quantities
    │       • Validate warehouse provenance
    │       • db.add(InventoryTxn(...))
    │       • db.flush()
    │       • Emit DomainEvent
    │
    ▼
[DB Model Layer]  backend/app/db/models/
    │  • Receives db.add() / db.flush() / db.commit() calls
    │  • Persists to PostgreSQL
    │
    ▼
HTTP Response  (structured JSON, committed state only)
```

**Ordering requirements:**

1. Precondition checks (guard clauses, financial lock) run BEFORE any
   `db.add()` or field mutation. If a check fails, no mutation has
   occurred.

2. `db.flush()` is called AFTER `db.add()` for any entity whose `.id`
   is needed as a `ref_id` on a child record. This makes the row visible
   within the transaction without committing.

3. `create_inventory_txn` is called AFTER the parent entity is flushed
   (so `batch_id`, `stock_entry_id`, or `dispatch_entry_id` are
   available) and BEFORE `db.commit()`.

4. `db.commit()` is called ONCE, at the end of the service function,
   after all mutations, ledger writes, and audit writes are complete.

5. The API layer calls no DB operations directly. It receives the
   committed result from the service layer and returns it.

---

## Section 3 — Forbidden Flows

These patterns are explicitly prohibited. Each prohibition exists because
the pattern has caused real bugs or creates an undetectable failure mode.

---

### Forbidden Flow 1: DB Model Mutation Without Service Layer

**Pattern:** Code outside a service function assigns directly to an ORM
model attribute and calls `db.flush()` or `db.commit()`.

```python
# FORBIDDEN
batch = db.get(Batch, batch_id)
batch.quantity = new_qty   # silent UPDATE; no ledger entry created
db.commit()
```

**Why it is dangerous:** SQLAlchemy's dirty-tracking mechanism issues
a `UPDATE` statement for any modified attribute at flush time. There is
no hook, no exception, and no audit trail. The `InventoryTxn` ledger
entry is never written. The batch balance diverges from the ledger
balance permanently, and the divergence is invisible until a reconcile
run.

---

### Forbidden Flow 2: Ledger Creation Outside `create_inventory_txn`

**Pattern:** Any code path creates an `InventoryTxn` row by calling
`db.add(InventoryTxn(...))` directly, without going through
`backend/app/services/inventory_txn.py::create_inventory_txn`.

```python
# FORBIDDEN
txn = InventoryTxn(batch_id=bid, raw_qty=qty, ...)
db.add(txn)
db.flush()
```

**Why it is dangerous:** `create_inventory_txn` owns precision
enforcement (`Decimal(str(...)).quantize(...)`), warehouse provenance
validation, and `DomainEvent` emission. Bypassing it means ledger rows
may be written with float precision, wrong warehouse IDs, or no domain
event — all silent failures.

---

### Forbidden Flow 3: Cross-Transaction Mutations

**Pattern:** A service function commits once, performs additional
mutations, and commits again — or reads a committed value then writes
to it in a separate transaction based on that read.

```python
# FORBIDDEN
db.commit()           # first commit
obj.status = "done"   # mutation in a new implicit transaction
db.commit()           # second commit
```

**Why it is dangerous:** The state between the two commits is
inconsistent and visible to concurrent readers. If the second commit
fails, the first cannot be rolled back. The system lands in a partially
applied state that no rollback can correct.

---

### Forbidden Flow 4: Partial Commits

**Pattern:** A service function commits some mutations early to "save
progress" before all related writes are complete.

```python
# FORBIDDEN
db.add(dispatch)
db.commit()                     # commits dispatch without ledger entry
create_inventory_txn(db, ...)   # ledger write — may fail after commit
db.commit()
```

**Why it is dangerous:** If `create_inventory_txn` raises after the
first commit, the dispatch record exists permanently but the ledger entry
does not. The batch balance is wrong and the ledger is missing a row.
There is no automated recovery path.

---

## Section 4 — Invariant Binding

Each invariant category binds to specific layers. A violation at a bound
layer constitutes a breach of the invariant.

| Category | Bound Layers | How violations surface |
|----------|-------------|------------------------|
| LED (Ledger & Inventory) | Service Layer + Ledger Layer | `AppException` if preconditions fail; silent ledger gap if model is mutated directly (no exception — must be caught by governance tests) |
| NUM (Numeric Precision) | Service Layer + `backend/app/core/decimal_utils.py` | `TypeError` at arithmetic if `float` mixed with `Decimal`; silent precision loss if `asdecimal=True` is missing from column definition |
| IMM (Immutability) | Service Layer boundary | `AppException(status_code=409)` from `update_stock_entry` / `update_dispatch_entry`; silent UPDATE if ORM field set directly (model-level bypass) |
| TXN (Transaction Integrity) | Service Layer — transaction scope | `OperationalError` from SQLAlchemy on duplicate commit; silent state corruption on partial commit (not caught until reconcile) |
| TST (Test Infrastructure) | `backend/tests/conftest.py` | Test isolation failures manifest as flaky tests that pass individually but fail in suite order |
| PRC (Process Integrity) | Service Layer — precondition guards | `AppException` with specific `rule_id` (e.g., `ORD-007`) if guards are active; silent bypass if guard is called after mutation |

**Invariant enforcement gap:** LED and IMM invariants have a shared
blind spot at the DB Model Layer. Direct ORM mutation (`obj.field = value`)
produces no exception. These invariants rely on the governance tests
in `backend/tests/test_governance_*.py` to catch structural violations
at CI time.

---

## Section 5 — Invariant Enforcement Contract

This is a strict rule, not guidance. It applies to every executor and
every agent session that performs mutations in this repository.

**Before executing any mutation, the executor MUST:**

1. **Identify the impacted invariants.** Read the Triggered-By Index in
   `01-INVARIANTS.md`. Every mutation type maps to one or more invariants.
   If the mutation type does not appear in the index, find the matching
   invariant category by layer (Section 4 above) and read those invariants
   in full.

2. **Validate preconditions.** For each impacted invariant, confirm that
   its preconditions are satisfied before writing any code or issuing any
   DB operation. Preconditions are stated in the **When triggered** and
   **Stop condition** fields of each invariant.

3. **Enforce correct execution order.** Mutations must follow the canonical
   flow in Section 2. Precondition checks before mutations. Ledger writes
   before commit. Single commit at the end.

4. **If any invariant may be violated — STOP.** Do not proceed. Do not
   attempt to "work around" the invariant. Write a FACT REPORT that names:
   - The invariant ID and title
   - The specific condition that would be violated
   - The file and line where the violation would occur
   Surface this in SESSION CLOSE and wait for human instruction.

**There are no exceptions to this contract.** A mutation that is
"obviously correct" still requires this check. Speed is not a reason to
skip it. A paused executor waiting for human confirmation is always
correct. An executor that guesses and violates an invariant compounds
damage.

---

## Section 6 — Agent Execution Model

Agents (AI executor sessions) that operate on this repository are
governed by additional constraints beyond the layer rules above.

**Agents operate ONLY through the Service Layer.**

An agent that needs to change inventory state calls the service function.
An agent does not write SQL. An agent does not issue `db.add()` directly
against model classes. An agent does not modify ORM object attributes
outside of a service function body.

**Agents MUST NOT mutate models directly.**

Direct ORM mutation (`obj.field = value` + `db.flush()`) is forbidden
for human engineers. It is equally forbidden for agent-generated code.
The enforcement contract in Section 5 applies to every line of code an
agent writes, not just to the agent's runtime behavior.

**Agents MUST respect transaction boundaries.**

Agent-generated service functions must follow the single-commit rule.
An agent must not generate a function that calls `db.commit()` more than
once. An agent must not generate a function that calls `db.commit()` in
a loop. If a use case seems to require multiple commits, the agent must
STOP and surface the design question to the human.

**Agents MUST stop on invariant breach.**

If an agent, while implementing a brief, discovers that completing the
brief would require violating an invariant in `01-INVARIANTS.md`, the
agent MUST stop immediately. It must not attempt to "satisfy the brief
anyway" by bending the rule. It must surface the conflict as an
out-of-scope observation in SESSION CLOSE and wait for human resolution.

---

## Footer

**This file covers:** layer definitions, canonical execution flow,
forbidden patterns, invariant binding, enforcement contract, agent model.

**What it does not cover:** individual invariant text (see
`01-INVARIANTS.md`), entity relationships and data model (see
`03-SYSTEM_MAP.md`), operating mode rules (see
`05-OPERATING_MODEL.md`).

**Next file to read:** `.agent/CORE/03-SYSTEM_MAP.md`
