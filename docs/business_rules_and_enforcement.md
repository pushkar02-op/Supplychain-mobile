# AGRO SUPPLY CHAIN SYSTEM  
## Business Rules, Enforcement Checklist & Backend Mapping

**Version:** 1.0 (LOCKED)  
**Last Updated:** 2025-12-30  
**Status:** Authoritative Source of Truth  

---

## 0. PURPOSE

This document defines:

- Formal business rules (LOCKED)
- Engineering & QA enforcement checklists
- Explicit mapping of rules to backend services and functions

Any change that violates this document **must update this file first**.

---

## 1. FOUNDATIONAL PRINCIPLES

### BP-001 — Ledger Supremacy
Inventory-affecting operations MUST be traceable via immutable ledger records.

**Canonical Table:** `inventory_txn`

#### Checklist
- [ ] Every stock mutation creates exactly one `inventory_txn`
- [ ] No update/delete exists on `inventory_txn`
- [ ] Ledger is never recomputed from Batch

#### Backend Mapping
- `app/services/stock_entry.py`
  - `create_stock_entry`
  - `update_stock_entry`
- `app/services/dispatch_entry.py`
  - `create_dispatch_entry`
- `app/services/rejection_entry.py`
  - `create_rejection_entry`
- `app/services/inventory_txn.py`
  - `create_inventory_txn`

---

### BP-002 — Canonical vs Derived Data

| Data | Type |
|---|---|
inventory_txn | Canonical |
item | Canonical |
uom | Canonical |
mart | Canonical |
batch.quantity | Derived cache |
order.status | Derived |
order.quantity_dispatched | Derived |

#### Checklist
- [ ] Derived fields are never user-editable
- [ ] Derived fields are recalculated only from canonical data
- [ ] No API accepts direct mutation of derived fields

#### Backend Mapping
- `app/services/order.py`
  - `recalculate_order_status`
- `app/services/batch.py`
  - batch quantity updates only via stock/dispatch/rejection

---

### BP-003 — Backend Authority

All business rules are enforced server-side.

#### Checklist
- [ ] No frontend-only validation is relied upon
- [ ] Admin UI never bypasses backend checks
- [ ] No raw SQL writes from UI

#### Backend Mapping
- All `app/api/*.py`
- All `app/services/*.py`

---

## 2. MASTER DATA RULES

### MD-001 — Item Identity

Each Item represents a real, physical product.

#### Checklist
- [ ] Item has exactly one `default_uom_id`
- [ ] Item cannot exist without a UOM

#### Backend Mapping
- `app/db/models/item.py`
- `app/services/item.py`

---

### MD-002 — Default UOM Immutability

Once an Item participates in any inventory transaction, its default UOM MUST NOT change.

#### Checklist
- [ ] Check for existing `inventory_txn` before allowing UOM change
- [ ] Admin UI blocks change with explanation

#### Backend Mapping
- `app/services/item.py`
  - `update_item`
- `app/api/item.py`

**Backend Enforcement Note:** This rule is enforced at update time by rejecting default UOM changes once `inventory_txn` records exist for the item.

---

### MD-003 — UOM Canonicality

UOM codes are canonical identifiers.

#### Checklist
- [ ] UOM codes are unique
- [ ] Renaming a used UOM is blocked
- [ ] Deleting a used UOM is blocked

#### Backend Mapping
- `app/db/models/uom.py`
- `app/services/uom.py`

---

### MD-004 — Mart Identity

Mart ID is canonical; name is human-facing.

#### Checklist
- [ ] All transactional tables reference `mart_id`
- [ ] APIs may accept `mart_name` but resolve internally

#### Backend Mapping
- `app/services/order.py`
- `app/services/dispatch_entry.py`

---

## 3. ITEM IDENTITY & ALIASING (IA-XXX)

### IA-001 — Mart-Scoped Identity (MANDATORY)

Item identity resolution MUST be scoped by Mart. Global aliasing is FORBIDDEN.

**Required Table:** `mart_item_alias`

#### Checklist
- [ ] Table `mart_item_alias` exists with `mart_id`, `item_id`, `alias_code`, `alias_name`.
- [ ] Unique constraints on `(mart_id, alias_code)` and `(mart_id, alias_name)`.
- [ ] No global alias lookup exists in code.

