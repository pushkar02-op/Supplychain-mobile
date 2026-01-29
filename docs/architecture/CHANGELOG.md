# Architecture & Governance Changelog

This document tracks major architectural phases and governance locks.

## 2026-01-29: Item Archival (Phase C + C.1)
**Status**: LOCKED

## 🔒 BASELINE — ITEM SYSTEM (LOCKED)

This baseline includes:
- Item UX Refactor (UX-1 → UX-6)
- Item Lifecycle & Archival (Phase C)
- Inactive Visibility Bugfix (Phase C.1)
- Alias Intelligence (Phase 2A)
- Forecasting Backend + UI Integration
- UI Canon, Migration Playbook, Governance Docs

**Statement**: "All work listed above is considered IMMUTABLE HISTORY. No refactoring, re-splitting, or behavioral change is permitted without explicit governance approval."

- **Feature**: Replaced destructive Item deletion with `ACTIVE` / `INACTIVE` lifecycle.
- **Rule**: `DELETE /item/{id}` is strictly blocked (405).
- **Rule**: Inactive items are hidden by default and require explicit opt-in to view.
- **Artifacts**:
    - `docs/governance/ITEM_LIFECYCLE.md` (Created)
    - `mobile/docs/ui/ITEM_UX_CANON.md` (Updated)

---
