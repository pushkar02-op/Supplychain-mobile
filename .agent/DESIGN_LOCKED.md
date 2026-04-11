
# AGRO — AGENT GOVERNANCE & DEVELOPMENT LOOP
## LOCKED DESIGN DOCUMENT v1.0

**Status:** Finalized, pending cleanup prerequisite
**Last updated in chat:** Before cleanup phase
**Purpose:** Single source of truth for the agent governance system design.
**Rule:** When resuming, this document supersedes any partial recollection. If the chat contradicts this file, this file wins.

---

## PART A — THE CORE PROBLEM WE ARE SOLVING

Pushkar operates as a **human message bus** between two classes of AI:

- **Planners** — chat sessions (Claude, ChatGPT) that act as program manager, architect, reviewer
- **Executors** — coding agents (Claude Code, Codex, Google Antigravity) that read/write the repo

The code can only be changed by executors. The planner can only learn about the repo from executor output. Pushkar copy-pastes between them and provides judgment.

The failure mode we are fixing: **context decay across sessions and agents.** Every new chat starts fresh, forgets prior decisions, invents its own structure, and produces drift — contradictory docs, stale tests, inconsistent processes, no git discipline.

Previous attempts (custom GPTs, Claude projects with instructions) failed because the *memory lived inside the chat*, which is exactly what keeps forgetting.

**The core principle that makes the new system work:**
> Neither the planner nor the executor is allowed to remember anything between sessions. The `.agent/` folder in the repo is the memory. Pushkar is the bus that moves state between the agents and the folder. Every session is rehydrated from files at the start and flushed back to files at the end.

---

## PART B — MENTAL MODEL

```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐
│   PLANNER   │◄─────►│   PUSHKAR    │◄─────►│  EXECUTOR   │
│ (Claude/GPT │       │ (bus+judge)  │       │ (CC/Codex/  │
│  chat)      │       │              │       │  Antigrav)  │
└──────┬──────┘       └──────┬───────┘       └──────┬──────┘
       │                     │                      │
       └─────────────────────┴──────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │  .agent/ folder  │  ← shared memory
                   │  (git-tracked)   │     single source of truth
                   └──────────────────┘
```

**Pushkar's role shifts from "process enforcer + memory holder + format validator" to "judgment layer."** The scripts and templates carry the process. The files carry the memory.

---

## PART C — TWO LAYERS OF MEMORY (MUST BE SEPARATED)

| Layer | Name | Stores | Written by | Lifetime |
|---|---|---|---|---|
| **L1** | **Project Memory** | Invariants, architecture, decisions, current state | Planner (via approval) + scripts | Permanent |
| **L2** | **Session Memory** | What one executor run did | Executor (auto-generated) | Append-only, only recent are "hot" |

The mistake to avoid: **never mix these.** Invariants do not live in the same file as "fixed a null bug on Tuesday." The old instruction document mixed them, which is why it kept drifting.

---

## PART D — FILE SYSTEM DESIGN (FINAL)

