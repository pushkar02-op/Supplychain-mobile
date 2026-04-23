# AGRO — Executor Brief Template

> This is the format contract for all work delivered to an executor.
> Every field marked REQUIRED must be present. Optional fields may be
> omitted only if the reason is stated.
>
> Emit this after the executor-bootstrap.md paste. The executor reads
> the bootstrap first, then this brief.

---

## EXECUTOR BRIEF

**Session ID:** YYYY-MM-DD-slug
_(slug = 3-5 word kebab-case description of the task)_

**Branch:** feature/<name> | chore/<name> | fix/<name>
_(must not be develop or main)_

**Agent target:** claude-code | codex | generic
_(which executor tool this is written for)_

**Mode:** plan-first | direct
- `plan-first` — executor produces a plan and STOPS; planner reviews
  before execution begins
- `direct` — executor proceeds to implementation without a plan review

**Parent session:** YYYY-MM-DD-slug | NONE
_(link to the session that produced this brief, if continuing work)_

---

### Invariants

List every invariant ID from `01-INVARIANTS.md` that applies to this work.
The executor must read these in full and confirm they are not violated.

- LED-001: ...
- IMM-002: ...
_(add as needed)_

---

### Scope

Files expected to be created or modified. This list is the ceiling.
The executor must not touch files outside this list.

**Creating:**
- `path/to/new/file.py` — purpose

**Modifying:**
- `path/to/existing/file.py` — what changes

**Read-only (context only, no edits):**
- `path/to/reference/file.py`

---

### Out of scope

Explicit list of things the executor must NOT do, even if they seem
related or helpful. Any observation about out-of-scope work goes in
`GAPS_SURFACED` in SESSION CLOSE — not in the code.

- Do NOT refactor X
- Do NOT touch Y
- Do NOT fix Z (separate brief)

---

### Task

Full description of the work. Be specific. Reference exact function names,
field names (using canonical names from `04-GLOSSARY.md`), and line ranges
where known.

#### Background
_Why this work is needed. What problem it solves._

#### Requirements
1. _Specific, verifiable requirement_
2. _Specific, verifiable requirement_
...

#### Acceptance criteria
- [ ] _Testable condition that confirms the work is complete_
- [ ] _Testable condition_
...

---

### Documentation impact

Which docs must be updated in this same session. If none, write NONE.
Sessions that skip required docs are REJECTED in review.

- `docs/<file>.md` — what to add/update
- `.agent/STATE/state.json` — state delta (if phase changes)

---

### Validation

Exact commands the executor must run and show verbatim output for.
Do not write `PASS` without running these.

```bash
# Run all backend tests (fail fast)
pytest backend/tests/ -x

# Run governance tests specifically
pytest backend/tests/test_governance_*.py -v

# If Flutter files touched
flutter analyze

# If migration added
alembic heads
```

---

### SESSION CLOSE template

The executor's final output must be in this exact format.
This is the complete contract — every field is required.
See `.agent/PROMPTS/session-close.md` for field-level rules.

```
SESSION CLOSE
═══════════════════════════════════════════════════════

PHASE:        <phase ID and title — must match this brief's phase label>
BRANCH:       <git branch name>
COMMIT:       <short SHA — or NONE if no commit was made>

CHANGES:
  CREATED:    [<path> — <one-line description>, ...]  or NONE
  MODIFIED:   [<path> — <what changed>, ...]          or NONE
  DELETED:    [<path>, ...]                            or NONE

VALIDATION_STATUS:  PASS | FAIL | PARTIAL
  TESTS:            PASS | FAIL | NOT_RUN — <reason if NOT_RUN>
  ANALYZE:          PASS | FAIL | NOT_RUN — <reason if NOT_RUN>
  GOVERNANCE:       PASS | FAIL | NOT_RUN — <reason if NOT_RUN>
  ALEMBIC:          SINGLE | MULTIPLE | NOT_CHECKED — <reason if NOT_CHECKED>

INVARIANTS_TOUCHED:
  <INV-ID>: <one sentence — what was confirmed or guarded>
  ...
  or NONE

RISKS:
  REGRESSION_RISK:  NONE | LOW | MEDIUM | HIGH — <reason if not NONE>
  STRUCTURAL_RISK:  NONE | LOW | MEDIUM | HIGH — <reason if not NONE>
  OPEN_QUESTIONS:   [list of unresolved items for next session]  or NONE

GAPS_SURFACED:
  [list of out-of-scope observations, bugs discovered, or follow-up work]
  or NONE

NEW_TERMS_INTRODUCED:
  [list — each new canonical term added per 04-GLOSSARY.md §6]
  or NONE

STATE_DELTA:
  phase: "<new phase name>"
  current_focus: "<one line>"
  subsystems:
    <subsystem>: { "status": "stable|ux_transition|refactor|broken", "invariants_ok": true|false }
  open_threads: ["<thread>", ...]
  next_actions: ["<action>", ...]

NEXT_PHASE:   <phase ID and title>  |  AWAITING_HUMAN_DECISION

NOTES:
  <free text — max 5 sentences — for anything not captured above>

═══════════════════════════════════════════════════════
```
