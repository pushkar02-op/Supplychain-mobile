# .agent/STATE/ — Repo State Tracking

Machine-readable state about the current phase, active branches, open
threads, and subsystem health.

## Status
EMPTY — populated in Phase G.

## Expected Contents
- `state.json` — Structured state per the design doc schema
- `open-threads.md` — In-progress work not yet closed
- `risks.md` — Known risks and hot spots

## How to Use
Agents read `state.json` at session start to understand current repo
state. It is updated by close-session.sh at the end of each session.
