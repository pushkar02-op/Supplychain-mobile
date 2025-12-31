# 🧹 Pull Request: Refactor / Tech Debt

> **Goal:** Improve code quality without altering behavior.

## 1. Safety Guarantee (MANDATORY)
- [ ] I certify that this PR changes **ZERO** Business Logic.
- [ ] I certify that `docs/business_rules_and_enforcement.md` remains 100% accurate.
- [ ] I verify that all tests pass (No changes to test expectations allowed).

## 2. What is being Refactored?
*Description of cleanup, renaming, or structural change.*

## 3. Risk Assessment
- [ ] Low Risk (Renaming, Comments, formatting)
- [ ] Medium Risk (Moving files, extracting functions)
- [ ] High Risk (Changing DB queries, ORM logic) -> **Be extremely careful.**

## 4. Verification
- [ ] **Automated Tests:** All passed.
- [ ] **Sanity Check:** Manually verified the feature still works.

---
> **NOTE:** If you "cleaned up" logic and it changed the result, use the **Bug Fix** or **Rule Change** template.
