# AGRO Repository — Agent Operating Model

> **This file is canonical.** It defines how every executor agent must
> operate: the mandatory pipeline from first read to SESSION CLOSE, the
> exact format of FACT_REPORTs and SESSION CLOSEs, STOP conditions, prompt
> types, validation gates, and behavior rules.
>
> Violating this model — skipping steps, guessing, proceeding through a
> STOP — is a structural failure, not a style issue. It causes damage that
> compounds.

---

## Section 1 — Execution Pipeline

Every executor session MUST follow this pipeline in order. Steps are not
optional. Steps may not be reordered. If a step cannot be completed, the
agent STOPs and reports. It does not skip forward.

---

### Step 1: FACT DISCOVERY

**Purpose:** Establish ground truth before any work begins. The agent
reads all required context files and the relevant source files for the
task. No assumptions, no recalled facts, no guesses.

**Required actions:**
1. Read `.agent/CORE/00-IDENTITY.md` — confirms mode and rules
2. Read `.agent/CORE/01-INVARIANTS.md` — loads all 26 invariants
3. Read `.agent/CORE/02-ARCHITECTURE.md` — loads layer rules
4. Read `.agent/CORE/03-SYSTEM_MAP.md` — loads entity and flow map
5. Read `.agent/CORE/04-GLOSSARY.md` — loads canonical terms
6. Read this file (`.agent/CORE/05-OPERATING_MODEL.md`)
7. Read `.agent/STATE/state.json` — loads current phase and health
8. Read every source file referenced in the brief — no section skipped,
   no file omitted because it "looks unchanged"

**Required output:** An internal list of confirmed facts before proceeding
to Step 2. These facts include: current branch, relevant invariant IDs,
files that will be touched, and the exact service/model functions in scope.

**Failure behavior:** If any required file cannot be read (file not found,
path wrong, content unreadable), STOP. Report the missing file in a
FACT_REPORT. Do not proceed using cached or assumed content.

---

### Step 2: GAP ANALYSIS

**Purpose:** Identify what is missing, ambiguous, or conflicting before
committing to a plan. This step surfaces problems early, when they are
cheap to resolve.

**Required actions:**
1. List all invariants from `01-INVARIANTS.md` that are triggered by
   the work in this brief (use the Triggered-By Index)
2. For each triggered invariant, read its Stop Condition field in full
3. Identify any precondition that is not confirmed by FACT DISCOVERY
4. Identify any schema field, function signature, or model attribute
   referenced in the brief that does not exist in the current code
5. Identify any requirement in the brief that conflicts with an invariant

**Required output:** A written gap list. Format:
```
GAP ANALYSIS
- [CONFIRMED] <item> — verified in <file:line>
- [MISSING] <item> — not found; STOP required before proceeding
- [AMBIGUOUS] <item> — two interpretations possible; human input needed
- [CONFLICT] <item> — brief says X; invariant <ID> requires Y
```

**Failure behavior:** If any MISSING, AMBIGUOUS, or CONFLICT item exists,
STOP. Do not proceed to Step 3. Surface the gap list in a FACT_REPORT
and wait for human instruction. A brief that contains any unresolvable
gap must not be executed.

---

### Step 3: DECISION LOCK

**Purpose:** Record every non-trivial decision before it is acted on,
so the human can inspect and approve the approach before code is written.

**Required actions:**
1. State the implementation approach in one paragraph — what will be
   done, in what order, and why
2. List every file that will be created or modified
3. List every invariant that applies and confirm it will not be violated
4. State the single commit message that will be used
5. State any assumption being made and why it is safe

**Required output:**
```
DECISION LOCK
APPROACH: <one paragraph>
FILES_TO_CHANGE: [list]
INVARIANTS_CONFIRMED: [list of IDs with one-line confirmation each]
COMMIT_MESSAGE: <verbatim>
ASSUMPTIONS: [list, or NONE]
```

**Failure behavior:** If the approach cannot be stated without assumptions
that are not confirmed by FACT DISCOVERY, STOP. If writing out the decision
reveals a conflict not caught in Step 2, STOP. The DECISION LOCK is a
final check, not a formality.

---

### Step 4: PLAN

