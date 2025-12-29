# Core Ownership & Escalation Model

**Status:** ACTIVE  
**Effective Date:** 2025-12-24

---

## 1. Roles & Responsibilities

### The "Core Owner" (Engineering Lead)
*   **Authority**: Veto power on all changes to `stock_entry`, `rejection_entry`, `dispatch_entry`, and Ledger logic.
*   **Responsibility**:
    *   Reviewing RFCs for Core changes.
    *   Authorizing emergency SQL repairs (if absolutely unavoidable).
    *   Maintaining the integrity of the "Freeze".

### The "Operations Lead" (Admin)
*   **Authority**: Managing configuration (Items, UOMs, Batches) via the UI.
*   **Responsibility**:
    *   Monitoring the "Inventory Health" dashboard.
    *   Resolving UOM warnings (`sop_uom_diagnostics.md`).
    *   Escalating "Red" drift signals to Engineering.

### The "On-Call Engineer"
*   **Authority**: Read-only access to PROD DB. No write access without ticket.
*   **Responsibility**:
    *   Triaging 409 Conflict errors (`runbook_blocked_operations.md`).
    *   Diagnosing drift root causes.
    *   Restarting services if hung.

---

## 2. Escalation Ladder

### Level 1: Configuration Block (User Report)
*   **Symptom**: "I cannot dispatch this item."
*   **Resolution**: Operations Lead checks Admin Dashboard.
    *   If UOM error -> Ops Lead fixes item config.
    *   If System Error (500) -> Escalate to Level 2.

### Level 2: Runtime Failure / Bug (On-Call)
*   **Symptom**: System throwing 500s or timeouts.
*   **Resolution**: On-Call Engineeer investigates logs.
    *   If infrastructure issue -> Restart/Scale.
    *   If logic bug -> Rollback to previous version.
    *   If data corruption (Ledger Drift) -> Escalate to Level 3.

### Level 3: Protocol Breach / Drift (Core Owner)
*   **Symptom**: Ledger Drift > Threshold, or massive inventory loss.
*   **Resolution**: Core Owner takes command.
    *   **STOP THE LINE**: Halt all warehouse operations.
    *   **Audit**: trace every transaction for affected items.
    *   **Compensate**: Issue "Correction" entries. **NO DB UPDATES**.

---

## 3. Decision Authority Matrix

| Action | Operations Lead | On-Call Eng | Core Owner |
| :--- | :---: | :---: | :---: |
| Create Item | ✅ | ❌ | ✅ |
| Change UOM Config | ✅ | ❌ | ✅ |
| Restart Server | ❌ | ✅ | ✅ |
| **Hotfix Deploy** | ❌ | ✅ | ✅ |
| **Direct SQL Update** | ❌ | ❌ | ⚠️ (Requires Incident) |
| **Alter Schema** | ❌ | ❌ | ⚠️ (Requires RFC) |