```
.agent/
├── CORE/                         ← L1 — rarely changes, planner reads ALL
│   ├── 00-IDENTITY.md            ← Project one-pager
│   ├── 01-INVARIANTS.md          ← Locked rules (the 8 core principles + business rules)
│   ├── 02-ARCHITECTURE.md        ← Ledger flow, entities, subsystems
│   ├── 03-GLOSSARY.md            ← Domain terms
│   └── 04-OPERATING-MODE.md      ← Planner + executor behavior rules
│
├── STATE/                        ← L1 — updated every session, machine-readable
│   ├── state.json                ← Current snapshot (see Part E)
│   ├── open-threads.md           ← In-flight work / unresolved questions
│   └── risks.md                  ← Known issues, tech debt
│
├── DECISIONS/                    ← L1 — append-only, immutable
│   ├── INDEX.md
│   ├── ADR-0001-ledger-first.md
│   └── ADR-XXXX-*.md
│
├── SESSIONS/                     ← L2 — append-only, one file per executor run
│   ├── INDEX.md                  ← Auto-maintained TOC
│   └── YYYY-MM-DD-HHMM-slug.md
│
├── PROMPTS/                      ← Reusable templates (the format contracts)
│   ├── planner-bootstrap.md      ← Paste into new planner chat
│   ├── executor-bootstrap.md     ← Paste into new executor agent
│   ├── context-fetch.md          ← Planner → executor read-only fetch request
│   ├── executor-brief.md         ← Planner → executor implementation brief
│   ├── plan-delta.md             ← Planner corrections to executor plan
│   ├── session-close.md          ← Executor's required output format
│   └── review-verdict.md         ← Planner's approval format
│
├── ARCHIVE/                      ← Old session artifacts from cleanup (if any)
│
└── scripts/
    ├── bootstrap-planner.sh      ← Produces clipboard blob for planner chat
    ├── bootstrap-executor.sh     ← Produces clipboard blob for executor
    ├── context-fetch.sh          ← Executor-side read-only repo snapshot
    ├── close-session.sh          ← The automation payoff (see Part H)
    ├── update-state.py           ← Validates & updates state.json
    └── git-safe.sh               ← Read-only git wrapper for agents

docs/                             ← HUMAN docs only (product, API, runbooks, setup)
├── product/
├── api/
├── runbooks/
└── status.md                     ← Auto-generated from state.json

CLAUDE.md                         ← Symlink → .agent/CORE/00-IDENTITY.md
AGENTS.md                         ← Symlink → .agent/CORE/00-IDENTITY.md
.cursorrules                      ← Pointer to .agent/CORE/*
README.md                         ← Tiny living index (not a living doc)
CHANGELOG.md                      ← Human-readable, updated per session
```

**Key rule:** `docs/` is for humans. `.agent/` is for AI agents. They must never mix. This alone prevents ~70% of the "docs scattered everywhere" problem.

---

## PART E — THE HEART: `state.json`

The one file that makes automation possible. Small, diff-friendly, parseable.

```json
{
  "schema_version": 2,
  "updated_at": "ISO-8601 timestamp",
  "updated_by_session": "session-file-slug",
  "phase": "UAT_PREPARATION",
  "current_focus": "free-text description",
  "active_branches": [
    { "name": "feature/x", "agent": "claude-code", "status": "in-progress" }
  ],
  "subsystems": {
    "dispatch":       { "status": "stable|ux_transition|refactor|broken", "invariants_ok": true },
    "inventory":      { "status": "stable", "invariants_ok": true },
    "mart_invoice":   { "status": "stable", "invariants_ok": true },
    "audit":          { "status": "stable", "invariants_ok": true }
  },
  "open_threads": ["..."],
  "recent_sessions": [".agent/SESSIONS/..."],
  "last_planner_digest": "ISO-8601",
  "next_actions": ["..."]
}
```

Validated by schema in CI. Updated automatically by `close-session.sh` from the SESSION CLOSE block's State Delta section.

---

## PART F — THE WORKFLOW (FINAL, 10 STEPS)

This is Pushkar's explicitly-designed workflow, refined with all the gaps filled:

```
[0] BOOTSTRAP PLANNER
    Run: ./bootstrap-planner.sh | <clipboard>
    Paste into new Claude/GPT chat
    Blob contains: CORE/*, STATE/*, last 3 SESSIONS, all PROMPTS/*

[1] DESIGN
    Describe the feature to planner
    Planner has full context from the paste

[2] CONTEXT FETCH (if planner needs current code)
    Planner emits a CONTEXT FETCH REQUEST as a single copy-pasteable code block
    Rule: planner-bootstrap.md forces this to be one block with no prose inside
    Paste into executor → executor runs read-only commands → paste output back to planner

[3] PLAN DESIGN
    Planner produces implementation plan
    Plan includes: code changes + doc updates + validation strategy + risks
    Pushkar iterates with planner until finalized

[4] EXECUTOR BRIEF
    Planner emits EXECUTOR BRIEF in strict template (PROMPTS/executor-brief.md)
    Must include:
      - Scope (files expected to change)
      - Out of scope (explicit)
      - Invariants to respect
      - Mode: plan-first | direct
      - Required doc updates
      - Required lint/test commands
      - SESSION CLOSE template (inline)
    Paste to executor

[5] PLAN VERIFY (if Mode=plan-first)
    Executor emits plan, STOPS, waits
    Paste plan to planner
    Planner emits APPROVAL or PLAN DELTA (strict format)
    Loop until approved

[6] EXECUTE
    Executor:
      - Writes code
      - Updates docs in same session (per brief)
      - Runs linters (ruff, flutter analyze)
      - Fixes lint errors
      - Runs tests (pytest, flutter test)
      - Fixes test failures
      - Emits SESSION CLOSE block
    Executor does NOT touch git (no commit, push, merge, rebase, force push)

[7] REVIEW
    Paste SESSION CLOSE to planner
    Planner verifies: scope, invariants, docs updated, validation passed, state delta valid
    Planner emits REVIEW VERDICT (APPROVED / REJECTED / APPROVED_WITH_FOLLOWUP)

[8] CLOSE
    Run: ./close-session.sh
    Script does everything (see Part H)
    Only command Pushkar runs at close time

[9] PR
    Pushkar (human) opens PR on GitHub, reviews, merges
    Never automated — merge is the one decision that must remain human
```