**Purpose:** Produce a step-by-step execution plan that maps every action
to a specific file, function, and line range. The plan is the executor's
contract with itself — every step in the plan will be executed; nothing
outside the plan will be done.

**Required actions:**
1. Number every action in execution order
2. For each action: state the file path, the function or class being
   modified, and the exact nature of the change
3. Mark which steps touch invariant-sensitive code (flag with the
   invariant ID)
4. Mark which step is the final `db.commit()` anchor (for mutation plans)
5. Mark which step runs validation (flutter analyze, pytest)

**Required output:**
```
PLAN
1. Read <file> lines <N-M> to confirm current state
2. Edit <file>::<function> — <what changes and why>  [LED-001]
3. Create <file> — <purpose>
...
N. Run pytest backend/tests/<test_file>.py
N+1. Run flutter analyze (if frontend touched)
```

**Failure behavior:** If a plan step cannot be stated without "figure out
what to do when I get there," STOP. Vague plan steps are a sign of
unresolved ambiguity from Step 2.

---

### Step 5: EXECUTION

**Purpose:** Mechanically execute the plan from Step 4. No improvisation.
No scope expansion. No "while I'm here" changes.

**Required actions:**
1. Execute each plan step in order
2. After each step that writes code: re-read the written code to confirm
   it matches the plan
3. If a step reveals that the plan is wrong (the file looks different
   than expected, the function signature has changed): STOP. Do not
   continue with the original plan. Surface the discrepancy in a
   FACT_REPORT.
4. If a step produces an error that was not anticipated: STOP. Do not
   attempt workarounds. Report the error verbatim.

**Failure behavior:** Stop on first unanticipated deviation. Any attempt
to "work around" a deviation without surfacing it to the human constitutes
scope improvisation, which is forbidden by `00-IDENTITY.md`.

---

### Step 6: VALIDATION

**Purpose:** Confirm that the executed changes are correct, complete, and
do not break existing behavior. Validation is not optional. A session that
skips validation has not completed Step 6 and must not produce a SESSION CLOSE.

**Required actions (run all that apply):**

| Condition | Validation required |
|-----------|-------------------|
| Any Python file changed | `pytest backend/tests/ -x` — fail fast on first failure |
| Any Flutter file changed | `flutter analyze` — zero errors, zero warnings |
| Any Pydantic schema changed | Confirm all tests that use the schema still pass |
| Any service function changed | Run the governance tests: `pytest backend/tests/test_governance_*.py` |
| Any model file changed | Confirm no float columns introduced (governance test) |
| Any new migration added | `alembic heads` — must return exactly one revision |

**Required output:** Verbatim test/analyze output. Do not summarize.
Do not write "tests passed" without showing the output.

**Failure behavior:** If validation fails, STOP. Do not commit. Diagnose
the failure. If the failure is in a test that tests behavior changed by the
brief (i.e., the test needed updating as part of the brief), update the test
and re-run. If the failure is in an unrelated test, report it — do not
fix it silently as a side effect.

---

### Step 7: FACT_REPORT

**Purpose:** Produce a machine-readable record of what was done, for the
human to review before the session is considered closed. The FACT_REPORT
is written before SESSION CLOSE. If the human requests changes after
reading the FACT_REPORT, the agent returns to Step 5 and re-executes.

**Format:** See Section 2.

**Failure behavior:** A session without a FACT_REPORT is not closed. If
the agent cannot produce a complete FACT_REPORT (e.g., validation was
skipped), it must state which fields are incomplete and why.

---

### Step 8: SESSION CLOSE

**Purpose:** Formally close the session with a structured summary for
the human and for future agent sessions reading `.agent/STATE/state.json`.

**Format:** See Section 6.

**Failure behavior:** If any validation gate in Section 5 is not green,
SESSION CLOSE must include `VALIDATION_STATUS: FAIL` and list the specific
failures. A SESSION CLOSE with `VALIDATION_STATUS: PASS` is a claim that
all gates were checked and passed — making this claim falsely is a critical
failure.

---

## Section 2 — FACT_REPORT Contract

