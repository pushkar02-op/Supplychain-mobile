# Runbook: Ledger Drift Detection

**Severity:** Low (Monitoring) / High (If drift increases)  
**Trigger:** Admin checks "Inventory Health" screen and sees non-zero drift.

---

## 1. Conceptual Overview
**Ledger Drift** occurs when the sum of individual batch quantities (`batch.quantity`) does not equal the system's aggregated total (if stored separately) or if the transaction ledger (`stock_ledger_entries`) sum differs from current batch state.
*   *Note: In the current hardened architecture, the Ledger is strict. Drift implies a massive bug or manual DB tampering.*

## 2. Interpretation (Admin UI)

### "Healthy" (Green)
*   Drift = 0.000
*   Action: None. System is consistent.

### "Check Required" (Yellow)
*   Drift > 0 but small (< 0.01 units).
*   **Cause**: Historical floating-point dust (pre-Phase 4 fixes).
*   **Action**: Monitor. Do not panic.

### "Critical" (Red)
*   Drift > 1.0 units.
*   **Cause**:
    *   Manual SQL update to `batch` table?
    *   Concurrency bug during dispatch?
    *   Conversion factor changed mid-flight?
*   **Action**: **IMMEDIATE ESCALATION**.

---

## 3. Resolution Steps

### Step 1: Quarantine
1.  Identify which Item ID has drift.
2.  Instruct Operations to **STOP** moving that item.

### Step 2: Audit
1.  Admin/Engineer reviews `stock_ledger_entry` vs `batch` history.
2.  Check for "Manual Adjustment" entries that might have been entered incorrectly.

### Step 3: Repair (Engineering Only)
*   **Admins**: Do NOT attempt to fix drift by adding fake stock.
*   **Engineering**: Create a compensating `Stock Adjustment` transaction to bring the ledger back in sync.
    *   *Never update `batch.quantity` via SQL.*

---

## 4. Escalation Policy
*   If Drift > 5% of Total Inventory: **P0 Incident**.
*   If Drift exists but is stable (not growing): **P2 Bug**.
