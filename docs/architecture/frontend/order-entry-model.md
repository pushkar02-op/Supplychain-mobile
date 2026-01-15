# Order Entry Model (Architecture)

**Version:** 1.0  
**Phase:** F6.DOC  
**Status:** FROZEN  

## 1. Core Philosophy

An Order in the AGRO Supply Chain is not merely a request for goods; it is a **binding contract** for a specific item, at a specific location, on a specific operational day.

Therefore, the **Order Entry Model** enforces strict immutability constraints once an order exists. We do not "edit" an order's fundamental identity; we only "adjust" its magnitude.

## 2. The Immutable Core

The following fields define the **Identity** of an order. Changing any of them effectively destroys the current contract and creates a new one. To prevent data corruption, disjointed dispatch records, and inventory ghosting, these fields are **LOCKED (Read-Only)** in `Adjust Order` mode.

| Field | Lock Status | Why? |
|-------|-------------|------|
| **Date** | 🔒 LOCKED | An order for *Tuesday* is fundamentally different from an order for *Wednesday*. Moving an order across days breaks historical reporting, dispatch scheduling, and forecasting signals. |
| **Mart** | 🔒 LOCKED | Inventory is siloed by Mart. Changing the Mart would require re-validating item existence, re-calculating stock availability, and could orphan existing dispatch entries linked to the original Mart. |
| **Item** | 🔒 LOCKED | The Item determines the Unit of Measure (UOM) and the Batch linkage. Changing the item invalidates the entire downstream dispatch chain. |

> **UX Impact:** If a user made a mistake in Date, Mart, or Item, they must **Delete** the wrong order and **Create** a new one. We do not support "morphing" orders.

## 3. The Mutable Variable

| Field | Lock Status | Why? |
|-------|-------------|------|
| **Quantity** | ✏️ EDITABLE | Demand fluctuates. Adjusting the quantity (up or down) is the primary valid use case for editing an order. It preserves the contract but changes the scale. |

## 4. Derived Constraints

### 4.1. Unit Coupling (1:1)
- **Rule:** Every Item has exactly **one** canonical Unit of Measure (UOM) for ordering.
- **Enforcement:** The Unit dropdown is strictly populated from the Item definition.
- **UX:** Users cannot "choose" a unit; they can only see the required unit. This prevents UOM mismatches (e.g., ordering "Sugar" in "Liters" when the backend expects "Kg").

### 4.2. Duplicate Prevention
- **Scope:** Composite Key `(Mart + Item + Date)`.
- **Behavior:** The system enforces uniqueness on this tuple.
- **Recovery:** If a user attempts to create a duplicate, they are blocked and directed to view/adjust the existing order. We never merge silently.

## 5. Screen Modes

### 5.1. Create Order
- **Goal:** Establish a new contract.
- **State:** All fields unlocked.
- **Date:** Defaults to Today, selectable via "Change" action.
- **Action:** "SAVE"

### 5.2. Adjust Order
- **Goal:** Correct the volume of an existing contract.
- **State:** Identity fields locked. Quantity unlocked.
- **Context:** "Scheduled for [Date] (cannot be changed)".
- **Action:** "ADJUST ORDER"

## 6. Navigation Safety
- **Exit Strategy:** Cancel/Back must preserve state if no changes saved.
- **Submit Strategy:** Success must pop with `true` result to trigger list refresh.
- **Duplicate Recovery:** Must pop context to return to list, preserving user's filter context.
