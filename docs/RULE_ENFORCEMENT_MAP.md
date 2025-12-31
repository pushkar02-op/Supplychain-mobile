# Business Rule Traceability Matrix

**Generated:** 2025-12-31
**Status:** Audit & Enforcement Gap Analysis

---

**Test Coverage Legend:**
- High: E2E + API tests
- Medium: API tests only
- Low: Manual or partial
- None: No tests

---

## 1. Foundational & Master Data

| Rule ID | Rule Name | Enforcement Point | Status | Test Coverage |
|---|---|---|---|---|
| **BP-001** | Ledger Supremacy | `app/services/stock_entry.py` | ✅ Enforced | High |
| **BP-002** | Derived Data | `app/services/order.py` | ✅ Enforced | Medium |
| **MD-001** | Item Identity | `app/db/models/item.py` | ✅ Enforced | High |
| **MD-002** | UOM Immutability | `app/services/item.py` | ✅ Enforced | Medium |
| **MD-004** | Mart Identity | `app/services/mart.py` | ✅ Enforced | Medium |

## 2. Inventory & Ledger

| Rule ID | Rule Name | Enforcement Point | Status | Test Coverage |
|---|---|---|---|---|
| **INV-001** | Inventory Non-Negativity | `app/services/dispatch_entry.py` | ✅ Enforced | High |
| **INV-005** | Canonical Normalization | `app/services/*_entry.py` | ✅ Enforced | High |
| **NUM-001** | Decimal Safety | `app/services/*_entry.py` | ✅ Enforced | High |
| **LED-001** | Ledger Immutability | `app/db/models/inventory_txn.py` | ✅ Enforced | Medium |
| **LED-002** | Atomic Transactions | `app/services/*_entry.py` | ✅ Enforced | High |

## 3. ITEM IDENTITY & ALIASING (Phase 2)

| Rule ID | Rule Name | Enforcement Point | Status | Test Coverage |
|---|---|---|---|---|
| **IA-001** | Mart-Scoped Identity | `app/db/models/mart_item_alias.py` | ✅ Enforced | High |
| **IA-002** | Deterministic Resolution | `app/services/item_alias.py` | ✅ Enforced | High |
| **IA-003** | Admin-First Resolution | `app/api/endpoints/admin_identity.py` | ✅ Enforced | Medium |
| **IA-004** | Legacy Alias Deprecation | `app/api/item_alias.py` | ✅ LOCKED (410 Gone) | High |
| **DEL-001** | Master Data Protection | `app/services/item.py` | ✅ Enforced | Medium |

## 4. Invoice Processing

| Rule ID | Rule Name | Enforcement Point | Status | Test Coverage |
|---|---|---|---|---|
| **MR-001** | Evidence Only (Immutability) | `app/services/invoice.py` | ✅ Enforced | High |
| **MR-002** | Raw Fidelity | `app/db/models/invoice.py` | ✅ Enforced | Medium |

## 5. Reconciliation (Phase 3)

| Rule ID | Rule Name | Enforcement Point | Status | Test Coverage |
|---|---|---|---|---|
| **REC-001** | Comparison Only (Read-Only) | `app/services/reconciliation.py` | ✅ Enforced | Medium |
| **REC-002** | Mismatch Classification | `app/db/models/reconciliation_mismatch.py` | ✅ Enforced | Medium |
| **REC-003** | Confidence Scoring | `app/services/reconciliation.py` | ✅ Enforced | Low |
| **REC-004** | Dispute Workflow | `app/api/endpoints/admin_reconciliation.py` | ✅ Enforced | Low |

---

## 6. Order Management (Phase 4B/4C)

| Rule ID | Rule Name | Enforcement Point | Status | Test Coverage |
|---|---|---|---|---|
| **ORD-001** | Order Uniqueness | `app/services/order.py` | ✅ Enforced | Medium |
| **ORD-002** | Derived Status | `app/services/order.py` | ✅ Enforced | Medium |
| **ORD-003** | Quantity Consistency | `app/services/dispatch_entry.py` | ✅ Enforced | High |
| **ORD-004** | Order Immutability | `app/services/order.py` | ✅ Enforced | High |
| **ORD-005** | Cancellation Rules | `app/services/order.py` | ✅ Enforced | High |
| **ORD-006** | Partial Fulfillment | `app/services/order.py` | ✅ Enforced | High |
| **ORD-007** | Dispatch Integrity | `app/services/dispatch_entry.py` | ✅ Enforced | High |
| **ORD-008** | Delete Semantics | `app/services/order.py` | ✅ Enforced | High |
| **ORD-009** | Quantity Invariants | `app/services/order.py` | ✅ Enforced | High |

---

## Summary

**All business rules are now fully enforced.** 

Phase 4B/4C completed the Order Management rules (ORD-001 through ORD-009).

**No remaining gaps.**
