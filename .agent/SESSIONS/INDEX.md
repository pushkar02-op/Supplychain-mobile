# .agent/SESSIONS/ — Session Log Index

This directory holds append-only logs of agent sessions. Each session
produces one file named `NNNN-phase-X-description.md` where NNNN is
a zero-padded sequence number.

## Status
ACTIVE — transitional. Reports from Phases A through E.1 are stored
here but not yet in the final session format. Phase G will establish
the canonical session file format and update this index.

## Current Contents
- `phase-a-tracked-ignored-report.txt` — Phase A tracked-but-ignored report
- `phase-e1-branch-classification.txt` — Phase E.1 branch classification

## Future Format
Starting from Phase G, sessions will follow the format defined in
`.agent/DESIGN_LOCKED.md` (section on Session memory layer).
