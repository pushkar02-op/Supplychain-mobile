# AGRO Repository — Glossary & Naming Standardization

> **This file is canonical.** Any term not defined here has no guaranteed
> meaning in this codebase. Agents, reviewers, and engineers must use
> the exact terms below. When a conflict exists between a legacy name and
> a canonical name, the canonical name wins.

---

## How to Read This File

- **Canonical term** — the one correct name for a concept. Use it everywhere:
  code, comments, briefs, FACT REPORTs, SESSION CLOSEs, PR descriptions.
- **Must not be confused with** — concepts that are related but distinct.
  Using these interchangeably with the canonical term causes real bugs.
- **Forbidden synonyms** — words that have been used in the past for this
  concept and MUST be abandoned. If you see them in new code or agent output,
  treat it as a naming violation.

---

## Section 1 — Canonical Domain Terms

### Term: Item

**Exact meaning:** A product catalog entry. Represents a type of good
(e.g., "Tomato 1kg", "Mango Pulp 400ml"). An Item is warehouse-independent
and has no quantity of its own — quantity lives in Batches.

**Where it is used:**
- DB model: `backend/app/db/models/item.py` → table `item`
- Pydantic schema: `backend/app/db/schemas/item.py`
- Frontend model: `mobile/lib/models/inventory_item.dart` (read-only
  representation)
- Referenced by Batch, Order, DispatchEntry, StockEntry, MartBillItem

**Must NOT be confused with:**
- `Batch` — a Batch is a physical lot of an Item in a warehouse.
  An Item can have many Batches. An Item alone has no stock.
- `MartBillItem` — a raw parsed line from an invoice. It may or may not
  resolve to an Item. Until `item_id` is set, it is not an Item.

**Forbidden synonyms:**
- ❌ product
- ❌ SKU
- ❌ good
- ❌ commodity

---

### Term: Batch

**Exact meaning:** A physical lot of one Item held at one Warehouse.
`batch.quantity` is the authoritative on-hand balance for that lot — it
is updated in every inventory mutation and must always match the sum of
`InventoryTxn.base_qty` rows that reference it.

**Where it is used:**
- DB model: `backend/app/db/models/batch.py` → table `batch`
- Referenced by StockEntry, DispatchEntry, InventoryTxn

**Must NOT be confused with:**
- `Item` — an Item is the catalog definition; a Batch is a physical instance
  of that Item in a specific warehouse
- `StockEntry` — a StockEntry is the record of goods being received, which
  creates or increments a Batch; the Batch is the running balance, not the
  receipt event

**Forbidden synonyms:**
- ❌ lot
- ❌ stock lot
- ❌ inventory lot
- ❌ stock record

---

### Term: InventoryTxn

**Exact meaning:** One row in the append-only inventory ledger. Created
exactly once per inventory event (receipt, dispatch, adjustment, reversal).
Never updated or deleted. The sum of all `InventoryTxn.base_qty` rows for
a Batch must always equal `batch.quantity`.

**Where it is used:**
- DB model: `backend/app/db/models/inventory_txn.py` → table `inventory_txn`
- Single authorized write path: `backend/app/services/inventory_txn.py::create_inventory_txn`
- Frontend model: `mobile/lib/models/inventory_transaction.dart`
  (Dart class `InventoryTransaction` — the `Transaction` suffix is a
  Flutter naming convention; the canonical backend term is `InventoryTxn`)

**Must NOT be confused with:**
- `StockEntry` — a StockEntry is the business receipt event; an InventoryTxn
  is the ledger record that the StockEntry creates
- `DispatchEntry` — same distinction; DispatchEntry is the business dispatch
  event; InventoryTxn is its ledger record
- A database transaction (`db.commit()`) — an InventoryTxn is a domain
  object (a row), not a SQL transaction

**Forbidden synonyms:**
- ❌ ledger entry (acceptable in prose explanation; forbidden as a code term)
- ❌ transaction log
- ❌ inventory log
- ❌ txn record (in agent output — write `InventoryTxn` in full)
- ❌ stock movement

---

### Term: Order

**Exact meaning:** A mart's purchase order for a specific Item on a
specific date. Tracks `quantity_ordered` (fixed at creation) and
`quantity_dispatched` (updated as dispatches occur). Drives the ORD-007
dispatch guard.

