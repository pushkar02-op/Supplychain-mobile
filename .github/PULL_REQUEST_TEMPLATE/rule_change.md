# ⚠ Pull Request: Business Rule Change

> **CRITICAL:** Changing strict Business Rules (Ledger, UOM, Identity) requires Pre-Approval.

## 1. Authorization
- [ ] **RFC Approved:** Link to `docs/` or Issue: `[ LINK HERE ]`
- [ ] **Documentation Updated:** `docs/business_rules_and_enforcement.md` matches this code.
- [ ] **Map Updated:** `docs/RULE_ENFORCEMENT_MAP.md` is updated.
- [ ] **Freeze Check:** If touching Core, I certify this is an approved Red Lane change.

## 2. Change Description
*What rule is changing and why?*

## 3. Migration Plan
*How strictly is this enforced? How do we handle old data?*
- [ ] Migration script included.
- [ ] Backwards compatibility maintained.
- [ ] "Break the World" (Requires Downtime approval).

## 4. Verification
- [ ] **New Rule Test:** Added test case proving the new rule.
- [ ] **Old Rule Negation:** Added test case proving the old logic is effectively gone/migrated.

---
> **GOVERNANCE BLOCKER:**
> A "Rule Change" PR without a link to an updated Document/RFC is **INVALID** and will be closed.
