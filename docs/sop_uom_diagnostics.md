# SOP: Resolving UOM Diagnostics

**Version:** 1.0  
**Last Updated:** 2025-12-24  
**Audience:** Admin only

---

## 1. Objective
Identify and resolve Item configuration issues that are blocking inventory operations, using the Admin Diagnostics tools.

## 2. Accessing Diagnostics
1.  Log in as an **Admin** user.
2.  Navigate to **Dashboard**.
3.  Scroll to the **Administration** section.
4.  Tap **UOM Diagnostics**.

---

## 3. Interpreting the Screen

The screen lists all items that are currently **BLOCKED** from operations.

### Warning Types
1.  **"BLOCKED: Missing Default UOM"**
    *   **Meaning**: This item has `default_uom_id = NULL`.
    *   **Impact**: No stock can be added, removed, or transferred. Ledger logic cannot determine the target unit.

---

## 4. Resolution Steps

### Scenario A: New Item (No Stock)
1.  Identify the item name/ID from the Diagnostics screen.
2.  Navigate to **Items** list.
3.  Search for the item.
4.  Open **Item Details** > **Edit**.
5.  Select the correct **Default UOM**.
6.  Save.
7.  Return to Diagnostics screen and **Swipe to Refresh**. The item should disappear.

### Scenario B: Legacy Item (Has History)
*If an item appears here but has existing batches (rare, indicates data corruption):*
1.  **DO NOT** simply pick a UOM at random.
2.  Check physical inventory or historical logs to determine what unit was used previously.
3.  Select the UOM that matches *existing* physical stock counts.
4.  If unsure, escalate to Engineering to audit `batch` table units before applying the fix.

---

## 5. Verification
After resolving an item:
1.  Refresh **UOM Diagnostics** -> Item is gone.
2.  Attempt a valid **Stock Entry** (dry-run) -> No "Not fully configured" error.

---

## 6. Safety Warnings
> **WARNING**: The Diagnostics screen is Read-Only by design. You must fix the issue in the Item Management screens. This separation ensures you deliberately verify the item details before applying a fix.