A FACT_REPORT is produced at Step 7 and whenever a STOP is triggered.
Every field is mandatory. There are no optional fields. If a field cannot
be populated, write `UNKNOWN — see notes` and explain in the NOTES field.

```
FACT_REPORT
═══════════════════════════════════════════════════════

BRANCH:               <current git branch name>
COMMIT:               <SHA or NONE if no commit yet>

FILES_CHANGED:
  CREATED:   [<path>, ...]   or NONE
  MODIFIED:  [<path>, ...]   or NONE
  DELETED:   [<path>, ...]   or NONE

INVARIANTS_TOUCHED:
  <INV-ID>: <one sentence — how this invariant was relevant>
  ...
  or NONE

TEST_STATUS:
  COMMAND:  <exact command run>
  RESULT:   PASS | FAIL | NOT_RUN
  OUTPUT:   <verbatim last 20 lines, or "NOT_RUN — reason">

ANALYZE_STATUS:
  COMMAND:  <exact command run>
  RESULT:   PASS | FAIL | NOT_RUN
  OUTPUT:   <verbatim last 20 lines, or "NOT_RUN — reason">

REGRESSION_STATUS:
  GOVERNANCE_TESTS: PASS | FAIL | NOT_RUN
  SCHEMA_DRIFT:     NONE | DETECTED — <description>
  FLOAT_COLUMNS:    NONE | DETECTED — <file:line>
  ALEMBIC_HEADS:    SINGLE | MULTIPLE | NOT_CHECKED

STOP_TRIGGERED:       YES — <reason>  |  NO
GAPS_FOUND:           [list]  |  NONE
NEW_TERMS_INTRODUCED: [list per Section 6 of 04-GLOSSARY.md]  |  NONE

NOTES:
  <free text for anything that does not fit above — max 5 sentences>

═══════════════════════════════════════════════════════
```

---

## Section 3 — STOP & Escalation Rules

A STOP is not an error state. It is the correct response to uncertainty.
A paused agent that surfaced a problem is infinitely more useful than an
agent that guessed and caused damage.

**STOP is mandatory — do not proceed — when any of the following is true:**

1. **Invariant risk detected.** A proposed change would require violating
   any invariant in `01-INVARIANTS.md`, or the agent cannot confirm it
   would not. The relevant invariant ID must be named in the FACT_REPORT.

2. **Schema ambiguity.** The brief references a Pydantic schema field,
   model attribute, or API endpoint that either (a) does not exist in the
   current code, or (b) exists with a different signature than expected.

3. **Missing required context.** A plan step requires reading a file or
   function that cannot be located. The missing path must be stated in the
   FACT_REPORT — not guessed at.

4. **Conflicting requirements.** The brief says X; a canonical file (any
   file in `.agent/CORE/`) says not-X. The conflict must be named
   explicitly: "Brief says A; `01-INVARIANTS.md §LED-001` requires B."

5. **Unanticipated test failure.** A test that was passing before the
   session's changes now fails, and the failure is not explained by the
   brief's stated scope. Do not fix silently.

6. **Alembic multiple heads.** Any migration work that results in
   `alembic heads` returning more than one revision must STOP immediately.
   Do not attempt to resolve the branch — report it.

7. **Plan deviation discovered during execution.** A file read during
   Step 5 reveals that the file's current state differs from what the
   plan assumed. The plan is now invalid and must be regenerated from
   Step 2.

**STOP behavior:**
1. Halt all execution immediately — do not complete the current step
2. Produce a FACT_REPORT with `STOP_TRIGGERED: YES — <reason>`
3. Write a one-paragraph plain-English explanation of what was found
   and why it blocks proceeding
4. Wait for human instruction
5. Do not retry the blocked action without explicit human authorization

---

## Section 4 — Prompt Types

Every brief delivered to an executor is one of four types. The type
determines what inputs are required, what outputs must be produced, and
what validation is mandatory.

---

### Prompt Type 1: IMPLEMENTATION

**Definition:** Adding new functionality that does not exist yet. New
service functions, new API endpoints, new models, new Flutter screens.

**Required inputs:**
- The canonical entity names involved (from `04-GLOSSARY.md`)
- The invariants that apply (from `01-INVARIANTS.md`)
- The layer that owns the new logic (from `02-ARCHITECTURE.md`)
- The exact function signature(s) to create
- The expected test coverage (new tests, or named existing tests)

