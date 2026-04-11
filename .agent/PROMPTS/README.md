# .agent/PROMPTS/ — Reusable Prompt Templates

Templates for the recurring prompts in the planner/executor loop.

## Status
EMPTY — populated in Phase G.

## Expected Contents (from .agent/DESIGN_LOCKED.md)
- `planner-bootstrap.md` — What to paste into a new planner session
- `executor-bootstrap.md` — What to paste into a new executor session
- `context-fetch.md` — Template for requesting facts from the repo
- `executor-brief.md` — The standard executor brief template
- `plan-delta.md` — Template for communicating plan changes
- `session-close.md` — SESSION CLOSE output template
- `review-verdict.md` — Planner review verdict template

## How to Use
When starting a new planner or executor session, paste the matching
bootstrap prompt to establish the operating mode.