**Manual actions per cycle:** bootstrap paste, feature description, (optional) context paste-pair, plan review, brief paste, (optional) plan verify paste-pair, session close paste, review paste, `./close-session.sh`, `git push`, open PR.

**Things Pushkar must remember:** zero. The templates carry the process.

---

## PART G — THE SPLIT: AGENT vs SCRIPT

Critical design decision. Agents are good at judgment (fixing lint errors, debugging tests). Scripts are good at ritual (commit messages, git safety). Split accordingly:

### AGENT RESPONSIBILITIES (inside the work loop)
- Write code
- Run linter (ruff, flutter analyze)
- Fix linting errors
- Run tests (pytest, flutter test)
- Fix test failures
- Update docs in the same session
- Emit SESSION CLOSE block with validation results
- **Does NOT commit, push, merge, rebase, force push, or touch branches**

### SCRIPT RESPONSIBILITIES (close-session.sh)
- Validates SESSION CLOSE block against template
- Writes session file to `.agent/SESSIONS/`
- Updates `state.json` from State Delta
- Updates `open-threads.md`, `SESSIONS/INDEX.md`
- Updates `CHANGELOG.md` with human-readable line
- Re-runs validation locally (trust but verify)
- Stages files (whitelist only)
- Generates commit message from session metadata
- Commits and pushes feature branch
- **Refuses to: merge, rebase, force push, commit on protected branches, commit without changes, commit on failed validation**

This split **structurally enforces Section 7 git governance** (never force push, never rebase shared branches, never merge locally). No agent can violate it because no agent touches git. Belt and suspenders: `git-safe.sh` whitelists only `status|log|diff|show|branch|rev-parse|ls-files` for agents during context fetch.

---

## PART H — WHAT `close-session.sh` DOES (PSEUDOCODE)

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Read SESSION CLOSE block from clipboard or $1
# 2. Validate format against PROMPTS/session-close.md schema
# 3. Parse Status field

if status in [FAILED, BLOCKED]:
    write_session_file(status=partial)
    update_open_threads()
    # No commit, no push, but session is recorded
    exit 0

# 4. Safety: refuse if on develop/main
if current_branch in [develop, main]:
    refuse

# 5. Safety: refuse if no changes
if git_tree_clean:
    refuse

# 6. Re-run validation locally (trust but verify)
run_linters_and_tests or refuse

# 7. Write session file to .agent/SESSIONS/YYYY-MM-DD-HHMM-slug.md
# 8. Apply State Delta → update .agent/STATE/state.json
# 9. Update CHANGELOG.md [Unreleased] section
# 10. Regenerate SESSIONS/INDEX.md
# 11. Stage whitelisted paths only: .agent/, docs/, CHANGELOG.md, README.md, backend/, mobile/, infra/
# 12. Generate commit message from session metadata:
#     feat(subsystem): one-line summary
#
#     Session: YYYY-MM-DD-HHMM-slug
#     Invariants: INV-X, INV-Y
#     Branch: feature/x
# 13. git commit
# 14. git push origin <current_branch>
# 15. Print next-step hint (PR URL)
```

**Refuses to:** commit on `develop`/`main`, force push, rebase, merge, push to wrong branch, commit if validation fails, commit if no changes.

---

## PART I — DOCS IN THE LOOP (THREE TIERS)

| Tier | Location | Updated by | When |
|---|---|---|---|
| **Agent memory** | `.agent/` | Scripts + executor | Every session (auto) |
| **Living human docs** | `docs/`, `README.md`, `CHANGELOG.md` | Executor (instructed by brief) | When session changes something user-visible |
| **Reference docs** | `docs/api/`, `docs/runbooks/` | Executor (instructed by brief) | When contracts/procedures change |

**Key rule:** docs are updated **in the same session as the code**, not as follow-up. The executor brief has a mandatory `## Documentation impact` section. The SESSION CLOSE has a mandatory `## Documentation updated` section. The REVIEW VERDICT checks doc updates. Sessions that skip required docs are REJECTED.

