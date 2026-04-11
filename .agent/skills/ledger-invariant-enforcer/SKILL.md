---
name: ledger-invariant-enforcer
description: Enforces immutable ledger rules before any backend or UX change touching inventory, dispatch, rejection, or forecasting.
---

## When to use this Skill
Trigger this Skill whenever:
- A backend change touches inventory, stock, batch, dispatch, rejection, adjustment, or forecasting logic
- A frontend screen displays inventory quantities
- A bug involves "wrong stock", "unexpected balance", or "drift"

## Step by Step Strategy
1. Identify all tables involved in the change.
2. Classify each table as:
   - Ledger (immutable)
   - Derived cache
   - Read model
3. Verify:
   - No UPDATE/DELETE is applied to ledger tables
   - All mutations create exactly one ledger entry
4. Confirm Decimal arithmetic (no float math in core logic).
5. If violation detected:
   - STOP
   - Produce a FACT REPORT
   - Reject the change

## Edge Cases & Best Practices
• Derived tables may be recalculated, never treated as truth  
• Reversals must be additive ledger entries  
• "Fixing" data by editing history is forbidden  

## Validation & Acceptance Criteria
• Ledger tables untouched by UPDATE/DELETE  
• All mutations traceable in inventory_txn  
• Drift remains visible  

## Common Failure Modes
• Editing receipts directly  
• Adjusting batch.quantity without ledger entry  
• Using float math in calculations  

Why this Skill exists

This project repeatedly hit ledger corruption risk.
This Skill ensures no agent ever "just fixes the number" again.