#### Backend Mapping
- `app/services/item_alias.py`

---

### IA-002 — Deterministic Resolution

Resolution order is strict and deterministic.

#### Order:
1. **(mart_id, alias_code)**: Exact Match.
2. **(mart_id, alias_name)**: Case-Insensitive Exact Match.
3. **Unresolved**: Return None/Error.

#### Checklist
- [ ] No fuzzy matching.
- [ ] No partial matching.
- [ ] No fallback to global item table.

#### Backend Mapping
- `app/services/item_alias.py`: `resolve_item_for_mart`

---

### IA-003 — Admin-First Resolution

Unresolved items remain unresolved until explicitly mapped by an Admin.

#### Checklist
- [ ] System stores unresolved invoice line items without erroring.
- [ ] Admin API exists to map alias to item.
- [ ] No automatic silent creation of items.

---

### IA-004 — Legacy Alias Deprecation

**Status:** DEPRECATED

The legacy `item_alias` table is **DEPRECATED**. It exists solely for read-only historical access and migration purposes.

#### Checklist
- [ ] No runtime logic queries `item_alias` for resolution.
- [ ] `mart_item_alias` is the ONLY authoritative source for resolution.
- [ ] Global alias lookup is FORBIDDEN.

#### Backend Mapping
- **Reference**: `app/db/models/item_alias.py` (Legacy Model)
- **Forbidden Usage**: All Resolution Services


---

## 4. INVENTORY & STOCK RULES

### INV-001 — Inventory Non-Negativity

Inventory must never go negative.

#### Checklist
- [ ] Availability checked in canonical UOM
- [ ] Dispatch/Rejection fails before mutation

#### Backend Mapping
- `app/services/dispatch_entry.py`
- `app/services/rejection_entry.py`

---

### INV-002 — Inventory Changes by Events Only

Direct quantity edits are forbidden.

#### Checklist
- [ ] No API updates `batch.quantity` directly
- [ ] All changes go through services

#### Backend Mapping
- `app/services/stock_entry.py`
- `app/services/dispatch_entry.py`
- `app/services/rejection_entry.py`

---

### INV-003 — Batch Grouping

Stock entries with same item + received_date group into one Batch.

#### Backend Mapping
- `app/services/stock_entry.py`
  - `get_or_create_batch`

---

### INV-004 — Batch Deletion Protection

Batch deletion blocked if downstream usage exists.

#### Checklist
- [ ] Dispatch existence check
- [ ] Rejection existence check
- [ ] UI explanation required

#### Backend Mapping
- `app/services/stock_entry.py`
  - `delete_stock_entry`

---

### INV-005 — Canonical Normalization

All mutations use canonical UOM.

#### Checklist
- [ ] Unit conversion happens BEFORE quantity mutation
- [ ] No raw-unit subtraction

#### Backend Mapping
- `app/services/item_conversion_map.py`
- `app/services/dispatch_entry.py`
- `app/services/rejection_entry.py`

---

## 5. LEDGER & AUDIT RULES

### LED-001 — InventoryTxn Immutability

Ledger is append-only.

#### Checklist
- [ ] No update/delete endpoints
- [ ] DB constraints prevent mutation

#### Backend Mapping
- `app/db/models/inventory_txn.py`

---

### LED-002 — Dual-Write Consistency

NOTE: Dual-write is an accepted transitional design. Long-term target may replace batch.quantity with a computed or trigger-enforced model.


Batch + Ledger updated atomically.

#### Checklist
- [ ] Wrapped in DB transaction
- [ ] No partial commit possible

#### Backend Mapping
- All inventory-mutating services

---

### LED-003 — Idempotency

All ledger mutations support Idempotency-Key.

#### Checklist
- [ ] Header required or injected
- [ ] Duplicate requests return same result

#### Backend Mapping
- `app/utils/idempotency.py`
- `app/services/*_entry.py`

---

## 6. UOM & CONVERSION RULES

### UOM-001 — Canonical Enforcement

Ledger quantities always canonical.

