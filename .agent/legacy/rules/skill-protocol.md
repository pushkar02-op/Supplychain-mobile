# AGRO Supply Chain — Agent Operating Rules

## Skill Invocation Protocol

Before making ANY changes to this codebase, you MUST:

1. **Check for applicable skills** in `/.agent/skills/`
2. **Read the full SKILL.md** for any skill that matches your task context
3. **Follow the skill's STOP Conditions** — halt if any are triggered
4. **Apply the skill's validation criteria** before completing work

## Skill Trigger Quick Reference

| If working on... | Read this skill FIRST |
|------------------|----------------------|
| Inventory, stock, batch, dispatch, quantities | `ledger-invariant-enforcer` |
| Backend tests (`tests/*.py`) | `test-schema-compliance`, `test-isolation-enforcement` |
| Alembic migrations | `alembic-chain-integrity` |
| Price/quantity arithmetic | `decimal-purity-enforcement` |
| Stock list or receipt UI | `receipt-batch-separation-guard` |
| Blocking/void actions | `void-trap-prevention` |
| Editing dispatch/receipt/rejection | `immutable-event-correction` |
| List endpoints or history screens | `pagination-before-scale` |
| Locked/frozen phases | `read-only-phase-lock` |
| Error messages or dialogs | `ux-copy-truthfulness` |
| Git push or merge | `branch-phase-discipline` |
| Unclear requirements | `stop-and-ask`, `fact-report-first` |

## Non-Negotiable Rules

1. **Never edit ledger tables directly** (UPDATE/DELETE forbidden on `inventory_txn`)
2. **Never use float for money/quantity** — use `Decimal` only
3. **Never skip test cleanup** — each test must be isolated
4. **Never assume** — when unclear, read `stop-and-ask` skill

## How to Read a Skill

```bash
# Use view_file on the skill before starting work:
/.agent/skills/<skill-name>/SKILL.md
```

Then follow its Step-by-Step Strategy exactly.