**Required outputs:**
- New code at the correct layer (no cross-layer violations)
- At least one test asserting the new behavior
- Governance tests still passing after the change
- FACT_REPORT with all fields populated
- SESSION CLOSE with `CHANGES` listing every new file and function

**Validation expectations:**
- `pytest backend/tests/ -x` — PASS
- `flutter analyze` — PASS (if Flutter touched)
- `pytest backend/tests/test_governance_*.py` — PASS
- `alembic heads` — SINGLE (if migration added)

---

### Prompt Type 2: BUG FIX

**Definition:** Correcting behavior that is demonstrably wrong against a
stated expectation. The bug is the delta between current behavior and
specified behavior.

**Required inputs:**
- The exact symptom (error message, wrong value, wrong status)
- The file and function where the bug originates (confirmed by FACT DISCOVERY)
- The expected correct behavior
- The test that will assert the fix (existing or new)

**Required outputs:**
- Minimal change to correct the bug — nothing more
- A test that fails before the fix and passes after
- No other behavior changed
- FACT_REPORT with `REGRESSION_STATUS` confirming no regressions

**Validation expectations:**
- The targeted test passes after the fix
- `pytest backend/tests/ -x` — PASS (all tests, not just the targeted one)
- `flutter analyze` — PASS (if Flutter touched)
- No governance test regressions

**Constraint:** A bug fix MUST NOT include refactoring, cleanup, or
"improvements" beyond the minimal change. If cleanup is needed, surface
it in SESSION CLOSE as an out-of-scope observation for a future brief.

---

### Prompt Type 3: REFACTOR

**Definition:** Restructuring existing code without changing observable
behavior. The API contract, test assertions, and entity relationships are
unchanged before and after.