#### Backend Mapping
- `app/services/item_conversion_map.py`

---

### UOM-002 — Conversion Integrity

Conversions reference valid UOMs only.

#### Checklist
- [ ] FK-based UOM references
- [ ] Reverse conversion computed

#### Backend Mapping
- `app/services/item_conversion_map.py`

---

### UOM-003 — Unit-Safe Mutations

No raw unit arithmetic allowed.

#### Backend Mapping
- `app/services/dispatch_entry.py`
- `app/services/rejection_entry.py`

---

## 7. MART RECEIPTS (INVOICES)

### MR-001 — Evidence Only

Mart Receipts (Invoices) are evidence of external claims. They NEVER mutate inventory directly.

#### Checklist
- [ ] Invoice creation is read-only for Inventory.
- [ ] Invoice deletion is read-only for Inventory.

#### Backend Mapping
- `app/services/invoice.py`

---

### MR-002 — Raw Fidelity

Invoices store data exactly as provided by the external source (files/OCR).

#### Checklist
- [ ] Raw UOM strings stored without normalization.
- [ ] Raw item names stored for resolution.
- [ ] Unresolved rows are preserved.

#### Backend Mapping
- `app/db/models/invoice.py`
- `app/db/models/invoice_item.py`

---

## 8. RECONCILIATION RULES

### REC-001 — Comparison Only

Reconciliation never mutates ledger.

#### Backend Mapping
- `app/services/reconciliation.py`

---

### REC-002 — Mismatch Classification

Types:
- Quantity
- UOM
- Price
- Identity

---

### REC-003 — Confidence Scoring

Stored, deterministic, explainable.

#### Backend Mapping
- `app/services/reconciliation.py`
  - Confidence scoring implemented inline in `_create_mismatch_record`

---

### REC-004 — Dispute Workflow

Manual admin resolution required.

#### Backend Mapping
- `app/services/reconciliation.py`
  - `resolve_mismatch`
- `app/api/endpoints/admin_reconciliation.py`

---

## 9. ORDER & DEMAND RULES

### ORD-001 — Uniqueness

Unique by (item_id, mart_id, order_date).

#### Backend Mapping
- `app/services/order.py`

---

### ORD-002 — Derived Status

Status is not user-editable.

#### Backend Mapping
- `app/services/order.py`

---

### ORD-003 — Quantity Consistency

quantity_dispatched = sum(dispatch_entries).

#### Backend Mapping
- `app/services/dispatch_entry.py`
- `app/services/order.py`

---

### ORD-004 — Order Immutability After Dispatch (LOCKED)

Once an Order has any dispatch (quantity_dispatched > 0), the following fields MUST NOT change:
- `quantity_ordered`
- `item_id`
- `mart_id`
- `order_date`
- `unit`

**Rationale:** Changing order parameters after fulfillment has begun would corrupt dispatch-order relationships and audit trails.

#### Checklist
- [ ] Block update of core fields if quantity_dispatched > 0
- [ ] Return 409 Conflict with rule metadata
- [ ] Allow only administrative fields (remarks, if any)

#### Backend Mapping
- `app/services/order.py`
  - `update_order`

---

### ORD-005 — Order Cancellation Rules (LOCKED)

Orders MAY be cancelled ONLY if:
- `quantity_dispatched == 0` (no dispatch has occurred)
- Order status is "Pending"

Cancellation sets `status = "Cancelled"` (soft delete).

**Rationale:** Hard deletion of orders with history would orphan audit records.

#### Checklist
- [ ] Block cancellation if any dispatch exists
- [ ] Set status to "Cancelled" instead of physical delete
- [ ] Cancelled orders are not eligible for dispatch

#### Backend Mapping
- `app/services/order.py`
  - `cancel_order` (new function)

---

### ORD-006 — Partial Fulfillment Rules (LOCKED)

Order status MUST be calculated deterministically:
- `Pending`: quantity_dispatched == 0
- `Partially Completed`: 0 < quantity_dispatched < quantity_ordered
- `Completed`: quantity_dispatched >= quantity_ordered

Status is NEVER user-editable (per ORD-002).

