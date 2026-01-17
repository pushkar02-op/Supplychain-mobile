# Dispatch UX — Phase F7 Design Specification

## 1. Dispatch Mental Model

**Dispatch is Execution, Order is Intent.**

- **Orders** allow a user to say "We need 100 kg of Tomato at Mart A today."
- **Dispatches** record "We actually sent 40 kg from Batch X and 60 kg from Batch Y just now."

A Dispatch is an immutable event log. Once signed off (saved), it enters the ledger. It cannot be edited because it affects physical inventory that may have already left the building. If a mistake is made, the dispatch must be **Reversed** (negating the effect) and a new one created.

## 2. Dispatch List Screen — Purpose & Scope

**Purpose:** To confirm operations for *today* and reverse mistakes.

This screen is NOT an analytics dashboard or a historical archive search. It is an operational log for the current shift.

**Key Questions Answered (<30s):**
1. "What has gone out today?"
2. "Did I forget to dispatch the Tomato order?" (Implicitly, by absence or cross-check)
3. "Did I make a mistake?" (Visible partial entries)

**Intentionally NOT Shown:**
- Backlog of previous days.
- Pending orders (Those live on the *Orders* screen).
- Inventory levels.

## 3. Primary Actions & Navigation

**Initiating Dispatch:**
Dispatches MUST originate from an Order context.
- **Action:** "Dispatch Order" (Replaces "New")
- **Behavior:** Redirects user to the **Orders List**.
- **Reasoning:** Since a dispatch fulfills a specific order, the user must first select *which* order they are fulfilling. This enforces the "Intent First" mental model.

## 4. Dispatch Entry Screen — Information Hierarchy

The screen follows a strict top-down operational flow to minimize error:

1.  **Context (Locked):**
    - "Dispatching **Tomato** to **Mart A** for **Today**".
    - This anchors the user: "Am I working on the right task?"

2.  **Remaining Quantity (The Target):**
    - "Remaining: 100 kg".
    - This is the goal. It guides the decision of how much to pick.

3.  **Batch Selection (The Source):**
    - "Which batches are we taking from?"
    - Users select specific batches to ensure FIFO or specific stock rotation.

4.  **Dispatching Now (The Result):**
    - "Total: 100 kg".
    - Dynamically sums selected batches.
    - Warnings appear here if over-dispatching.

5.  **Confirmation (The Sign-off):**
    - "Save Dispatch".
    - Commits the immutable event.

## 5. Batch Selection Semantics

- **Default:** FIFO (First-In, First-Out). The system auto-selects oldest batches first to fill the requested quantity.
- **Manual Override:** Users can uncheck auto-selected batches and choose newer ones (e.g., if the old batch is physically inaccessible or damaged).
- **Clamping:** Evaluating inputs ensures a user cannot type a quantity > batch availability.
- **Transparency:** All available batches are visible. We do not hide "irrelevant" batches, so users trust they are seeing the full reality of inventory.

## 6. Over-Dispatch Semantics

**Semantics:** Over-dispatch is a *deviation from plan*, not a system error. It is physically possible to send more than ordered.

- **Warning:** Use permissive language.
  - *Bad:* "Error: You cannot dispatch more than ordered."
  - *Good:* "You are dispatching 120kg, but the order remaining is 100kg. Proceed?"
- **Intent:** To prevent fat-finger errors (typing 100 instead of 10) while allowing operational flexibility.

## 7. Reversal UX Semantics

**Who:** Any authorized user (removing admin-only gating).

**Pre-Confirmation Information:**
The user must see exactly what will happen *before* clicking "Confirm":
- **Quantity:** How much stock returns to inventory.
- **Status Context:** "Order status will revert from 'Fully Dispatched' to 'Partially Dispatched'."

**Consequences:**
- The Dispatch record remains visible but marked "Reversed".
- Inventory credits back to original batches.
- Order "Dispatched Quantity" decreases.

## 8. Pagination & Data Volume Transparency

**Decision:** No UI Pagination for Phase F7.

**Reasoning:**
- Operational shifts rarely produce >100 distinct dispatch events per Mart-Day filter.
- Adding complex pagination UI distorts the "daily log" mental model.

**Mitigation:**
- If the API returns the limit (e.g., 100 items), display a footer: *"Showing first 100 dispatches. Use filters to see more."*
- This ensures users know if they are looking at a truncated list without complicating the common case.

## 9. Explicit Non-Goals

- **No Editing:** Users cannot "fix" a quantity. They must Reverse and Redo.
- **No Bulk Dispatch:** One order at a time.
- **No Analytics:** "Total Dispatched Value" is for the Overview Dashboard, not here.
- **No Historical Backfills:** Dispatches are for current operations.
