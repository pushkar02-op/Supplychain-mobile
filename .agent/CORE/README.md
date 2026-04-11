# .agent/CORE/ — Core Governance Documents

This directory holds the canonical governance documents for the AGRO
repository. It is the single source of truth for invariants, operating
mode, and agent identity.

## Status
EMPTY — populated in Phase G of the repository cleanup.

## Expected Contents (from .agent/DESIGN_LOCKED.md)
- `00-IDENTITY.md` — What agents operating on this repo are, what they
  must and must not do
- `01-INVARIANTS.md` — The hard rules that must not be violated (ledger
  integrity, decimal purity, immutable events, etc.)
- `02-ARCHITECTURE.md` — Current system topology (backend + mobile)
- `03-GLOSSARY.md` — Terms and their definitions
- `04-OPERATING-MODE.md` — The planner/executor loop, git discipline,
  doc-in-loop rules

## How to Use
When operating as an agent on this repo, read every file in this
directory before taking any action. These documents override any
older rules in `.agent/legacy/`.
