# CRITICAL: What NOT To Do

**Audience:** All Staff (Admin, Engineering, Operations)  
**Enforcement:** Strict. Violation is grounds for access revocation.

---

## 1. NEVER Update Quantities via SQL
*   **The Forbidden Action**: Running `UPDATE batch SET quantity = 50 WHERE id = ...`
*   **The Consequence**: This creates "Ghost Inventory". It desynchronizes the `batch` table from the `stock_ledger_entry` table. The ledger will permanently show drift, and financial reports will be wrong.
*   **The Correct Way**: Create a `Stock Adjustment` or `Stock Entry` (if adding) or `Dispatch/Rejection` (if removing) via the API or App.

## 2. NEVER Use "Units" as a Generic UOM
*   **The Forbidden Action**: Creating an item with Unit = "Unit" or "Items".
*   **The Consequence**: It is ambiguous. Is it a box? A pallet? A single piece? This breaks downstream usage when someone eventually tries to convert "Units" to "Kg".
*   **The Correct Way**: Use `Each`, `Box`, `Pallet`, `Kg`, `Liters`. Be specific.

## 3. NEVER Bypass UI Validation
*   **The Forbidden Action**: Using `curl` or Postman to force a request that the App blocked.
*   **The Consequence**: The App blocks you for a reason (e.g., missing UOM). Bypassing it often creates data that crashes the backend later (Internal Server Error 500).
*   **The Correct Way**: Resolve the configuration blocker (see `sop_uom_diagnostics.md`).

## 4. NEVER Delete "Stuck" Batches via SQL
*   **The Forbidden Action**: `DELETE FROM batch WHERE quantity = 0`.
*   **The Consequence**: Breaks foreign key constraints in `rejection_entries` or `dispatch_entries`.
*   **The Correct Way**: Leave them. The system handles 0-quantity batches correctly. If they clutter the UI, ask Engineering to implement an "Archived" flag.

## 5. NEVER Mix Decimals and Floats in Reporting
*   **The Forbidden Action**: Calculating inventory value in Excel using 2 decimal places when the system uses high-precision math.
*   **The Consequence**: Financial discrepancy.
*   **The Correct Way**: Trust the system's generated reports which use `NUMERIC(18,6)` precision.
