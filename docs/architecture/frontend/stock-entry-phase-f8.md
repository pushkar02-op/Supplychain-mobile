# Stock Entry UX — Phase F8

> [!IMPORTANT]
> Stock receipts are **immutable**. Corrections are recorded as **adjustments**.

## Mental Model

| Concept | Meaning |
|---------|---------|
| **Receipt** | Physical fact: goods received on a specific date |
| **Adjustment** | Correction to a previous receipt (e.g., counting error) |
| **Void** | Reversal of an entire receipt (inventory is restored) |

## Why Editing is Forbidden

1. **Audit Integrity**: Receipts are facts. Changing them rewrites history.
2. **Ledger Consistency**: `InventoryTxn` is append-only; edits would corrupt the ledger.
3. **Traceability**: Adjustments create explicit audit trails with reasons.

## User-Visible Changes (Phase F8.1)

### Stock List Screen
- **FAB**: "Receive Stock" (was "Add Stock")
- **Card Tap**: No longer opens edit form
- **Popup Menu**:
  - "Correct / Adjust" → Opens correction form
  - "Void Entry" → Reverses the receipt

### Stock Entry Screen

#### Mode A: Receive Stock
- Title: "Receive Stock"
- CTA: "Save Receipt"
- Behavior: Creates new `StockEntry` and `InventoryTxn`

#### Mode B: Correct Stock
- Title: "Correct Stock"
- Banner: "You are correcting a previous stock receipt. The original receipt will not be changed."
- Shows original receipt summary (read-only)
- Inputs: Adjustment quantity (+/-), Reason (required)
- CTA: "Record Adjustment"
- Behavior: Creates `InventoryTxn` (type='ADJUST')

## Void vs Adjust

| Action | Effect | When to Use |
|--------|--------|-------------|
| **Void Entry** | Deletes receipt, creates OUT txn | Receipt was entered by mistake |
| **Correct / Adjust** | Creates ADJUST txn only | Quantity was wrong, receipt is valid |

## API Endpoints

| Action | Endpoint | Method |
|--------|----------|--------|
| Create Receipt | `/stock-entry/` | POST |
| Void Receipt | `/stock-entry/{id}` | DELETE |
| Create Adjustment | `/stock-adjustment/` | POST |
| ~~Edit Receipt~~ | ~~`/stock-entry/{id}`~~ | ~~PUT~~ (Returns 409) |

## Stock List Display

Each stock entry now shows:
- **Received**: Original receipt quantity (immutable)
- **Current**: Batch balance (reflects adjustments)
- **"Adjusted" Badge**: Shown only when Current ≠ Received

This provides operational clarity while preserving audit integrity.
