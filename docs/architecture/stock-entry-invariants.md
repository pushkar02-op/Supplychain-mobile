# Stock Receipt Invariants (Phase B8.1)

> [!IMPORTANT]
> Stock Entries are now **Immutable Receipts**.

## Core Rules

1. **Receipts are Append-Only**
   - Once a Stock Entry is created, it represents a physical fact (goods received on date X).
   - `PUT /stock-entry/{id}` IS BLOCKED (Returns 409 Conflict).
   - "Editing" a receipt breaks historical truth and ledger integrity.

2. **Corrections = Adjustments**
   - If a receipt was wrong (e.g., wrong qty entered), DO NOT edit the receipt.
   - Perform a **Stock Adjustment** instead.
   - This creates an explicit audit event (`InventoryTxn` type='ADJUST').

3. **Units are Canonicalized**
   - Stock entries must use a unit convertible to the Item's Default UOM.
   - "Liters" cannot be stored for an "Each" item.
   - This prevents mathematical corruption of the ledger.

## Developer Guide

### How to Correct Stock
Use the Adjustment API (to be exposed in Phase B8.2):
```python
create_stock_adjustment(
    batch_id=...,
    quantity_delta=Decimal("5.0"), # +5 or -5
    reason="Correction"
)
```

### Why no "Undo"?
Reversing a stock entry (deletion) is a special case of adjustment ("Voiding") which emits an OUT transaction to zero out the balance. Deletion logic in `delete_stock_entry` is already compliant (creates OUT txn).
