# Guide: Post-Freeze Safe Work

**Status:** ACTIVE  
**Goal:** Enable feature velocity without breaking the Core.

---

## 1. The Strategy: "Build Outside, Read Inside"
Use the Core (Ledger, Items, UOM) as a stable foundation. Build new features *on top* of it, treating the Core as a read-only API or a trusted transaction engine.

## 2. Safe Areas (Green Light) Service
*   **Web Frontend (React/Vue)**: You can rewrite the entire web admin UI. It just needs to call the verified APIs.
*   **Mobile App (Flutter)**: Add new screens, change workflows, improve caching.
*   **Analytics & Reporting**:
    *   Pull data from `stock_ledger_entries` into a Data Warehouse (Snowflake / BigQuery).
    *   Create dashboards for "Top Selling Items", "Wastage Reports".
    *   *Safe because it reads, never writes.*
*   **Notifications**: Send emails/SMS on dispatch.
*   **Identity**: Changing how users log in (OAuth/SAML) is safe, as long as `user_id` persists.

## 3. Caution Areas (Yellow Light) - Needs Review
*   **New Transaction Types**: Want to add "Returns"?
    *   *Strategy*: Model it as a special kind of Stock Entry (Receipt) or Dispatch (Shipment) using existing primitives. Do not create a new `return_entry` table unless absolutely necessary.
*   **Batch Selection Logic**: Want to change FIFO to LIFO?
    *   *Strategy*: This changes which batch gets picked, but not *how* it is decremented. Safe-ish, but requires rigorous testing.

## 4. Danger Areas (Red Light) - Do Not Touch
*   **The Checkbook**: `stock_ledger_entries`. Do not add columns. Do not change the sign logic.
*   **The Math**: `item_conversion_map`. Changing this logic breaks history.
*   **The Database Driver**: Switching from SQLAlchemy to raw SQL? No. The ORM handles locking.

---

## 5. Cheat Sheet: "I want to..."

| I want to... | Is it Safe? | How to do it? |
| :--- | :---: | :--- |
| **Change the App Logo** | ✅ | Go ahead. |
| **Add a "Manager Approval" step** | ✅ | Implement in API/UI layer. Core transaction happens *after* approval. |
| **Allow selling in "Pallets"** | ✅ | Add UOM=Pallet, Add Conversion (1 Pallet=50 Boxes). Core handles the rest. |
| **Round cost to 2 decimals** | ❌ | **STOP**. Presentation layer can round. Database stays at 6. |
| **Delete old history** | ❌ | **STOP**. Ledger must be continuous. Use "Archive" flags on UI instead. |
