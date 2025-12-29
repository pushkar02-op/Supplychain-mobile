# SOP: Item Onboarding (UOM-Safe)

**Version:** 1.0  
**Last Updated:** 2025-12-24  
**Audience:** Admin, Operations Managers

---

## 1. Objective
Ensure every new item created in the system has a valid Unit of Measure (UOM) configuration to prevent inventory ledger corruption and blocked operations.

## 2. Preconditions
Before creating an item, you must know:
1.  **Item Name / Code** (Unique identifier).
2.  **Default UOM** (The base unit for inventory storage, e.g., `kg`, `liters`, `units`).
3.  **Conversion Factors** (If you buy/sell in different units, e.g., Buy in `boxes`, Store within `units`).

> **CRITICAL**: The system creates a continuous inventory ledger. Once an item has stock, its Default UOM cannot be easily changed without complex migration. **Get it right the first time.**

---

## 3. Step-by-Step Procedure

### Step 1: Create the Item
1.  Navigate to **Items** > **Create New**.
2.  Enter Name and Item Code.
3.  **IMMEDIATELY** sets the `Default UOM`.
    *   *Note: If the current UI does not prompt for UOM on creation, you MUST navigate to Item Details immediately after creation to set it.*

### Step 2: Verify Configuration
1.  Go to the **Item Details** screen.
2.  Confirm `Default Unit` is populated (e.g., `kg`).
3.  If `Default Unit` is `null` or empty:
    *   **STOP**. Do not receive stock.
    *   Edit the item and select a valid UOM.

### Step 3: Configure Conversions (If applicable)
If you intend to receive this item in units *other* than the Default UOM (e.g., Receive in `Tons`, Store in `kg`):
1.  Navigate to **Conversions**.
2.  Add a mapping: `1 Ton = 1000 kg`.
3.  Save.

### Step 4: Dry-Run Verification
1.  Open **Stock Entry** screen.
2.  Select the new item.
3.  Select the intended receiving unit.
4.  If the system allows you to proceed, the configuration is valid.
5.  If you see an error: *"This item is not fully configured"*, verify Step 2 and 3.

---

## 4. Common Errors & Blocks

| Error Message | Cause | Resolution |
|/---|---|---|
| **"This item is not fully configured..."** | Missing Default UOM | Set Default UOM in Item Details. |
| **"No conversion factor found..."** | Receiving unit != Default UOM, and no map exists | Add conversion rule (e.g., Lbs -> Kg). |

## 5. "Do NOT Do This"
*   ❌ **Do NOT** receive stock before setting the UOM. The system will block you (409 Error), but attempting to bypass this via SQL will corrupt the ledger.
*   ❌ **Do NOT** assume 'Units' is a safe default. Always be specific (e.g., 'Each', 'Box').