**Where it is used:**
- DB model: `backend/app/db/models/order.py` → table `order`
- Pydantic schema: `backend/app/db/schemas/order.py`
- Frontend model: `mobile/lib/models/order.dart`

**Must NOT be confused with:**
- `DispatchEntry` — an Order is the intent to dispatch; a DispatchEntry
  is the actual fulfillment event. One Order can produce many DispatchEntries.
- `MartBill` — a MartBill is the mart's confirmation of what was dispatched;
  an Order is what was agreed in advance

**Forbidden synonyms:**
- ❌ purchase order (acceptable in user-facing copy; forbidden as a code
  identifier — use `Order`)
- ❌ mart order
- ❌ demand
- ❌ PO

---

### Term: DispatchEntry

**Exact meaning:** The record of goods sent from one Batch to one Mart on
one date. Decrements `batch.quantity`, creates one `InventoryTxn` of type
`OUT`, and updates `order.quantity_dispatched`. Immutable after creation.
Reversals are a separate `DispatchReversal` record.

**Where it is used:**
- DB model: `backend/app/db/models/dispatch_entry.py` → table `dispatch_entry`
- Pydantic schema: `backend/app/db/schemas/dispatch_entry.py`
- Service: `backend/app/services/dispatch_entry.py`
- Frontend: `mobile/lib/screens/dispatch_entry_screen.dart`

**Must NOT be confused with:**
- `Order` — an Order is the upstream intent; a DispatchEntry is the
  fulfillment event
- `MartBill` — a MartBill is the mart's own record of what it received;
  a DispatchEntry is the warehouse's record of what it sent

**Forbidden synonyms:**
- ❌ dispatch (use `DispatchEntry` in code; `dispatch` is acceptable only
  as a verb in prose — "to dispatch goods")
- ❌ shipment
- ❌ delivery record
- ❌ dispatch record
- ❌ outbound

---

### Term: StockEntry

**Exact meaning:** The record of goods received into warehouse inventory.
Creates or increments a Batch, and creates one `InventoryTxn` of type
`IN`. Immutable after creation. Corrections require a separate adjustment
entry, not an edit.

**Where it is used:**
- DB model: `backend/app/db/models/stock_entry.py` → table `stockentry`
- Pydantic schema: `backend/app/db/schemas/stock_entry.py`
- Service: `backend/app/services/stock_entry.py`
- Frontend model: `mobile/lib/models/stock_entry_create.dart`

**Must NOT be confused with:**
- `MartBillItem` — a MartBillItem is a parsed invoice line; a StockEntry
  is the warehouse's physical receipt event. A MartBillItem may link to a
  StockEntry via `source_bill_item_id`, but they are distinct entities.
- `Batch` — a StockEntry is the receipt event; a Batch is the running balance
- `InventoryTxn` — a StockEntry is the business event; InventoryTxn is its
  ledger record

**Forbidden synonyms:**
- ❌ stock receipt
- ❌ inward entry
- ❌ goods received note (GRN)
- ❌ purchase entry
- ❌ `StockTransaction` (this is a Flutter model name in
  `mobile/lib/models/stock_transaction.dart` — it is a read-only view
  model for display purposes, not the canonical entity; do not use this
  term in backend code, briefs, or agent output)

---

### Term: MartBill

**Exact meaning:** A PDF invoice uploaded by a mart, confirming what was
dispatched to it. This is a **dispatch confirmation from the mart**, not
a purchase invoice from a supplier. Parsed to extract line items
(`MartBillItem`). Drives reconciliation against `DispatchEntry` records.

**Database table:** `invoice` (legacy naming — do not use "invoice" as
the canonical term in any new code, agent output, or documentation)

**Where it is used:**
- DB model: `backend/app/db/models/mart_bill.py` → table `invoice`
- Pydantic schema: `backend/app/db/schemas/mart_bill.py`
- Service: `backend/app/services/mart_bill.py`
- Frontend model: `mobile/lib/models/mart_bill.dart`

**Must NOT be confused with:**
- `Order` — a MartBill is the mart's post-dispatch document; an Order is
  the pre-dispatch agreement
- `DispatchEntry` — a DispatchEntry is the warehouse's record; a MartBill
  is the mart's record of the same event; they are compared in reconciliation

