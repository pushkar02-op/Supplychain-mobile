# Runbook: Blocked Inventory Operation (409 UOM Error)

**Severity:** Medium (Operational Blocker)  
**Trigger:** User reports "This item is not fully configured" error or receives a `409 Conflict`.

---

## 1. Symptom Analysis
*   **User Report**: "I cannot add stock / I cannot make a rejection."
*   **Error Message**: "This item is not fully configured. Please contact an admin to set its default unit of measure."
*   **Technical Error**: `UOMConfigurationError` (HTTP 409).

## 2. Triage Steps

### Step 2.1: Verify Diagnostics
1.  Ask the Admin to check **UOM Diagnostics** in the app.
2.  If the item appears in the list -> **It is a Configuration Issue**. (Go to Resolution A)
3.  If the item does NOT appear -> **Check Conversion**. (Go to Resolution B)

### Step 2.2: Check Logs (If accessible)
Look for `UOMConfigurationError` in backend logs.
*   Log message: `Item id=123 has no default UOM configured.` -> **Missing UOM**.
*   Log message: `No conversion factor found for item_id=123 from 'Box' to 'Kg'.` -> **Missing Conversion**.

---

## 3. Resolution Paths

### Resolution A: Missing UOM
*   **Cause**: Item created without a Default Unit.
*   **Fix**:
    1.  Admin opens Item Details.
    2.  Sets Default Uom.
    3.  User retries operation.

### Resolution B: Missing Conversion
*   **Cause**: User is trying to transact in a unit (e.g., 'Box') that has no mapping to the Base unit ('Kg').
*   **Fix**:
    1.  Admin opens Item Details -> Conversions.
    2.  Add mapping (e.g., `1 Box = 12 Kg`).
    3.  User retries operation.

### Resolution C: Bug (Escalation)
*   **Criteria**: Item has UOM, has valid Conversion, but still fails.
*   **Action**: Escalate to Engineering.
*   **Data Required**: Item ID, From Unit, To Unit, Timestamp.

---

## 4. Operational Rules
*   **NEVER** directly INSERT into the `batch` table to bypass this check.
*   **NEVER** change the `default_uom_id` of an item that already has stock without a full migration plan (Engineering only).
