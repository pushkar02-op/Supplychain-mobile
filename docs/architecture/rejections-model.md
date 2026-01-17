# Canonical Design: Rejection Refinement & Unification (Phase R2)

**Status**: DRAFT (Phase R2)
**Author**: Antigravity Agent
**Date**: 2026-01-17

---

## 1. Problem Statement: The Void Trap
Currently, **Rejections** are immutable `OUT` transactions.
- **The Deadlock**: A user cannot Void a Receipt if Rejections exist (to protect ledger integrity).
- **The Gap**: A user cannot Delete/Reverse a Rejection (no feature exists).
- **The Result**: If a user makes a mistake in receiving, and then "rejects" a few items, they are permanently blocked from correcting the original receipt.

## 2. Core Design Decisions

### A. Rejection is a "Classified Adjustment"
We will **Unify** the domain model.
- **Old Model**: Rejection was a distinct mutation path (`RejectionEntry` -> `InventoryTxn(OUT)`).
- **New Model**: Rejection is a semantic wrapper around the standard **Adjustment** logic.
    - Uses `InventoryTxn(type=ADJUST)`.
    - **Classification**: Distinguish Rejections from Cycle Counts using `reason` codes or a specific flag.
    - **Outcome**: Simplifies the ledger. All corrections flow through the same reliable pipe.

### B. Reversibility (The Fix)
Rejections MUST be reversible.
- **Action**: "Delete Rejection" (UI) -> **Compensating Adjustment** (Backend).
- **Ledger**:
    1.  T0: Receipt (+10)
    2.  T1: Rejection (-2) [User Error]
    3.  T2: **Reversal (+2)** [New Action]
- **State**: The `RejectionEntry` is marked `is_voided=True` (Soft Delete).
- **Result**: Batch quantity restores to 10. Downstream dependency is effectively neutralized.

### C. Creating the "Safe Void" Path
Once a Rejection is reversed:
1.  The Net Quantity impact of the rejection on the Batch is 0.
2.  The `StockEntry` Void check can optionally be relaxed OR (better) requires the Rejection to be soft-deleted first.
3.  **Validation Update**: `delete_stock_entry` will check *active* rejections. If all rejections are voided (soft-deleted), the Receipt Void can proceed.

---

## 3. Comparative Mapping

| Concept | Old Rejection (Legacy) | New Rejection (R2) |
| :--- | :--- | :--- |
| **Ledger Type** | `OUT` | `ADJUST` |
| **Logic** | Custom decrement | Standard `create_stock_adjustment` |
| **Reversible** | ❌ NO | ✅ YES (Compensating Txn) |
| **Void Block** | **Permanent** (Trap) | **Temporary** (until reversed) |
| **Audit** | `RejectionEntry` row | `RejectionEntry` (Voided) + `InventoryTxn` |
| **Frontend** | Generic Error | Actionable "Reverse first" dialog |

---

## 4. Impact Verification

### Backend Services
- `app/services/rejection_entry.py`:
    - Refactor `create` to use `create_stock_adjustment` internally? OR keep using `OUT` but allow Reversal?
    - **Decision**: Keep `type=OUT` or `ADJUST`? `ADJUST` is safer for "corrections". `OUT` implies consumption.
    - **Refinement**: Let's keep `ref_type='rejection_entry'` but ensure we can create a **counter-transaction**.
    - **New Method**: `reverse_rejection_entry(id)`.

- `app/services/stock_entry.py`:
    - Update `delete_stock_entry` validation to ignore `is_active=False` rejections.

### Frontend Screens
- `RejectionListScreen`: Add "Delete" (Trash) icon.
- `RejectionEntryScreen`: No change needed.
- `StockListScreen`: The "Void Trap" dialog now leads to a solvable path.

### Data Migration
- Add `is_active` column to `rejection_entries` (Default: True).
- No data loss. Old rejections remain valid.

---

## 5. Non-Goals
- **No Hard Deletes**: We never physically delete rows.
- **No History Rewrite**: Reversal is a forward-moving transaction.