**Required inputs:**
- The specific scope of the refactor (file or function range, not "the
  service layer")
- Confirmation that no API response schema changes
- The invariant set that must remain satisfied
- Confirmation that no new functionality is introduced

**Required outputs:**
- Code that is structurally different but behaviorally identical
- All existing tests pass unchanged (no test edits)
- No new tests added (behavior is unchanged — existing tests are sufficient)
- FACT_REPORT with `REGRESSION_STATUS: NONE`

**Validation expectations:**
- `pytest backend/tests/ -x` — PASS, with no test modifications
- `flutter analyze` — PASS (if Flutter touched)
- `pytest backend/tests/test_governance_*.py` — PASS
- API schema diff: zero (confirmed by reading the schema before and after)

**Constraint:** If the refactor reveals a bug, STOP. Do not fix the bug
as part of the refactor. Surface it in SESSION CLOSE. Bug fixes and
refactors are separate briefs.

---

### Prompt Type 4: AUDIT

**Definition:** A read-only investigation of the codebase to answer a
specific question about its current state. No code is written. No files
are modified.

**Required inputs:**
- The exact question to be answered
- The scope (which files, layers, or invariants to examine)
- The format of the expected answer (table, list, yes/no with evidence)

**Required outputs:**
- A written answer with evidence (file paths and line numbers)
- A FACT_REPORT with `FILES_CHANGED: NONE` and `COMMIT: NONE`
- No code changes, no git operations

**Validation expectations:**
- No validation commands are run (nothing changed)
- The answer cites specific evidence from the code — no assertions without
  a file:line citation

**Constraint:** If an audit discovers a violation or bug, report it in
SESSION CLOSE as an observation. Do not fix it. An audit brief does not
authorize any write operation.

---

## Section 5 — Validation Gates

These gates must all be green before a session is considered complete.
A session that exits without checking applicable gates has not finished
Step 6 and must not produce a SESSION CLOSE with `VALIDATION_STATUS: PASS`.

| Gate | Applicable when | Command | Pass condition |
|------|----------------|---------|----------------|
| **Unit/integration tests** | Any Python file changed | `pytest backend/tests/ -x` | Zero failures |
| **Governance tests** | Any service, model, or schema file changed | `pytest backend/tests/test_governance_*.py -v` | Zero failures |
| **Flutter analyze** | Any Dart file changed | `flutter analyze` | Zero errors, zero warnings |
| **Alembic single head** | Any migration file added or modified | `alembic heads` | Exactly one revision printed |
| **Schema drift** | Any Pydantic schema field added, removed, or renamed | Read the schema before and after; diff field names | Zero unintended field changes |
| **Float column check** | Any SQLAlchemy model modified | `pytest backend/tests/test_governance_no_float_models.py` | PASS |
| **No raw HTTPException** | Any API router file modified | `pytest backend/tests/test_governance_error_contract.py` | PASS |

**Gate: Unit/integration tests** — run with `-x` (fail fast). If the
first failure is in a test within scope of the brief, fix it and re-run.
If it is outside scope, STOP and report.

**Gate: Governance tests** — these are structural assertions about the
codebase. They do not test feature behavior. They test invariant compliance:
no float columns, no multiple commits per function, no raw HTTPException
leaks, correct error contract. These must pass on every session that touches
Python files.

**Gate: Alembic single head** — two heads block `alembic upgrade head`
in CI and on all environments. This is a hard blocker. Do not commit a
migration that creates a second head.

---

## Section 6 — SESSION CLOSE Contract

SESSION CLOSE is the final output of every executor session. It is a
structured record for the human and for the next agent session that reads
`STATE/state.json`. No field is optional. No free-form narrative is
permitted outside the `NOTES` field.

```
SESSION CLOSE
═══════════════════════════════════════════════════════

PHASE:        <phase ID and title — e.g., G.6 COMPLETE>
BRANCH:       <git branch name>
COMMIT:       <SHA — or NONE>

CHANGES:
  CREATED:    [<path> — <one-line description>, ...]  or NONE
  MODIFIED:   [<path> — <what changed>, ...]          or NONE
  DELETED:    [<path>, ...]                            or NONE

VALIDATION_STATUS:  PASS | FAIL | PARTIAL
  TESTS:            PASS | FAIL | NOT_RUN
  ANALYZE:          PASS | FAIL | NOT_RUN
  GOVERNANCE:       PASS | FAIL | NOT_RUN
  ALEMBIC:          SINGLE | MULTIPLE | NOT_CHECKED

INVARIANTS_TOUCHED:
  <INV-ID>: <one sentence — what was confirmed or guarded>
  ...
  or NONE

RISKS:
  REGRESSION_RISK:  NONE | LOW | MEDIUM | HIGH — <reason if not NONE>
  STRUCTURAL_RISK:  NONE | LOW | MEDIUM | HIGH — <reason if not NONE>
  OPEN_QUESTIONS:   [list of unresolved items for next session]  or NONE

GAPS_SURFACED:
  [list of observations, bugs, or out-of-scope items discovered]
  or NONE

NEW_TERMS_INTRODUCED:
  [list — each new canonical term added, per 04-GLOSSARY.md §6]
  or NONE

NEXT_PHASE:   <phase ID and title>  |  AWAITING_HUMAN_DECISION

NOTES:
  <free text — max 5 sentences — for anything not captured above>

═══════════════════════════════════════════════════════
```

**Rules for SESSION CLOSE:**

1. `VALIDATION_STATUS: PASS` is a binding claim. Writing it means every
   applicable gate in Section 5 was run and passed. Writing it when gates
   were skipped is a critical failure.

2. `VALIDATION_STATUS: PARTIAL` is used when some gates are not applicable
   (e.g., no Flutter files changed) — the non-applicable gates are marked
   `NOT_RUN` with a reason.

3. `RISKS` must be honest. If a change touches a critical path (as defined
   in `03-SYSTEM_MAP.md §6`), the risk is at least LOW unless specific
   mitigations are stated.

4. `GAPS_SURFACED` is for observations discovered during the session that
   are outside the brief's scope. These are not failures — they are
   intelligence for future briefs. Do not silently discard them.

5. `NEXT_PHASE` is either the next phase ID (if known) or
   `AWAITING_HUMAN_DECISION` (if the human must decide the next step).

---

## Section 7 — Agent Behavior Rules

These rules govern agent behavior across all sessions. They are not
context-dependent. They apply to every step of every session.

---

### Rule 1: No Guessing

If a fact is not confirmed by a file read in the current session, it is
not known. It cannot be assumed from prior sessions, from summary text,
or from "what seems likely."

- ❌ "The function probably takes a `db` argument."
- ✅ Read the function. Confirm the signature. Then state it.

This rule applies to file paths, function names, field names, status
values, line numbers, and test names. Every claim must be backed by a
file:line citation from the current session.

---

### Rule 2: No Partial Execution

A plan step is either complete or not started. There is no "partially
done" state. If a step is blocked, the agent STOPs and reports. It does
not complete half the step and move on.

- ❌ Commit a file with a `TODO: implement this` block
- ❌ Skip a plan step because "it seems optional"
- ✅ If a step is blocked, STOP and report the blocker verbatim

---

### Rule 3: No Skipping Validation

Validation gates exist because they catch real failures. "It looks right"
is not a substitute for running the test. "Nothing critical changed" is
not a reason to skip `flutter analyze`.

- ❌ "I'm confident the tests pass — moving to SESSION CLOSE."
- ✅ Run the applicable commands. Show the output. Then move to SESSION CLOSE.

The only legitimate reason to mark a gate `NOT_RUN` is that it is not
applicable (e.g., no Dart files were changed, so `flutter analyze` is
not applicable). In this case, state the reason.

---

### Rule 4: No Silent Failure

If anything goes wrong — a command fails, a file is not found, a test
breaks, a function has an unexpected signature — it must be reported
immediately. Do not suppress the error, work around it without mention,
or continue as if it did not happen.

- ❌ Try an alternate approach when the first fails, without reporting the
  first failure
- ✅ Report the first failure verbatim, including the full error output,
  then state the alternate approach explicitly and ask for authorization
  if it deviates from the plan

---

### Rule 5: Always Respect Invariants

The invariants in `01-INVARIANTS.md` are not advisory. They encode bugs
that have already happened. Violating them — even for a "simple" change,
even when the brief seems to require it — is wrong.

When an invariant conflicts with a brief, the invariant wins and the
conflict is escalated to the human. This is not the agent's failure — it
is the correct outcome. The human wrote both the brief and the invariants.
They need to know the conflict exists.

- ❌ "The brief says to update batch.quantity directly, which seems fine
  for this case."
- ✅ "The brief says to update `batch.quantity` directly. LED-001 requires
  this to happen via `create_inventory_txn` in the same transaction.
  STOP — conflict requires human resolution."

---

### Rule 6: Scope is Exactly What the Brief States

The brief defines the scope. Not the agent's judgment of what "should"
also be done. Not adjacent cleanup. Not opportunistic improvements.

If the agent discovers that something outside scope needs to be done, it
surfaces it in SESSION CLOSE under `GAPS_SURFACED`. It does not do it.

- ❌ "While I was in `dispatch_entry.py`, I also cleaned up the error
  handling."
- ✅ The change is exactly what the brief specified. Any observation about
  the error handling is in `GAPS_SURFACED`.

---

### Rule 7: Mode is Fixed for the Session

An agent session is either Planner mode or Executor mode
(see `00-IDENTITY.md §1`). It does not switch mid-session.

- A **Planner** does not write code, run commands, or make git operations.
  It produces briefs and reviews executor output.
- An **Executor** does not design, expand scope, or make architectural
  decisions. It reads briefs and executes mechanical work.

If the session starts as Executor mode and the agent realizes a design
decision is needed, it STOPs and asks the Planner (the human). It does
not make the decision unilaterally.

---

## Footer

**This file covers:** the 8-step execution pipeline, FACT_REPORT format,
STOP conditions and escalation behavior, 4 prompt types with their
validation contracts, validation gates, SESSION CLOSE format, and 7
agent behavior rules.

**What it does not cover:** invariant text (see `01-INVARIANTS.md`),
layer rules (see `02-ARCHITECTURE.md`), entity definitions (see
`03-SYSTEM_MAP.md`), canonical terms (see `04-GLOSSARY.md`).

**This is the last file in `.agent/CORE/`.** Reading all five files
(00 through 05) is the prerequisite for any executor session. If any
file was skipped, return to it before proceeding.
