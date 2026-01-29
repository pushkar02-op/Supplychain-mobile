# Item Lifecycle Governance

> **Status**: LOCKED
> **Effective Date**: 2026-01-29
> **Authority**: High (Overrides UI/Code)

## 1. Core Mandate
**Items are NEVER deleted.**

The concept of "Deleting an Item" is effectively abolished in the AGRO Supply Chain System. It is replaced entirely by the **Active / Inactive** lifecycle.

## 2. Lifecycle States

| State | Status Enum | Behavior |
|---|---|---|
| **ACTIVE** | `ACTIVE` | Visible in all standard lists. Available for selection in Stock/Dispatch/Bill entries. |
| **INACTIVE** | `INACTIVE` | Hidden from standard lists. **Read-Only** in historical records. Blocked from new operations. |

### "Inactive" Definition
An Inactive item is **Archived**, not deleted.
- It RETAINS its ID (referential integrity check).
- It RETAINS all historical transaction links (Stock, Ledger, Bills).
- It RETAINS its Aliases and Conversions.
- It appears in "All Items" views ONLY when explicitly requested.

## 3. Forbidden Actions

The following actions are strictly **FORBIDDEN** by governance and enforced by the Backend:

1.  **Hard Delete**: Physical removal of a row from the `items` table.
2.  **Cascade Delete**: Deleting dependencies (aliases, stock) to facilitate item removal.
3.  **Soft Delete via Boolean**: We use `status` Enum, not `is_deleted`.

## 4. UX Implications

To reflect this governance in the UI:

### A. Item Lists
- **Default View**: Must show `ACTIVE` items only.
- **Opt-In Visibility**: Users must toggle "Show Inactive" (or similar) to see archived items.
- **Visual Distinction**: Inactive items must be visually distinct (e.g., greyed out, badged).

### B. Item Detal
- **Lifecycle Panel**: A read-only indicator must show the current status.
- **No Delete Button**: The UI must NOT contain a trash can icon or "Delete" button.

### C. Actions
- **Deactivate**: Available on ACTIVE items. Must require confirmation.
- **Reactivate**: Available on INACTIVE items. Restores visibility immediately.

## 5. Backend Enforcement

- **DELETE /item/{id}**: Must return `405 Method Not Allowed`.
- **POST /item/{id}/deactivate**: Sets status to `INACTIVE`.
- **POST /item/{id}/reactivate**: Sets status to `ACTIVE`.
