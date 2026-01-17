# Order Entry Model (Create vs Adjust)

## 1. Purpose of Order Entry

The Order Entry system captures **intent**, not execution. Orders define **what** needs to be delivered and **when** (date scope), but they do not dictate **how** fulfillment occurs.

- **Orders are Plans**: An order is a request for items to be delivered to a specific Mart on a specific Date.
- **Orders imply Operations**: Orders drive the "Remaining Quantity" metric which guides Dispatch operations.
- **Orders strictly respect Time**: An order is bound to its schedule date. It does not float or move.

## 2. Explicit Entry Modes

The UX enforces two strictly distinct modes to preserve data integrity and auditability.

### Create Order (Intent Definition)
- **Goal**: Establish a new requirement on the schedule.
- **Behavior**: All fields are editable. Defaults to "Today" for immediate operational relevance.
- **Constraint**: System prevents duplicates (Same Item + Same Mart + Same Date).
- **Result**: Adds to the "Ordered" total. "Remaining" equals "Ordered".

### Adjust Order (Correction only)
- **Goal**: Correct the quantity of an existing requirement.
- **Behavior**: User can **only** change Quantity. Context is locked.
- **Reasoning**: Changing the Date, Mart, or Item of an existing order would effectively be creating a *new* order and deleting the *old* one. Doing this in-place breaks audit trails and confuses dispatch history linked to that Order ID.

## 3. Field Locking Matrix

| Field | Create Mode | Adjust Mode | Reason for Lock in Adjust |
|-------|-------------|-------------|---------------------------|
| **Date** | Editable | **LOCKED** | Moving an order changes operational history. Create a new order instead. |
| **Mart** | Editable | **LOCKED** | Changing destination invalidates any partial dispatches linked to this Order ID. |
| **Item** | Editable | **LOCKED** | Changing item type invalidates specific batch dispatches already recorded. |
| **Unit** | Locked (1:1) | **LOCKED** | Tied to Item definition. Cannot change independently. |
| **Quantity** | Editable | **Editable** | The scale of intent can change (e.g., "Need 50 more"). This is the sole adjustment point. |

## 4. Relationship to Dispatch

Orders and Dispatches are decoupled but related:

- **Orders define the Ceiling**: `Quantity Ordered` is the target.
- **Dispatch fulfills segments**: Multiple dispatches can fulfill one order.
- **Remaining Quantity** = `Ordered` - `Sum(Dispatched)`.
- **Integrity Rule**: Modifying an Order's Quantity changes the *target*, but it NEVER mutates existing Dispatch records.
  - *Example*: You ordered 100, dispatched 50. If you adjust Order to 80, Remaining becomes 30. Dispatches remain 50.

## 5. UX Guarantees

1. **Human-Readable Dates**: Dates are always presented contextually ("Today", "Wednesday, Jan 15") to prevent scheduling errors.
2. **No Time Complexity**: Orders are strictly Date-based (Daily operations). Time of day is irrelevant for ordering.
3. **No Silent Mutations**: The system never auto-corrects an order's date or mart. User intent is absolute.
4. **Context Preservation**: If an error occurs (e.g., duplicate), the user's input context is preserved so they can correct it, rather than wiping the form.

## 6. Explicit Non-Goals

This screen will **NEVER**:
- **Move Orders across dates**: To reschedule, Delete and Create New.
- **Change Mart/Item in-place**: This is a new intent, not an edit.
- **Perform Dispatch**: Dispatch is a separate, batch-aware workflow (`DispatchEntryScreen`).
- **Adjust Inventory**: Orders are demand signals, not inventory mutations.
- **Show Analytics**: Operational dashboards belong elsewhere (`OverviewScreen`).
