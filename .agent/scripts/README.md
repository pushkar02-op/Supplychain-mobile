# .agent/scripts/ — Governance Automation Scripts

Scripts that enforce the agent governance loop. Humans run these;
agents do NOT run git commands directly.

## Status
EMPTY — populated in Phase G.

## Expected Contents (from .agent/DESIGN_LOCKED.md)
- `bootstrap-planner.sh` — Start a new planner session
- `bootstrap-executor.sh` — Start a new executor session
- `close-session.sh` — Validate SESSION CLOSE, commit, and push
- `update-state.py` — Apply a state delta to `STATE/state.json`
- `git-safe.sh` — Read-only git commands whitelisted for agents

## How to Use
These scripts are called by the human at specific points in the
workflow (session start, session close). They are not called by
agents directly.
