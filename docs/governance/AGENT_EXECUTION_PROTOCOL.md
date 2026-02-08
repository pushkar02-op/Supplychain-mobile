AGENT EXECUTION PROTOCOL

Version: 2.0
Status: ENFORCED
Owner: Human Controller

This document defines the mandatory execution contract
for all automated agents operating on this repository.

Violations are hard failures.

1. EXECUTION MODES (EXCLUSIVE)

An agent MUST declare exactly one mode before acting:

FACT_REPORT — read-only investigation

IMPLEMENT_PHASE — code changes

DOC_UPDATE — documentation only

AUDIT — read-only system review

No mode declared → IMMEDIATE STOP

2. BRANCH DISCIPLINE (UPDATED — HARD LAW)
🔒 Branch Model (Authoritative)

ONE branch per FEATURE

COMMITS represent PHASES

ONE PR per FEATURE

Allowed Branches for Agents
feature/<feature-slug>


Examples:

feature/item-lifecycle
feature/api-contract-integrity
feature/mobile-ci

Forbidden Actions (NON-NEGOTIABLE)

Agents MUST NEVER:

Work on main, develop, or release/*

Create branches per phase

Merge branches

Rebase

Amend commits

Force-push

Delete branches

3. BASE BRANCH RULE (UPDATED)

All feature/* branches MUST be created from:

develop


Agents MUST NOT branch from:

other feature branches

integration

main

This guarantees:

No hidden dependencies

No accidental coupling

Deterministic merges

4. PHASE DISCIPLINE (UPDATED)

A FEATURE consists of multiple PHASES

Each PHASE produces one or more commits

Phases are tracked by commit message, not branches

Commit Message Format (MANDATORY)
phase-<number><letter>: <concise description>


Examples:

phase-1a: numeric precision fact audit
phase-1b: enforce inventory_txn quantization
phase-1c: add precision governance tests

5. PRE-EXECUTION CHECKS (MANDATORY)

Before ANY action, the agent MUST explicitly verify and state:

Execution Mode

Current Branch

Must match feature/<slug>

Base Branch

Must be develop

Working Tree

git status MUST be clean

Active Phase ID

e.g. Phase 1B

Allowed Paths

Forbidden Paths

Declared Dependencies

NONE or explicitly listed

Failure of ANY check → IMMEDIATE STOP

## HARD PRECONDITION — CLEAN TREE

Before ANY IMPLEMENT_PHASE work:

- `git status --porcelain` MUST be empty
- If NOT empty → IMMEDIATE STOP

Agent MUST report:
- List of dirty files
- Suspected origin (previous phase / exploration / tooling)
- Ask human to decide:
  A) Discard
  B) Commit to correct branch
  C) Move to new feature


6. FILE SCOPE ENFORCEMENT

During IMPLEMENT_PHASE:

Only explicitly allowed files may be modified

Touching forbidden paths → STOP

Generated files must be declared before execution

Core freeze areas are immutable

7. COMMIT RULES (UPDATED)

Atomic commits only

One concern per commit

No mixed refactor + behavior

Commit messages MUST include phase tag

Allowed prefixes:

phase-x: ...
docs: ...
test: ...

8. DOCUMENTATION RULES (SIMPLIFIED)

Docs updated only when behavior changes

No per-run summary docs

No duplicate canon files

Feature-level docs consolidated once, at feature completion

9. STOP CONDITIONS (NON-NEGOTIABLE)

Agent MUST STOP immediately if:

Scope ambiguity exists

Required data is missing

Governance conflict detected

Human approval is required

A rule above cannot be satisfied

On STOP, agent must report:

What was attempted

Why it stopped

What decision is required

10. PHASE COMPLETION OUTPUT (MANDATORY)

At the end of each phase:

Phase: <id>
Feature Branch: feature/<slug>

Commits:
- <hash> — <summary>

Files Changed:
- <path>

Status:
- Phase complete
- Feature branch remains OPEN


❌ No PR
❌ No merge

### CLEAN TREE INVARIANT (NON-NEGOTIABLE)

An agent MUST NOT:
- start IMPLEMENT_PHASE
- declare phase complete
- output READY FOR PR

unless:

`git status --porcelain` is EMPTY.

If not empty:
- STOP immediately
- Report dirty files
- Require human classification


11. FEATURE COMPLETION OUTPUT (MANDATORY)

Only when ALL phases are complete:

Feature: <name>
Branch: feature/<slug>

Phases Completed:
- Phase 1A
- Phase 1B
- Phase 1C

Commits:
- <hash>
- <hash>

Status: READY FOR PR


Human approval is the ONLY merge authority.