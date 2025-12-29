# Core Change Process (RFC-Lite Rulebook)

**Status:** ACTIVE  
**Enforcement:** CI/CD blocked without verified RFC link.

---

## 1. When is an RFC Required?
Any change that touches the **Core** (as defined in `core_freeze_declaration.md`) requires a written Request For Comments (RFC).

### Yes, RFC Required:
*   Adding a column to `stock_entry`.
*   Changing `get_conversion_factor` logic.
*   Modifying the order of operations in `rejection_entry`.
*   Upgrading the database version.

### No, PR Only:
*   Frontend UI tweaks (colors, layout).
*   Adding a new Report (read-only).
*   Refactoring a non-core utility function.
*   Updating documentation.

---

## 2. The RFC Template
Your RFC does not need to be long. It needs to be **safe**.

### Section A: The "Why"
*   What problem are we solving?
*   Why can't we solve it outside the Core?

### Section B: Invariant Impact Analysis
*   Does this change affect Ledger integrity?
*   Does it introduce floating-point math?
*   Does it alter the UOM graph?

### Section C: Migration Plan
*   How do we move from State A to State B without downtime?
*   **Expansion Script**: Add new column (nullable).
*   **Dual Write**: Write to both old and new.
*   **Backfill**: Fill new column.
*   **Contraction**: Stop writing to old.

### Section D: Rollback Plan
*   If deployment fails, how do we revert **without data loss**?
*   *Note: " Restore from backup" is not an acceptable rollback plan for a live ledger.*

### Section E: Verification Logic
*   What SQL query proves the change worked?
*   What script verifies the ledger is still balanced?

---

## 3. Approval Workflow
1.  **Draft**: Engineer writes RFC.
2.  **Review**: Core Owner reviews for safety and invariants.
3.  **Approval**: Core Owner signs off.
4.  **Implementation**: Code is written.
5.  **Audit**: Implementation checked against RFC.
6.  **Deploy**: Executed during maintenance window (if needed).