**Forbidden synonyms:**
- ❌ invoice (this is the DB table name — do not use it as a domain term
  in code identifiers, agent output, or briefs)
- ❌ mart invoice
- ❌ bill
- ❌ supplier invoice (a MartBill is never a supplier invoice)
- ❌ purchase invoice
- ❌ inward invoice

---

### Term: MartBillItem

**Exact meaning:** A single line item parsed from a MartBill PDF. Holds
the raw text name and quantity from the invoice. May be linked to an
`Item` via alias resolution (`item_id` is set, `resolution_status="MAPPED"`)
or remain unresolved (`item_id` is null, `resolution_status="UNRESOLVED"`).
Unresolved items block bill verification.

**Database table:** `invoice_item` (legacy naming — do not use in agent
output or new code identifiers)

**Where it is used:**
- DB model: `backend/app/db/models/mart_bill_item.py` → table `invoice_item`
- Frontend model: `mobile/lib/models/mart_bill_item.dart`
- Referenced by `StockEntry.source_bill_item_id`

**Must NOT be confused with:**
- `Item` — an Item is a resolved catalog entry; a MartBillItem is a raw
  parsed row that may or may not map to an Item
- `StockEntry` — a StockEntry is created after a MartBillItem is verified,
  not during parsing

**Forbidden synonyms:**
- ❌ invoice item (this is the DB table name — forbidden as a domain term)
- ❌ bill line
- ❌ invoice line
- ❌ line item (too generic — use `MartBillItem`)

---

## Section 2 — Forbidden Terminology

This section lists terms that appear in the codebase (often in legacy
or early-stage code) and MUST NOT be introduced in new code, agent
prompts, FACT REPORTs, or SESSION CLOSEs.

### Quantity fields

| Forbidden | Use instead | Why |
|-----------|-------------|-----|
| `qty` (standalone variable) | `quantity` | Abbreviation; ambiguous in context |
| `amt` | `amount` or `total_cost` | Ambiguous |
| `bal` | `quantity` or `batch.quantity` | Ambiguous |
| `stock` (as a field name) | `batch.quantity` | "Stock" is a colloquial term, not a model field |

**Exception:** `_qty` as a field name suffix in Pydantic schemas
(e.g., `raw_qty`, `base_qty`, `ledger_qty`) is established and
acceptable because the prefix provides full context. The rule applies
to standalone variable names and new field introductions.

### Entity synonyms

| Forbidden | Canonical term | Context |
|-----------|---------------|---------|
| `invoice` (as entity) | `MartBill` | `invoice` is the DB table name only |
| `invoice item` (as entity) | `MartBillItem` | `invoice_item` is the DB table name only |
| `dispatch` (noun, as entity) | `DispatchEntry` | `dispatch` is a verb |
| `shipment` | `DispatchEntry` | Wrong connotation |
| `delivery record` | `DispatchEntry` | Wrong layer |
| `ledger` (as entity) | `InventoryTxn` | `ledger` is the concept; `InventoryTxn` is the model |
| `transaction log` | `InventoryTxn` | Wrong connotation |
| `stock movement` | `InventoryTxn` | Too vague |
| `GRN` / `goods received note` | `StockEntry` | Domain-specific jargon |
| `inward entry` | `StockEntry` | Colloquial |
| `lot` | `Batch` | Wrong connotation |
| `SKU` | `Item` | Supplier-specific term; the system has `item_code` |
| `PO` | `Order` | Abbreviation; forbidden in code identifiers |
| `StockTransaction` (in backend) | `StockEntry` (or `InventoryTxn`) | Flutter view model name only |

### Status values

Status strings are exact literals in the database. They must be used
verbatim. No paraphrasing.

| Entity | Canonical status values | Forbidden paraphrases |
|--------|------------------------|----------------------|
| Order | `"Pending"`, `"Partially Completed"`, `"Completed"`, `"Cancelled"` | ❌ `"open"`, `"partial"`, `"done"`, `"canceled"` |
| MartBill | `"PROCESSING"`, `"NEEDS_REVIEW"`, `"VERIFIED"` | ❌ `"pending"`, `"review"`, `"approved"`, `"complete"` |
| MartBillItem | `"UNRESOLVED"`, `"MAPPED"` | ❌ `"pending"`, `"resolved"`, `"linked"` |

---

## Section 3 — Field Naming Rules

