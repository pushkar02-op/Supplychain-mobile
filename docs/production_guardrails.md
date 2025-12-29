# Production Guardrails Checklist

**Status:** ACTIVE  
**Audience:** DevOps / SRE / On-Call

---

## 1. Deployment Guardrails
Before deploying any new backend version:
*   [ ] **Migration Check**: Does this release include Alembic migrations?
    *   *If YES*: Have they been tested against a staging DB with real data volume?
*   [ ] **Lock Check**: Does the migration lock the `stock_ledger_entry` table?
    *   *If YES*: Reject. Maintenance window required.
*   [ ] **Rollback Artifact**: Is the *previous* Docker image available and tagged?

## 2. The "3 Commandments" of Production
1.  **Thou shalt not write SQL against `batch`, `stock_ledger_entry`, or `item` in PROD.**
    *   Use the Admin UI. If the UI blocks you, investigate why.
2.  **Thou shalt not deploy code that calculates money using `FLOAT`.**
    *   Grep your PRs for `float`, `Real`, or javascript `number`. Mandatory reject.
3.  **Thou shalt not ignore Drift signals.**
    *   If `AdminInventoryDrift` > 0, you do not ship new features. You fix the drift.

## 3. Monitoring Expectations
### Health Signals
*   **Green**: `GET /admin/ledger/health` returns status OK, drift 0.
*   **Yellow**: Drift < 0.01 (Rounding dust). Monitor weekly.
*   **Red**: Drift > 0.01 OR Any 500 error on `stock_entry`. **Paged Incident**.

### Logs to Watch
*   `UOMConfigurationError` spikes: Indicates a configuration training issue for Ops.
*   `IntegrityError` (DB): Indicates a code bug managing concurrency.
*   `RemoteDisconnected`: Indicates server overload / uvicorn worker crash.

---

## 4. Incident Response Principles
*   **Diagnose First**: Do not restart. Do not patch. Read the headers. Check the Diagnostics screen.
*   **Compensate, Never Overwrite**: If inventory is wrong, issue a +/- correction entry. Never `UPDATE stock_entry SET qty = ...`.
*   **Blameless Root Cause**: If the Core breaks, it's a process failure, not a person failure. Update the `runbook` and `freeze_declaration`.
