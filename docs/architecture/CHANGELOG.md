# Architecture & Governance Changelog

This document tracks major architectural phases and governance locks.

## 2026-01-29: Item Archival (Phase C + C.1)
**Status**: LOCKED

- **Feature**: Replaced destructive Item deletion with `ACTIVE` / `INACTIVE` lifecycle.
- **Rule**: `DELETE /item/{id}` is strictly blocked (405).
- **Rule**: Inactive items are hidden by default and require explicit opt-in to view.
- **Artifacts**:
    - `docs/governance/ITEM_LIFECYCLE.md` (Created)
    - `mobile/docs/ui/ITEM_UX_CANON.md` (Updated)

---