These rules apply to any new field, variable, or identifier introduced
in this codebase.

### Backend (Python)

1. **`snake_case` only.** No camelCase, no PascalCase, no SCREAMING_SNAKE
   in field names.
   - ✅ `quantity_dispatched`, `price_per_unit`, `created_by_id`
   - ❌ `quantityDispatched`, `PricePerUnit`, `CREATED_BY_ID`

2. **No standalone abbreviations.** Write the full word.
   - ✅ `quantity`, `amount`, `reference_id`, `warehouse_id`
   - ❌ `qty`, `amt`, `ref` (as a standalone name — `ref_id` and `ref_type`
     are established exceptions because the prefix provides full context)

3. **No overloaded names.** A field named `status` must be unambiguous
   in its model context. If two related models both have `status` fields
   with different possible values, document both in this glossary.

4. **Foreign key fields use the `_id` suffix.** Always.
   - ✅ `item_id`, `batch_id`, `order_id`
   - ❌ `item`, `batch_ref`, `order_fk`

5. **Boolean fields use the `is_` prefix.**
   - ✅ `is_active`, `is_verified`
   - ❌ `active`, `verified` (as boolean column names)

6. **Date fields use the `_date` suffix; datetime fields use `_at`.**
   - ✅ `order_date`, `received_date`, `created_at`, `locked_at`
   - ❌ `order_time`, `creation`, `locked`

### Frontend (Dart/Flutter)

1. **`camelCase` for local variables and class fields.** Dart convention.
   - ✅ `quantityDispatched`, `itemId`, `createdAt`

2. **`snake_case` in JSON keys.** All `fromJson` / `toJson` serialization
   must use `snake_case` keys to match backend API field names exactly.
   - ✅ `json['quantity_dispatched']`, `json['item_id']`
   - ❌ `json['quantityDispatched']`, `json['itemId']`

3. **Class names must match canonical entity names.** Flutter model class
   names must correspond to the canonical backend entity name.
   - ✅ `class MartBill`, `class DispatchEntry`, `class Order`
   - ❌ `class Invoice` (canonical: `MartBill`), `class StockTransaction`
     as an entity synonym (it is a view model — name it accordingly)

4. **No silent field renaming in repository classes.** The field name
   returned by a repository method must exactly match the field name
   from the backend API response. No aliasing at the repository layer.

---

## Section 4 — API Contract Consistency

**The backend Pydantic schema is the single source of truth for field
names in the API contract.** The frontend must not introduce alternative
names for the same field.

**Rules:**

1. **One name per field, across the full stack.** If the backend schema
   exposes `quantity_dispatched`, the frontend JSON key is
   `quantity_dispatched`, the Dart model field is `quantityDispatched`
   (camelCase conversion only), and the Flutter screen references
   `order.quantityDispatched`. No other names.

2. **Backend schema changes are breaking changes.** Any rename of a
   Pydantic schema field must be treated as a breaking API change. It
   requires a coordinated update in the frontend models and repositories
   in the same PR.

3. **No silent renaming in Flutter repositories.** A repository class
   that parses `json['quantity_dispatched']` must not expose it as
   `dispatchedAmount` or any other alias. The Dart field name must be
   the camelCase of the JSON key and nothing else.

4. **Error response contract is fixed.** All `AppException`-derived
   errors serialize to:
   ```json
   {
     "rule_id": "<AAA-NNN>",
     "detail": "<human-readable message>",
     "metadata": { ... }
   }
   ```
   The frontend must read `rule_id`, `detail`, and `metadata` by those
   exact keys. No aliases.

5. **`rule_id` format is `^[A-Z]{3}-\d{3}$`.** Enforced at runtime by
   `AppException.__init__`. Any new error class that bypasses this
   validation is a contract violation.

---

## Section 5 — Agent Language Rules

These rules apply to every AI executor session operating on this
repository. They are as mandatory as the invariants in `01-INVARIANTS.md`.

**Agents MUST use canonical terms in all output.**

This includes:
- The body of FACT REPORTs
- SESSION CLOSE output
- Code comments written as part of an executor brief
- Variable names in generated code
- PR descriptions and commit messages

**Specific rules:**

1. **Use the full canonical entity name.** Never shorten in agent output.
   - ✅ `InventoryTxn`, `DispatchEntry`, `MartBillItem`
   - ❌ `inv_txn`, `dispatch`, `bill item`

