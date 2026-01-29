# Item UX Canon

> **Version**: 1.0  
> **Last Updated**: 2026-01-29  
> **Status**: LOCKED (Authoritative)

This document is the **single source of truth** for all Item-related User Experience surfaces in the AGRO Supply Chain application. It codifies decisions made/confirmed during phases UX-1 through UX-6.

**Governance Rule**: No new intelligence, recommendations, or decision support features may be added to these surfaces without a formal RFC and Controller approval.

---

## 1. Purpose & Philosophy

The Item UX is designed as a **Passive Memory System**, not an Active Assistant.

### Core Principles
1.  **Evidence-First**: Show only what is known (facts). Never guess, infer, or predict without explicit "Forecast" labeling.
2.  **Context Without Guidance**: Provide data (e.g., "Seen 5 times") but **never** recommend actions (e.g., "You should use this").
3.  **Silence is Correct**: If data is missing or zero, show **nothing**. Do not clutter the UI with "N/A", "0", or empty placeholders.
4.  **Read-Only by Default**: Most surfaces are for observation. Input surfaces (Creation/Editing) are strictly separated.

---

## 2. Item UX Surfaces (CANONICAL)

### A. Item List (UX-5)
*   **Purpose**: A living index for navigation and high-level status checks.
*   **Location**: `ItemListScreen`
*   **Allowed Signals**:
    *   **Aliases**: Count of aliases (e.g., "Aliases: 3") if > 0.
    *   **Conversions**: Count of conversions (e.g., "Conversions: 2") if > 0.
    *   **Default UOM**: Always visible.
*   **Forbidden Signals**:
    *   Forecasting data (unavailable in list API).
    *   "Last Used" stamps (unavailable in list API).
    *   Any color-coded status or warnings.

### B. Item Detail (UX-1)
*   **Purpose**: Deep inspection of a single item's "File". A canonical truth source.
*   **Location**: `ItemDetailScreen`
*   **Sections (Fixed Order)**:
    1.  **Identity**: Name, Code, Default UOM (The "What").
    2.  **Aliases**: List of all mapped aliases + seen counts (The "External Names").
    3.  **Conversions**: List of defined unit logic (The "Math").
    4.  **Forecasting**: (If Admin) Operational signals like Burn Rate, Stockout Date.
*   **Behavior**:
    *   **Read-Only**: No inline editing.
    *   **Memory Surface**: Shows "Seen X times" for aliases to prove validity.

### C. Item Create / Edit (UX-4)
*   **Purpose**: Defining or refining the Item entity.
*   **Location**: `ItemManagementScreen`
*   **Structure (Fixed Order)**:
    1.  **Identity**: Name (with Duplicate Awareness Advisory), Code, Default UOM.
    2.  **Units & Conversions**: Base UOM display + Conversion definitions.
    3.  **Naming & Aliases**: External alias mappings.
*   **Constraints**:
    *   **Duplicate Awareness**: "Advisory Only" warning. Does NOT block creation.
    *   **Validation**: Strict UOM enforcement.
    *   **No "Smart" Defaults**: User must explicitly choose UOMs.

### D. Alias Mapping (UX-2)
*   **Purpose**: Linking incoming ambiguous invoice items to master items.
*   **Location**: `AliasMappingScreen`
*   **Key Feature**: **Context Panel**.
    *   When an item is selected, show "Existing aliases for this item" below the dropdown.
    *   **Why**: Prevents "over-mapping" (mapping to the wrong variant) by showing what is *already* mapped.

### E. Conversions (UX-3)
*   **Purpose**: Defining unit math.
*   **Location**: `ItemManagementScreen` (Units Section)
*   **Key Feature**: **Context Panel**.
    *   Display existing conversions to avoid redundancy or conflict.
    *   **Why**: Users forget what math they already taught the system.

---

## 3. Explicitly Skipped / Absent UX

The following features were considered but **deliberately skipped** due to data unavailability or constraint violations. **Do not attempt to implement them.**

### ❌ UX-6: Item Activity Snapshot
*   **Concept**: Showing "Last Received", "Last Dispatched", "Used in last 30 days" on `ItemDetailScreen`.
*   **Status**: **SKIPPED**.
*   **Reason**: Backend `ItemManagementRead` model does not contain activity timestamps. Adding them would violate "No Backend Changes" and "No New API Calls" constraints.
*   **Rule**: Do not show "Activity" or "Usage" sections unless the backend explicitly provides this data in the future.

---

## 4. Copy & Language Rules

1.  **Neutral Tone**: Use "Seen 5 times", not "Frequent". Use "Default UOM", not "Recommended UOM".
2.  **No Directives**: Never use words like "Should", "Must", "Consider", "Try".
3.  **No Judgment**: Avoid "Good", "Bad", "Missing", "Incomplete". Use factual states: "No aliases", "0 conversions".
4.  **Advisory Labels**: Any logic that is fuzzy (like Duplicate Awareness) must be labeled "**(Advisory Only)**".

---

## 5. Stop Conditions

*   **Missing Data**: If a field is null/empty in the API response, **render nothing**. Do not render "N/A" or placeholders unless strictly required by layout.
*   **Uncertainty**: If you are unsure if a signal implies a recommendation, **remove it**.
*   **New Features**: If a user asks for "Smart Suggestions" or "Auto-Mapping", **STOP**. Refer to Governance (this document).


---

## 6. Item Lifecycle & Archival (LOCKED)

**Governed by**: `docs/governance/ITEM_LIFECYCLE.md`

### A. No Deletion
- **Rule**: There is no "Delete" button anywhere in the Item UX.
- **Rule**: The "Trash Can" icon is forbidden for Items.

### B. Lifecycle Actions
- **Location**: Use the **Item Management Screen** (Edit Mode) for lifecycle changes.
- **Actions**:
    - **Deactivate**: Moves Active -> Inactive. Requires explicit confirmation dialog.
    - **Reactivate**: Moves Inactive -> Active. Immediate action.

### C. Visibility Logic
- **Default**: Lists show `ACTIVE` items only.
- **Opt-In**: A toggle (e.g., "Show Inactive") is required to reveal archived items.
- **Visuals**: Inactive items are rendered with reduced opacity and an "Inactive" badge.

### D. Read-Only Indication
- `ItemDetailScreen` must include a **Lifecycle Panel** at the top.
- **Active**: Green indicator, standard text.
- **Inactive**: Grey indicator, explanatory text ("This item is deactivated...").