**README strategy:** Keep `README.md` tiny — just an index pointing to:
- `docs/setup.md` for quickstart
- `docs/architecture.md` for architecture
- `.agent/CORE/00-IDENTITY.md` for agents
- `.agent/STATE/state.json` for machine status
- `docs/status.md` for human status
- `CHANGELOG.md` for history

A README like this barely ever needs updating. The real docs live in `docs/` with single clear topic ownership.

**Auto-generated docs:** Anything that can be generated should be:
- API reference → generated from FastAPI OpenAPI → `docs/api/openapi.md`
- Changelog entries → appended by `close-session.sh`
- Project status → generated from `state.json` → `docs/status.md`

**CI structure guards:**
- If `backend/app/api/` changed but `docs/api/` didn't → fail
- If migration added but no CHANGELOG entry → fail
- If code changed but no session file added → fail
- If stray `.md` files outside allowed paths → fail

---

## PART J — THE 8 GAPS PUSHKAR'S ORIGINAL WORKFLOW NEEDED (ALL FIXED)

1. **No explicit bootstrap step** → Fixed: Step 0 is always `bootstrap-planner.sh`. Non-negotiable.
2. **No format contract between planner and executor** → Fixed: Five templates in `PROMPTS/`, part of every bootstrap paste.
3. **No state delta mechanism** → Fixed: Mandatory `## State Delta` section in SESSION CLOSE, applied by close script.
4. **No scope guard** → Fixed: Explicit `## Out of scope` section in executor brief, verified in review.
5. **No handling for failed sessions** → Fixed: SESSION CLOSE has `Status: SUCCESS | PARTIAL | FAILED | BLOCKED`. Close script records failure without commit; adds to open-threads.
6. **No multi-session feature handoff** → Fixed: Brief includes `Parent session:` field, linked in SESSIONS/INDEX.
7. **No staleness detection mid-chat** → Fixed: planner-bootstrap.md rule: before emitting any brief, re-state phase/branch/top 3 invariants. If can't, re-bootstrap.
8. **Manual, forgettable git commits** → Fixed: close-session.sh handles everything. Optional pre-push hook refuses if most recent commit touched code without session file.

---

## PART K — THE TEMPLATE CONTRACTS (SCHEMAS)

### `PROMPTS/planner-bootstrap.md`
Tells the planner:
- You have no memory. Everything you need is in this paste.
- If you lack current code context, emit a CONTEXT FETCH REQUEST as one code block.
- Before emitting any EXECUTOR BRIEF, re-state current phase, branch, top 3 invariants.
- Use the templates in this paste verbatim. Do not invent formats.
- Your role: design, plan, review. Never implement.

### `PROMPTS/context-fetch.md`
Format for planner → executor read-only fetch:
```
## CONTEXT FETCH REQUEST
Session goal: <what we're planning>
Please run and paste full output. Read-only. No modifications.

<numbered shell commands>

Do not modify anything. Do not commit. Do not create files.
```

### `PROMPTS/executor-brief.md`
Mandatory fields:
- Session ID, Branch, Agent target, Mode (plan-first | direct), Parent session
- Invariants to respect
- Scope (files expected)
- Out of scope (explicit refuse list)
- Task (detailed)
- Documentation impact (which docs must update)
- Required pre-close validation (lint + test commands)
- SESSION CLOSE template (inline)

### `PROMPTS/plan-delta.md`
Format for planner correcting executor plan:
```
## PLAN DELTA
Approved sections: 1, 2, 4
Changes required:
  Section 3: replace X with Y because <reason>
  Section 5: add Z
Re-submit plan with these changes.
```

