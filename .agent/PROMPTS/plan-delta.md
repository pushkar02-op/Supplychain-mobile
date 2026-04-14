# AGRO — Plan Delta Template

> Used by the Planner to communicate corrections to an executor's submitted
> plan (in `plan-first` mode). Emit this after reviewing the executor's
> plan. The executor applies the delta and re-submits a revised plan.
>
> Never approve-and-correct in the same message. Either APPROVE the plan
> and say "proceed to execution", or emit a PLAN DELTA and wait for the
> revised plan.

---

## PLAN DELTA

**Session ID:** YYYY-MM-DD-slug
_(must match the session ID in the executor's plan)_

**Plan revision:** 1 | 2 | 3
_(increment on each round-trip)_

---

### Approved sections

List plan step numbers that are approved and need no changes.

Approved: 1, 2, 4, 7

---

### Required changes

For each section that needs changes, state:
- What the executor planned
- What to do instead
- Why (one sentence — the reason grounds future judgment)

```
Section 3:
  Current: <what executor said>
  Replace with: <what it should be>
  Reason: <why>

Section 5:
  Current: <what executor said>
  Add before it: <what to add>
  Reason: <why>

Section 6:
  Remove entirely.
  Reason: <why — e.g., "out of scope per brief §Out of scope">
```

---

### Invariant notes

If the correction is invariant-driven, name the invariant explicitly
so the executor can re-check it.

- LED-001 requires that `create_inventory_txn` is called before
  `db.commit()`, not after. Section 3 has these reversed.

---

### Instruction

Re-submit the plan with these changes applied.
Do not begin execution until the revised plan is APPROVED.

---

## APPROVAL (separate message, do not combine with PLAN DELTA)

When the plan is acceptable, send this instead of a PLAN DELTA:

```
## PLAN APPROVED
Session ID: YYYY-MM-DD-slug
Plan revision: N
Proceed to execution.
```
