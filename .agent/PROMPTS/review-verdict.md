# AGRO — Review Verdict Template

> Used by the Planner to formally approve or reject a SESSION CLOSE
> submitted by an executor. Emit one of these after reading the SESSION
> CLOSE block. The human uses the verdict to decide whether to run
> `./close-session.sh`.
>
> Never combine REVIEW VERDICT with design discussion or new briefs.
> It is a single-purpose signal.

---

## REVIEW VERDICT

**Session ID:** YYYY-MM-DD-slug

**Status:** APPROVED | REJECTED | APPROVED_WITH_FOLLOWUP

---

### Gate checks

| Gate | Result | Notes |
|------|--------|-------|
| Scope adherence | ✓ / ✗ | Did the executor touch only files in scope? |
| Invariants | ✓ / ✗ | Were all triggered invariants named and confirmed? |
| Documentation | ✓ / ✗ | Were all required docs updated per the brief? |
| Validation | ✓ / ✗ | Were all validation commands run with output shown? |
| State delta | valid / invalid | Does the STATE_DELTA match what actually changed? |
| No new terms | ✓ / ✗ | Were any new terms introduced without glossary entry? |

---

### Rejection reasons (if REJECTED)

List each reason specifically. The executor must address every item
before resubmitting a SESSION CLOSE.

- [ ] <specific issue — file, field, or rule violated>
- [ ] <specific issue>

---

### Follow-up items (if APPROVED_WITH_FOLLOWUP)

These items do not block close. They are future briefs.

- [ ] <follow-up — will become a separate brief>
- [ ] <follow-up>

---

### Decision

```
Proceed to CLOSE: yes | no
```

If `yes`: the human runs `./close-session.sh`.
If `no`: the executor must address the rejection reasons and resubmit.

---

## QUICK APPROVAL (for clean sessions)

When all gates pass and there are no issues, a quick form is acceptable:

```
## REVIEW VERDICT
Session ID: YYYY-MM-DD-slug
Status: APPROVED
All gates: ✓
Proceed to CLOSE: yes
```
