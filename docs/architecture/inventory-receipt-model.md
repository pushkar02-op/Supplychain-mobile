# Inventory Receipt Model (Canonical Design)

> **Status**: LOCKED 🔒
> **Phase**: D1
> **Authority**: ABSOLUTE
> **Last Updated**: 2026-01-17

This document defines the **single source of truth** for how the system models inventory ingestion, correction, and consumption.

---

## 1. Domain Vocabulary (Authoritative)

### 1.1 Receipt (Stock Entry)
- **Concept**: A real-world record of goods arriving at a specific time, from a specific source, at a specific price.
- **Mutability**: **IMMUTABLE**. Once created, a receipt cannot be edited. It represents a historical fact.
- **Responsibility**: Financial audit, vendor tracking, and original quantity verification.
- **NOT Responsible For**: Being the live balance of inventory.

### 1.2 Adjustment
- **Concept**: A discrete, auditable event that corrects the inventory balance to match reality.
- **Mutability**: **IMMUTABLE**. Adjustments are append-only transactions.
- **Responsibility**: Correcting errors (count, spoilage, theft) relative to an anchor (Receipt or Batch).
- **NOT Responsible For**: Rewriting history. The original receipt remains visually distinct from the adjustment.

### 1.3 Batch
- **Concept**: An operational grouping of inventory for a specific Item and Date.
- **Mutability**: **MUTABLE STATE** (Derived). The "Current Quantity" of a batch changes over time.
- **Responsibility**: FIFO dispatch, expiration tracking, and being the "bucket" that holds inventory.
- **NOT Responsible For**: Financial history of *how* the inventory arrived (that's the Receipt).
- **Invariant**: A Batch may contain inventory from **multiple receipts** if they share the same Item+Date key (depending on configuration), but typically maps 1:1 in strict traceability modes.

### 1.4 Inventory Ledger (InventoryTxn)
- **Concept**: The append-only log of ALL inventory movements (IN, OUT, ADJUST).
- **Mutability**: **IMMUTABLE**.
- **Responsibility**: The ultimate mathematical proof of current stock (`SUM(IN) - SUM(OUT) + SUM(ADJECT)`).

### 1.5 Dispatch
- **Concept**: An execution event where inventory physically leaves the premise (Sold, Transferred).
- **Mutability**: **IMMUTABLE**.
- **Responsibility**: Decrementing the **Batch** balance.
- **NOT Responsible For**: Knowing which specific *Receipt* the physical item came from (unless serial-tracked). Dispatch consumes from the Batch.

---

## 2. Core Invariants (MUST HOLD TRUE)

| Rule | Description | Consequence of Violation |
|------|-------------|--------------------------|
| **Receipt Immutability** | Users CANNOT edit a `StockEntry`. Must use void/re-entry or adjustment. | Audit trail becomes trash; fraud becomes trivial. |
| **Adjustment Scope** | An adjustment MUST be linked to a specific Batch (and conceptually the Receipt context). | tracebility is lost; "Why did this change?" becomes unanswerable. |
| **Dispatch consumes Batch** | Dispatches decrement `Batch.quantity`. | System cannot handle multi-receipt batches; FIFO breaks. |
| **Ledger Integrity** | `Batch.quantity` must eventually consistent with `SUM(InventoryTxn)`. | "Ghost inventory" appears; financial reporting fails. |
| **No Negative Stock** | Adjustments/Dispatches cannot turn `Batch.quantity` negative (unless explicit config override). | Physical reality broken; upstream logic crashes. |

---

## 3. Receipt vs Batch — Responsibility Split

| Concern | Receipt (Stock Entry) | Batch |
| :--- | :--- | :--- |
| **Primary Role** | **Financial/Audit Record** | **Operational Bucket** |
| **User Question** | "What did we buy?" | "What can I sell?" |
| **Mutability** | Immutable | Mutable (Qty changes) |
| **Corrections** | Via **Adjustment Txn** | Result of Txns |
| **Dispatch** | Indirect Source | **Direct Source** |
| **Pricing** | Fixed at entry | Weighted Avg (if merged) |
| **Grouping** | Individual Record | Item + Date |

---

## 4. Adjustment Semantics

### 4.1 Receipt-Scoped Context
Adjustments are technically applied to the **Batch** (to update the sellable quantity), but the **User Intent** is usually to correct a specific **Receipt**.
- **Model**: `InventoryTxn(type=ADJUST, batch_id=X, ref=manual)`.
- **Reasoning**: If a user selects "Receipt #123" and clicks "Adjust -5", the system creates an adjustment on the *Batch* associated with #123, but the *Audit Trail* (History) groups this under Receipt #123's context.

### 4.2 Why Batch-Scoped Adjustments are Dangerous
If adjustments are just "free floating" on a batch without receipt context (where 1:1 mapping exists):
- **Traceability Loss**: "Did we adjust the morning delivery or the afternoon delivery?"
- **Vendor Disputes**: "You sent us 5 bad units" requires proving *which* delivery had the bad units.

### 4.3 Ledger Truth
`Batch.quantity = StockEntry.quantity + SUM(Adjustments) - SUM(Dispatches)`
The Ledger (`InventoryTxn`) is the mechanism that enforces this.

---

## 5. Dispatch Flow

### 5.1 Why Dispatch uses Batches
- Warehouse staff pick from a "Batch" (e.g., "Table A, Expiry Dec 2025"). They do not pick from "Invoice #994".
- Dispatches target the **Batch**.
- The system automatically decrements the oldest available Batch (FIFO) or the specific Batch selected.

### 5.2 Receipt Independence
- A Dispatch does **NOT** need to know about Receipts.
- Ideally, 1 Batch = 1 Receipt (Strict Mode).
- Even if 1 Batch = 2 Receipts (Merged Mode), Dispatch simply reduces the Batch total.

---

## 6. Stock List Semantics (Frontend Truth)

The Stock List (`StockListScreen`) must display:

| Label | Definition | Source |
| :--- | :--- | :--- |
| **Received** | Original verified quantity at the dock. | `StockEntry.quantity` |
| **Current** | What is physically available right now. | `Batch.quantity` (enriched) |
| **Adjusted** | Badge indicating divergence. | Visibile if `|Received - Current| > 0` |
| **Price** | Cost basis of the entry. | `StockEntry.price_per_unit` |

**What is NOT shown inline**:
- Dispatch history (clutter).
- Detailed adjustment logs (clutter).
- Voided entries (usually hidden or grayed out).

---

## 7. Explicit Non-Goals

1.  **Editing Receipts**: We will NEVER allow `PUT /stock-entry/{id}` to change quantity.
2.  **Hiding Mistakes**: We will NEVER delete an adjustment trace. It is permanent.
3.  **Complex Allocations**: We are NOT implementing "Reservation" or "Hard Allocation" logic in this model yet.
4.  **Backdating**: Adjustments happen *now*. We do not support retroactive inventory changes that rewrite past balance sheets (Ledger is time-forward).

---

## 8. Example Scenarios

### Scenario A: Same Item, Same Day, Different Suppliers
- **Action**: User receives 10kg Rice from Vendor A, then 10kg Rice from Vendor B.
- **Result**:
    - 2x `StockEntry` records created.
    - 2x `Batch` records created (assuming unique IDs/different prices or strict separation).
- **List View**: Shows two distinct cards.

### Scenario B: Wrong Quantity Entered
- **Action**: User enters "100kg" but meant "10kg".
- **Fix**:
    - User clicks "Correct Stock".
    - Enters "-90kg", Reason: "Data Entry Error".
- **Result**:
    - `StockEntry` remains "100kg" (Audit).
    - `InventoryTxn` created: "-90kg".
    - `Batch` updates to "10kg".
    - UI shows: "Received: 100kg | Current: 10kg | [Adjusted]".

### Scenario C: Voiding a Receipt
- **Action**: User realizes the entire entry was a duplicate.
- **Fix**: User clicks "Void Receipt".
- **Result**:
    - `StockEntry` is soft-deleted or marked void.
    - `InventoryTxn(type=OUT)` created effectively reversing the input.
    - `Batch` quantity becomes 0.
    - Entry disappears from default list (or moves to specific "Voided" filter).

### Scenario D: Blocking a Void (Inventory Integrity)
- **Condition**: User tries to void a receipt, but items from that batch have already been:
    1.  **Dispatched** to a Mart.
    2.  **Rejected** (Damaged/Expired).
    3.  **Adjusted** (Cycle Count).
- **Result**: System **BLOCKS** the void action.
- **Reason**: You cannot retroactively "un-receive" goods that have already been used. Voiding would orphan the downstream transactions (Dispatches would point to ghost inventory).
- **Remedy**: The user must first reverse the downstream actions (e.g., Return the dispatch, delete the rejection) before the system allows the receipt to be voided.
