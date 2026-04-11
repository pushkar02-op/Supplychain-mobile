# .agent/legacy/ — Pre-Phase-F Preserved Content

This directory holds the agent governance content that existed before
Phase F of the AGRO repository cleanup. Everything here was moved
verbatim (via `git mv`, history preserved) from the old `.agent/`
structure.

## Why This Exists
The new governance system defined in `.agent/DESIGN_LOCKED.md` uses
a different directory structure with `.agent/CORE/`, `.agent/STATE/`,
`.agent/DECISIONS/`, `.agent/PROMPTS/`, etc. Rather than deleting the
old rules, skills, and workflows, they were preserved here so:

1. The institutional knowledge encoded in each skill is not lost
2. The new CORE documents can reference these as source material
3. Agents operating during the transition period can still read them
4. Phase G (governance installation) can cite specific legacy skills
   when writing the new CORE/01-INVARIANTS.md

## Contents
- `rules/` — documentation enforcement rule, skill invocation protocol
- `skills/` — 14 skill definitions covering inventory invariants,
  decimal purity, immutable events, pagination, testing, etc.
- `workflows/` — the old agent boot sequence

## Status
These files are READ-ONLY reference material. Do not edit them. The
new canonical rules live in `.agent/CORE/`. When Phase G produces
`CORE/01-INVARIANTS.md`, it will consolidate the wisdom from these
skills into the new format, and this directory becomes purely
historical reference.

## Future Deletion
Once Phase G is complete and `CORE/` is populated with canonical
content, this `legacy/` directory can be removed in a future cleanup
if no ongoing references exist. Until then, keep it.

## Notes on Specific Files
`skills/playwright-cli/` was flagged as potentially orphaned during
Phase F — the TypeScript CLI tool does not appear to be referenced
outside its own directory. Review before deleting.
