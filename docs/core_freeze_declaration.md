# AGRO Supply Chain: Core Freeze Declaration

**Status:** FROZEN  
**Effective Date:** 2025-12-24  
**Enforced By:** Technical Owner / Engineering Lead

---

## 1. Explicit Declaration
The **AGRO Supply Chain Core** is hereby declared **FROZEN**.

This means the foundational logic governing inventory, money, and unit conversion is considered "Done". It is correct, verified, and hardened. From this point forward, **stability is prioritized over velocity** within the Core.

## 2. Definition of "Core"
The following components are subject to Freeze governance:

### A. Inventory Ledger
*   `stock_ledger_entries` table structure and logic.
*   `batch` table immutability rules (no SQL updates).
*   Drift detection logic.

### B. Unit of Measure (UOM) Logic
*   Binary compatibility of UOM definitions.
*   Conversion factor application logic.
*   The `UOMConfigurationError` fail-fast mechanism.

### C. Financial Precision
*   `NUMERIC(18,6)` usage for all quantities and costs.
*   Rounding rules in cost averaging.

### D. Critical User Flows
*   Stock Entry (Receipt)
*   Dispatch Entry (Shipment)
*   Rejection Entry (Waste)

## 3. Freeze Rules

### Allowed Changes (Green Lane)
*   ✅ **Bug Fixes**: Correcting logic that contradicts the original design spec (with regression test).
*   ✅ **Performance**: Optimizing query speed without changing the result set.
*   ✅ **Refactoring**: Code cleanup that does not alter public API signatures or side effects.
*   ✅ **Diagnostics**: Adding read-only views or logs (e.g., Phase 6A work).

### Forbidden Changes (Red Lane - Requires RFC)
*   ❌ **Schema Alterations**: Adding/removing columns to Core tables.
*   ❌ **Ledger Semantics**: Changing how "Weighted Average Cost" is calculated.
*   ❌ **Relaxing Constraints**: Removing Foreign Keys or NULL checks.
*   ❌ **Bypassing Safety**: Adding flags to "force" invalid transactions.

## 4. Examples of Disallowed Action
*   *"We need to support 'approximate' inventory for this one client."* -> **REJECTED**. Core requires precision.
*   *"Let's just allow negative stock for a few minutes."* -> **REJECTED**. Invariant violation.
*   *"Can we change the UOM ID to a string?"* -> **REJECTED**. Breakage risk too high.

---

**Signed:**  
*AGRO Supply Chain Engineering Team*  
*2025-12-24*