#### Checklist
- [ ] Status recalculated on every dispatch
- [ ] Status recalculated on dispatch deletion (if allowed)
- [ ] No API allows direct status mutation

#### Backend Mapping
- `app/services/dispatch_entry.py`
- `app/services/order.py`
  - `recalculate_order_status` (internal)

---

### ORD-007 — Dispatch Must Respect Order Remaining Quantity (LOCKED)

**Invariant:**
```
SUM(dispatch.quantity for order) ≤ order.quantity_ordered
```

**Rationale:** Over-dispatch indicates data corruption or order integrity breach. No dispatch may exceed the remaining unfulfilled quantity of its associated order.

**Failure Behavior:**
- Dispatch attempt exceeds remaining order quantity → FAIL
- Failure occurs BEFORE inventory mutation
- HTTP Status: **409 Conflict**
- Error response MUST include:
  - `rule_id`: "ORD-007"
  - `requested_quantity`: Amount attempted
  - `remaining_quantity`: Amount available to dispatch
  - `explanation`: Human-readable message

**Order State Guards:**
- Cancelled orders CANNOT receive dispatch
- Completed orders CANNOT receive dispatch

#### Checklist
- [ ] Pre-dispatch check: (existing_dispatched + new_quantity) <= quantity_ordered
- [ ] Block dispatch with 409 if would exceed
- [ ] Block dispatch if order status is "Cancelled" or "Completed"
- [ ] Include remaining vs requested in error response
- [ ] Inventory is NOT mutated on failure

#### Backend Mapping
- `app/services/dispatch_entry.py`
  - `create_dispatch_entry`
  - Enforcement point: Before inventory availability check


---

### ORD-008 — Delete vs Void vs Cancel Semantics (LOCKED)

| Action | When Allowed | Side Effect |
|--------|--------------|-------------|
| **Delete (Physical)** | NEVER for orders with dispatches | N/A |
| **Cancel (Soft)** | Only if quantity_dispatched == 0 | status = "Cancelled" |
| **Void** | Reserved for future invoice integration | N/A |

Physical deletion of orders is FORBIDDEN once any dispatch exists.

#### Checklist
- [ ] Block physical delete if quantity_dispatched > 0
- [ ] Return 409 Conflict with DEL-002 and ORD-008 references

#### Backend Mapping
- `app/services/order.py`
  - `delete_order`

---

### ORD-009 — Order Quantity Invariants (LOCKED)

Order quantities MUST satisfy:
- `quantity_ordered > 0`
- `quantity_dispatched >= 0`
- `quantity_dispatched <= quantity_ordered` (enforced by ORD-007)

All quantities MUST use Decimal precision (NUM-001 alignment).

#### Checklist
- [ ] Validate quantity_ordered > 0 on create
- [ ] Reject zero/negative quantities
- [ ] Use Numeric(18,6) in schema

#### Backend Mapping
- `app/services/order.py`
  - `create_order`
- `app/db/models/order.py`

---


---

### ORD-010 — Duplicate Order Handling

One order per (item, mart, date). Attempts to create duplicates must fail with a specific business error.

#### Checklist
- [ ] Detect duplicate before write
- [ ] Return 400 Bad Request (NOT 500)
- [ ] Error message must identify the conflict clearly
- [ ] Frontend must handle this with a direct "View Existing" action

#### Backend Mapping
- `app/services/order.py`
  - `create_order`

---

> **Section 9 Status: LOCKED (2025-12-31)**

---

## 10. NUMERIC & PRECISION RULES

### NUM-001 — Decimal Safety

Floats forbidden for inventory math.

#### Checklist
- [ ] Numeric/Decimal used in DB
- [ ] Decimal used in Python services

---

## 11. DELETION & MUTABILITY

### DEL-001 — Master Data Protection

Referenced master data cannot be deleted.

#### Backend Mapping
- `app/services/item.py`
- `app/services/uom.py`
- `app/services/mart.py`

---

### DEL-002 — Transaction Safety

Transactional deletion requires compensating logic.

---


## 13. AUTHENTICATION & SESSION RULES

### AUTH-001 — Token Lifecycle

Access is granted via short-lived JWTs, maintained by long-lived revocable refresh tokens.

