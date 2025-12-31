# 🐛 Pull Request: Bug Fix

## 1. Governance Safety Check
- [ ] **Type:** This is a strictly corrective fix. It does NOT change intended business logic.
- [ ] **Freeze:** This change helps, not hurts, the constraints in `docs/core_freeze_declaration.md`.
- [ ] **Documentation:** If the "Bug" was actually "Undocumented Behavior", I have updated `docs/` first.

## 2. The Problem
*Link to Issue # or Description of Defect*

## 3. The Fix
*Technical description of the correction.*

## 4. Reproduction & Verification
- [ ] **Reproduction Step:** Added a test case that fails BEFORE this fix.
- [ ] **Fix Verification:** The test case passes AFTER this fix.
- [ ] **Regression Check:** Existing Core Invariants are preserved.

## 5. Traceability
*Does this fix a violation of a Business Rule?*
- [ ] Yes, fixes Rule ID: `[ ______ ]`
- [ ] No, this is a technical/runtime error (NPE, Crash).

---
> **WARNING:** If this "Fix" changes how Inventory is calculated, you must switch to the **Rule Change** template.
