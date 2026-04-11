# RFC: Item Alias Deprecation and Removal Strategy

**Status:** DRAFT — NOT APPROVED
**Date:** 2025-12-31
**Author:** Systems Architect
**Impact Level:** High (Schema Removal)

---

## 1. Background & Context

The `item_alias` table was originally designed to provide global, system-wide aliases for items (e.g., mapping "Maggie" to "Maggi Noodles"). This design assumes that an alias string implies a single canonical item universally.

This assumption fails in a multi-mart environment:
*   **Ambiguity:** "Premium Rice" might mean *Basmati* in Mart A but *Sona Masoori* in Mart B.
*   **Collision:** Different suppliers use identical codes/names for disjoint products.
*   **Security:** Mart A should not dictate or pollute the namespace of Mart B.

This violates key business rules:
*   **IA-001 (Mart-Scoped Identity):** Aliases MUST be scoped per mart.
*   **IA-002 (Deterministic Resolution):** Resolution must be deterministic and mart-scoped.

Therefore, the global `item_alias` mechanism is fundamentally flawed and must be replaced by `mart_item_alias`.

## 2. Current State (As-Is)

*   **Schema:** Table `item_alias` exists.
*   **Governance:** Marked as **DEPRECATED** in `docs/business_rules_and_enforcement.md` (Rule IA-004).
*   **Runtime:** Code references have been removed or marked as deprecated. No active business logic relies on `item_alias` for resolution (validated via Phase 2 checks).
*   **Data:** Table contains historical alias mappings that lack mart context.

## 3. Target State (To-Be)

*   **Schema:** Table `item_alias` is DROPPED.
*   **Governance:** `mart_item_alias` is the SOLE authoritative source for item resolution.
*   **Runtime:** No code imports or references the `item_alias` model.
*   **Data:** All valid, unambiguous historical aliases have been migrated to `mart_item_alias`.

## 4. Deprecation Phases

### Phase 0 — Documentation & Freeze (COMPLETED)
*   [x] `item_alias` marked DEPRECATED in governance docs.
*   [x] Runtime resolution switched to `resolve_item_for_mart`.
*   [x] Legacy usage explicitly marked with warnings/comments.

### Phase 1 — Read-Only Lock (PENDING)
*   [ ] Remove write access to `item_alias` (e.g., remove `create_alias` function or make it raise error).
*   [ ] Ensure no background jobs or seeds write to this table.
*   [ ] Allow only SELECT queries for audit/migration purposes.

### Phase 2 — Data Migration (PENDING)
*   [ ] Analyze `item_alias` data for potential migration.
*   [ ] Execute migration script (details below).
*   [ ] **Constraint:** Only migrate aliases where Mart context can be confidently inferred or defaults are acceptable.

### Phase 3 — Verification Window (PENDING)
*   [ ] Operate system for N days (recommended: 14 days).
*   [ ] Verify zero runtime dependency via logs/tracing.
*   [ ] Confirm Admin workflows function fully without global aliases.

### Phase 4 — Physical Removal (PENDING)
*   [ ] Full DB backup taken and verified (schema + data).
*   [ ] Create Alembic migration to DROP `item_alias` table.
*   [ ] Remove SQLAlchemy model `app/db/models/item_alias.py`.
*   [ ] Remove API router `app/api/item_alias.py`.
*   [ ] Remove seed script `app/db/seed/alias_seed.py`.

## 5. Data Migration Strategy

Migration is **Manual-First** due to missing Mart context in the legacy table.

### Strategy Implementation:
1.  **Extract:** Export all `item_alias` rows (Code, Name, Master Item ID).
2.  **Filter:** Identify aliases that are truly universal (if any).
3.  **Map:**
    *   **Option A (Explicit Mart):** If an alias is known to belong to a specific Mart, insert into `mart_item_alias` with that `mart_id`.
    *   **Option B (Explicit Admin-Owned Mart):** Only if a formally defined, documented "Admin/Test Mart" exists and is approved for non-operational mappings. If no such Mart exists, this option MUST NOT be used.
    *   **Option C (Abandon):** If context is unknown, **DO NOT MIGRATE**. The historical data is less valuable than data integrity.
4.  **Execute:** Run a script that performs `INSERT INTO mart_item_alias ... ON CONFLICT DO NOTHING`.

**Critical Rule:** If mart context is unknown, the alias MUST NOT be auto-migrated. Better to have an unresolved invoice later (which Admin can fix) than an incorrect automatic mapping.

## 6. Risk Analysis

| Risk | Impact | Mitigation |
| :--- | :--- | :--- |
| **Data Loss** | Medium | Mappings in `item_alias` might be the only link for some historical papers. | Backup table before drop. Phase 3 Verification Window ensures impacts are felt before deletion. |
| **Incorrect Mapping** | High | Migrating a global alias to the wrong Mart could cause inventory corruption. | **Strict No-Auto-Migration Rule** for ambiguous data. Admin review required. |
| **Code Breakage** | Low | Runtime dependency already removed. | Grep audit before Phase 4. CI tests. |

## 7. Rollback Plan

If Phase 4 causes critical issues:
1.  **Restore Schema:** Re-run `CREATE TABLE item_alias`.
2.  **Restore Data:** Restore from backup/dump taken immediately before drop.
3.  **Restore Code:** Revert Git commit removing the model/API.

**Rollback Trigger:** valid invoices failing to resolve *and* cannot be fixed via Admin API within SLA.

## 8. Verification Checklist

Before Phase 4 execution:
- [ ] `grep -r "item_alias" backend/` returns only the definition and migration script.
- [ ] DB Query logs show ZERO `SELECT` queries on `item_alias` for 7+ days.
- [ ] Admin Dashboard for Identity works correctly.
- [ ] Lead Architect has signed off on the Migration Audit Report.

## 9. Governance & Approval

**Required Approvers:**
*   Systems Architect
*   Product Owner / Business Lead (for data abandonment decisions)

**Prerequisites:**
*   This RFC must be moved to **APPROVED** status.
*   `docs/rule_enforcement_map.md` must be updated to reflect "Planned Removal".

> **MANDATE:** No engineer may remove `item_alias` code or schema without this RFC being formally APPROVED and the Verification Window completed.