#### Checklist
- [ ] Access Token TTL ≤ 30 minutes (Target: 15m)
- [ ] Refresh Token stored server-side
- [ ] Refresh Token rotated on every use (One-Time Use)

#### Backend Mapping
- `app/services/auth.py`
  - `login_user`
  - `refresh_token`
- `app/core/security.py`

---

### AUTH-002 — Session Continuity

Users must NEVER be logged out silently due to simple access token expiry.

#### Checklist
- [ ] 401 Unauthorized triggers automatic refresh attempt
- [ ] Failed refresh triggers explicit logout
- [ ] Logout clears all local tokens

#### Backend Mapping
- `app/api/auth.py` (`/refresh` endpoint)

---


## 14. DISPATCH & FULFILLMENT RULES

### D-001 — Dispatch Immutability

Dispatch entries are append-only. Hard deletion of dispatch records is FORBIDDEN.

#### Checklist
- [ ] No DELETE endpoint for dispatch entries
- [ ] Database constraints prevent physical deletion
- [ ] `dispatch_entry` table is insert-only (except for status updates)

#### Backend Mapping
- `app/services/dispatch_entry.py`

---

### D-002 — Dispatch Reversal (Correction Model)

Any correction to a dispatch MUST be represented as a reversal entry or a cancelled dispatch record. The original data must remain intact for audit.

#### Checklist
- [ ] Corrections create new inverse transactions
- [ ] "Cancelled" status is used for soft-deletes (if applicable)
- [ ] Audit log captures the reversal event

#### Backend Mapping
- `app/services/dispatch_entry.py`
  - `create_reversal_entry` (Future)

---

### D-003 — Order Status Recalculation

Order status is derived from **net dispatched quantity**. Reversal or cancellation MUST trigger recalculation.

#### Valid Transitions:
- `Completed` → `Partially Fulfilled`
- `Completed` → `Open`

#### Checklist
- [ ] Recalculate status after every Dispatch OR Reversal
- [ ] Ensure `quantity_dispatched` reflects net value

#### Backend Mapping
- `app/services/order.py`
  - `recalculate_order_status`

---

### D-004 — Inventory Consistency

Reversing a dispatch restores inventory through ledger-safe operations. Inventory truth is preserved via append-only semantics.

#### Checklist
- [ ] Reversal increases stock quantity
- [ ] Reversal creates a new `inventory_txn`
- [ ] No direct edit of previous `inventory_txn`

#### Backend Mapping
- `app/services/inventory_txn.py`

---

## 15. CHANGE CONTROL



Any change violating this document MUST:
1. Update this file
2. Be reviewed as business decision
3. Include migration/mitigation plan

---


---

## 16. MART BILL & STORAGE RULES

### MB-001 — Standardized Lifecycle
Mart Bills follow a strict 3-state lifecycle to ensure data integrity.

#### Lifecycle
1. **NEEDS_REVIEW** (Default): Editable, Delete allowed.
2. **VERIFIED**: Locked. No Edit, No Delete.
3. **PROCESSING**: Transient state (parsing).

#### Checklist
- [ ] Uploads start as NEEDS_REVIEW
- [ ] Verification locks the record (timestamp + user)
- [ ] Edits rejected for VERIFIED bills

#### Backend Mapping
- `app/services/mart_bill.py`
- `app/api/mart_bill.py`

---

### MB-002 — Storage Abstraction
Filesystem operations must be decoupled from business logic via `StorageService`.

#### Checklist
- [ ] No direct `open()` or `os.remove()` in services
- [ ] Keys are relative paths
- [ ] Storage root is configurable via `STORAGE_ROOT`

#### Backend Mapping
- `app/core/storage/base.py`
- `app/core/storage/local.py`

---

### MB-003 — File Recovery & Self-Healing
Missing files must not crash the application. Users must be able to restore state.

#### Checklist
- [ ] Missing file returns specific error (e.g. 404 with code)
- [ ] Re-upload allowed for missing files even if Locked (resets lock)
- [ ] Re-upload resets status to NEEDS_REVIEW

#### Backend Mapping
- `app/services/mart_bill.py`: `replace_mart_bill_file`

---

**END OF DOCUMENT**

