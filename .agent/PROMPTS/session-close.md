# AGRO — Session Close Template

> This is the mandatory output format for every executor session.
> Every field is required. If a field cannot be populated, write
> `UNKNOWN — see NOTES` and explain in the NOTES field.
>
> `VALIDATION_STATUS: PASS` is a binding claim. Only write it if every
> applicable gate was run and passed. Writing it falsely is a critical
> failure.
>
> The human pastes this block to the planner for review (REVIEW VERDICT),
> then runs `./close-session.sh` to commit and push.

---

## SESSION CLOSE FORMAT

```
SESSION CLOSE
═══════════════════════════════════════════════════════

PHASE:        <phase ID and title — e.g., "G.6 COMPLETE" or "FEATURE: dispatch-hardening">
BRANCH:       <git branch name>
COMMIT:       <SHA — or NONE if no commit was made>

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

---

## FIELD RULES

**PHASE** — matches the phase label from the executor brief. Use the
same string the brief used.

**COMMIT** — write the short SHA (`git rev-parse --short HEAD`) after
committing. Write `NONE` if no commit was made (doc-only sessions where
pre-commit hooks skipped, write the SHA anyway if a commit was made).

**VALIDATION_STATUS** — the summary gate:
- `PASS` — all applicable gates ran and passed
- `FAIL` — at least one applicable gate failed
- `PARTIAL` — some gates were not applicable (mark those `NOT_RUN`)

**STATE_DELTA** — a machine-readable diff to be applied to `state.json`
by `close-session.sh`. Only include fields that actually changed.

**GAPS_SURFACED** — this is intelligence, not failure. List anything
discovered that is outside scope and should become a future brief.

---

## FACT_REPORT (attach before SESSION CLOSE when a STOP occurred)

```
FACT_REPORT
═══════════════════════════════════════════════════════

BRANCH:               <branch>
COMMIT:               <SHA or NONE>

FILES_CHANGED:
  CREATED:   [list or NONE]
  MODIFIED:  [list or NONE]
  DELETED:   [list or NONE]

INVARIANTS_TOUCHED:
  <INV-ID>: <how relevant>  or NONE

TEST_STATUS:
  COMMAND:  <exact command>
  RESULT:   PASS | FAIL | NOT_RUN
  OUTPUT:   <verbatim last 20 lines or "NOT_RUN — reason">

ANALYZE_STATUS:
  COMMAND:  <exact command>
  RESULT:   PASS | FAIL | NOT_RUN
  OUTPUT:   <verbatim last 20 lines or "NOT_RUN — reason">

REGRESSION_STATUS:
  GOVERNANCE_TESTS: PASS | FAIL | NOT_RUN
  SCHEMA_DRIFT:     NONE | DETECTED — <description>
  FLOAT_COLUMNS:    NONE | DETECTED — <file:line>
  ALEMBIC_HEADS:    SINGLE | MULTIPLE | NOT_CHECKED

STOP_TRIGGERED:       YES — <reason>  |  NO
GAPS_FOUND:           [list]  or NONE
NEW_TERMS_INTRODUCED: [list]  or NONE

NOTES:
  <max 5 sentences>

═══════════════════════════════════════════════════════
```
