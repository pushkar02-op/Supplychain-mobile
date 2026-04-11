---
name: alembic-chain-integrity
description: Prevents orphan migrations and multiple-head conditions in Alembic.
---

## When to Trigger
- Creating a new Alembic migration
- Merging branches that both contain migrations
- CI failure mentioning "multiple head revisions"

## Step-by-Step Enforcement Strategy
1. Before creating migration, run `alembic heads`.
2. If multiple heads exist:
   - STOP
   - Require merge migration or head resolution first
3. When creating migration:
   - Verify `down_revision` matches current single head
   - Never set `down_revision = None` (except initial)
4. After creation, run `alembic heads` again.
5. Confirm exactly ONE head exists.

## STOP Conditions (Mandatory)
- `alembic heads` returns more than one revision
- `down_revision` is set to `None` on non-initial migration
- Migration file references non-existent revision

## Validation & Acceptance Criteria
- `alembic heads` returns exactly one revision after any migration change
- `alembic upgrade heads` succeeds in CI
- No orphan migrations in versions directory

## Failure Modes Prevented
- "Multiple head revisions" CI failures
- Blocked database schema upgrades
- Branch merge conflicts in migration chain

## Explicit Non-Responsibilities
- Does NOT validate migration SQL correctness
- Does NOT check for destructive migrations
- Does NOT enforce migration naming conventions