### `PROMPTS/session-close.md`
Mandatory fields the executor must fill:
- Session ID, Agent, Branch, Commit (not yet committed at this point), Parent session
- Context Loaded (which files read)
- FACT_REPORT
- Changes (files modified)
- Documentation updated (per brief's doc impact)
- Invariants Touched
- Validation (lint + test results)
- State Delta (JSON-ish, applied by script)
- Status: SUCCESS | PARTIAL | FAILED | BLOCKED
- Handoff Notes

### `PROMPTS/review-verdict.md`
Planner's output format:
```
## REVIEW VERDICT
Status: APPROVED | REJECTED | APPROVED_WITH_FOLLOWUP
Scope adherence: ✓ / ✗
Invariants: ✓ / ✗
Documentation: ✓ / ✗
Validation: ✓ / ✗
State delta: valid / invalid
Follow-ups: <list or none>
Proceed to CLOSE: yes | no
```

---

## PART L — CROSS-TOOL COMPATIBILITY

One source, many pointers:

| Tool | File it reads | Solution |
|---|---|---|
| Claude Code | `CLAUDE.md` | Symlink → `.agent/CORE/00-IDENTITY.md` (which links to rest) |
| Cursor | `.cursorrules` | Pointer |
| Aider | `CONVENTIONS.md` | Symlink |
| Codex / ChatGPT | — | Paste via `bootstrap-planner.sh` or `bootstrap-executor.sh` |
| Antigravity | project instructions | Paste via bootstrap script |
| Generic `AGENTS.md` convention | `AGENTS.md` | Symlink |

For chat-only tools with no repo access: `bootstrap-planner.sh` produces a clipboard blob that works in any chat box.

**Custom GPT strategy:** instead of baking instructions into the GPT, configure it to refuse to act without a fresh context paste:
> "Wait for the user to paste a context blob starting with `## AGENT BOOTSTRAP v2`. Do not proceed without it."

This makes drift impossible — the GPT structurally can't operate on stale memory.

---

## PART M — PHASED IMPLEMENTATION ROADMAP

The correct order, as agreed:

```
PHASE 0 — DISCOVERY          ← Map current repo state (factual, read-only)
PHASE 1 — AUDIT & TRIAGE     ← Classify all files: keep/fix/archive/delete
PHASE 2 — CLEANUP EXECUTION  ← Execute cleanup via controlled agent sessions
PHASE 3 — BASELINE LOCK      ← Snapshot cleaned repo; generate CORE/ from reality
PHASE 4 — PROCESS INSTALL    ← Install .agent/ scripts, templates, CI guards
PHASE 5 — FIRST REAL FEATURE ← Dogfood the loop on something small
```

**We are currently between Phase 0 (partially complete — discovery output received) and Phase 1 (audit & triage, not yet done).**

Phase 0 revealed (summary of facts, not analysis — analysis happens in Phase 1):
- Branch `develop`, clean git state NOT achieved — ~450 modified files showing (likely whitespace/EOL from WSL mount)
- Backend: FastAPI, ~40 services, ~35 API modules, ~75 tests, ~55 alembic migrations
- Mobile: Flutter 3.7+, ~16 repositories, ~17 providers, ~35 screens, ~30 models
- Docs: ~50 markdown files across `docs/`, root, `backend/`, `mobile/docs/`, `.agent/rules`, `.agent/skills`, `.agent/workflows`
- Root directory pollution: dozens of loose `.txt` files (ruff_out.txt, pytest_out.txt, status.txt, test_output_*.txt, map files), standalone `.py` scripts (check_models.py, fetch_orders_trace.py, read_logs.py, extract_schemas.py), `task.md`, `walkthrough.md`
- Branches: 80+ local + remote branches, many stale (`arch/*`, `feature/r1-*` through `r8-*`, `baseline/recovery`, `backup/pre-repair-*`, `claude/*`)
- Existing `.agent/` folder exists but only contains `rules/`, `skills/`, `workflows/` subdirs (not our design)
- Existing governance docs: `docs/governance/AGENT_EXECUTION_PROTOCOL.md`, `AGENT_START_PROMPT.md`, many phase docs suggesting prior governance attempts
- Backend/mobile doc split already exists: `docs/backend/`, `mobile/docs/ui/`
- CI workflows exist: `agent_execution_gate.yml`, `backend.yml`, `ci.yml`, `ec2-deploy.yml`, `mobile-ci.yml`
- Pre-commit config exists
- `.copilot`, `.claude`, `.vscode` dirs exist
- 2.3 GB total, 1.4 GB is `mobile/` (mostly build artifacts)

**Phase 1 has NOT started.** When we resume, the next action is: produce the Doc Conflict Report, Test Trust Report, Code Dead Zone Report, and Cleanup Plan based on Phase 0 output.

---

## PART N — CLEANUP PLAN STRUCTURE (TO BE FILLED IN PHASE 1)

Phase 1 will produce:

1. **Verified Repo Map** — actual structure, file counts, by subsystem
2. **Doc Conflict Report** — every `.md` classified as: Canonical / Stale / Duplicate / Orphan / Session artifact / Uncertain
3. **Test Trust Report** — static assessment of whether each test file matches current code
4. **Code Dead Zone Report** — files with no imports referencing them, likely dead
5. **Branch Hygiene Plan** — which branches to delete, archive, keep
6. **Root Directory Cleanup** — what loose files to delete, archive, or move
7. **Cleanup Plan in Phases**:
   - Phase A: Kill obvious garbage (low risk, reversible)
   - Phase B: Consolidate conflicting docs (needs Pushkar's input)
   - Phase C: Archive session artifacts to `.agent/ARCHIVE/`
   - Phase D: Test triage
   - Phase E: Code dead zones
   - Phase F: Branch cleanup
8. **Baseline Truth Generation** — after cleanup, regenerate `.agent/CORE/` from actual code, not from Sections 1–28 of the old instruction doc

---

## PART O — THINGS TO NOT AUTOMATE (YET OR EVER)

- **PR merge** — always human judgment
- **Auto-merge on green CI** — never
- **AI review of PR itself** — redundant; planner already reviewed SESSION CLOSE
- **Semantic versioning automation** — wait until versioned releases exist
- **Vector stores / custom memory DBs** — files in git are enough until proven insufficient
- **Auto-PR creation vi

---


## PART P — THE ONE RULE THAT MAKES IT WORK

> Neither the planner nor the executor is allowed to claim knowledge of project state that isn't in the most recent paste. If a chat says "as we discussed earlier" and that discussion isn't in `.agent/`, Pushkar stops it and forces a re-bootstrap.

Everything else — the folder layout, the scripts, the templates, the CI guards — is in service of this one rule.

---

## PART Q — OPEN DECISIONS (NOT YET MADE, FOR PHASE 1+)

These were deliberately deferred until cleanup reveals ground truth:

1. Whether to preserve the existing `.agent/rules`, `.agent/skills`, `.agent/workflows` subdirs, archive them, or merge into the new design
2. Whether existing `docs/governance/AGENT_*` files are useful context or legacy drift
3. Whether to keep `docs/phases/` and `docs/remediations/` as historical record or archive
4. Whether the ~80 git branches should be deleted after confirming merge status, or kept as backup
5. Whether the ~450 "modified" files in git status are real edits or WSL CRLF/EOL artifacts (must be verified first)
6. Exact commit message convention for close-session.sh (conventional commits vs custom format)
7. Whether to add a `git worktree` workflow for parallel agent work or keep single-branch-at-a-time

---

## PART R — WHEN RESUMING

When this document is pasted back into a new chat:

1. Read it completely before doing anything else
2. Confirm: "Design v1.0 loaded. Ready to resume at Phase 1 (audit & triage)."
3. Ask Pushkar whether cleanup Phase 0 discovery output is available again, or whether to re-run discovery
4. Proceed to Phase 1 analysis: Doc Conflict Report, Test Trust Report, Code Dead Zone Report, Cleanup Plan
5. Do NOT redesign anything in this document. If something feels wrong, flag it explicitly and ask before changing
6. Do NOT start implementing `.agent/` folder until cleanup is complete (Phase 3)

---

## END OF LOCKED DESIGN v1.0

---

# What to Do Now

1. **Save the document above** as `.agent/DESIGN_LOCKED.md` (or any name you prefer — just remember it)
2. **Optionally** save this entire chat as backup (export Claude conversation)
3. **Start a new clean chat** when ready to resume cleanup, and paste the document as the first message
4. Say: *"Design v1.0 is loaded. Resume at Phase 1 (audit & triage). Here is the Phase 0 discovery output: [paste]"*

The new chat will have everything needed to continue without losing a single design decision.

---