2. **Never use forbidden synonyms.** See Section 2. If a synonym appears
   in a source file being read, acknowledge the legacy name but respond
   with the canonical name.
   - Example: "The DB table is named `invoice` (legacy), but the canonical
     term is `MartBill`."

3. **Use exact status strings.** When referencing entity statuses in
   FACT REPORTs or briefs, use the exact string literals.
   - ✅ `"NEEDS_REVIEW"`, `"Partially Completed"`, `"UNRESOLVED"`
   - ❌ `"needs review"`, `"partial"`, `"unresolved"`

4. **Never introduce a new term without defining it.** If a brief requires
   an executor to name a concept that does not appear in this glossary,
   the executor must flag it in SESSION CLOSE as an out-of-scope
   observation: "NEW TERM INTRODUCED: <term>. Requires glossary update."

5. **Never use positional references in place of canonical names.** In
   FACT REPORTs, name the entity explicitly.
   - ✅ "The `InventoryTxn` row for `StockEntry.id = 42` is missing."
   - ❌ "The ledger record for that entry is missing."

6. **Field names in FACT REPORTs must match the schema.** Reference
   fields as they appear in the Pydantic schema, not as they appear in
   Dart or in prose.
   - ✅ `order.quantity_dispatched`, `batch.quantity`, `inv.status`
   - ❌ `order.dispatched`, `batchQty`, `invoice.status`

---

## Section 6 — Drift Prevention Rule

When a new term is introduced anywhere in the system — in a new model,
a new schema field, a new API endpoint, or a new agent concept — the
following steps are mandatory before the work is considered complete:

1. **Check for conflicts.** The new term must not overlap in meaning with
   any existing canonical term in Section 1.

2. **Check for forbidden synonyms.** The new term must not be any word
   listed as forbidden in Section 2.

3. **Add to this glossary.** The new term must be added to Section 1 of
   this file with: exact meaning, where it is used, what it must not be
   confused with, and its forbidden synonyms.

4. **If the new term is a status value**, add it to the status table in
   Section 2 with its canonical string value and forbidden paraphrases.

5. **Surface in SESSION CLOSE.** Any executor session that introduces a
   new canonical term must report it in SESSION CLOSE under
   `NEW_TERMS_INTRODUCED: <term>` so the human can review the addition.

**A term that is in the codebase but not in this glossary has undefined
canonical status.** Treat it as a candidate for Section 1 addition, not
as an established term.

---

## Appendix: Known Naming Inconsistencies

These are naming inconsistencies that exist in the current codebase.
They are documented here — not corrected — because correcting them would
be a breaking change. Future refactors should resolve them.

| Location | Current name | Canonical name | Notes |
|----------|-------------|---------------|-------|
| `backend/app/db/models/mart_bill.py` | `__tablename__ = "invoice"` | `MartBill` / `mart_bill` | Legacy DB table name. Do not rename without a migration. |
| `backend/app/db/models/mart_bill_item.py` | `__tablename__ = "invoice_item"` | `MartBillItem` / `mart_bill_item` | Legacy DB table name. |
| `mobile/lib/models/stock_transaction.dart` | `StockTransaction` | `StockEntry` (for the entity) | Flutter view model for display; not an entity synonym. |
| `mobile/lib/models/inventory_transaction.dart` | `InventoryTransaction` | `InventoryTxn` | Flutter naming convention; backend canonical is `InventoryTxn`. |
| `backend/app/api/item_management.py:54` | `unmapped-invoice-items` (endpoint path) | should be `unmapped-mart-bill-items` | Legacy endpoint path. |
| `backend/app/db/schemas/domain_event.py` | `qty` field on event schemas | `raw_qty` / `base_qty` | Internal event schema; acceptable for now, candidate for cleanup. |

---

## Footer

**This file covers:** canonical domain term definitions, forbidden
synonyms, field naming rules (backend and frontend), API contract
consistency rules, agent language rules, drift prevention protocol,
and known naming inconsistencies.

**What it does not cover:** entity relationship details (see
`03-SYSTEM_MAP.md`), layer rules (see `02-ARCHITECTURE.md`), invariant
text (see `01-INVARIANTS.md`).

**Next file to read:** `.agent/CORE/05-OPERATING-MODE.md`
