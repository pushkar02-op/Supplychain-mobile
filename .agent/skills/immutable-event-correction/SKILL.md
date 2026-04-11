---
name: immutable-event-correction
description: Standardizes correction of immutable events using reversals or compensating entries.
---

## When to use this Skill
Trigger when:
- Editing is requested on dispatch, receipt, rejection
- "Fix" or "Update" is suggested

## Strategy
1. Confirm event is immutable.
2. Block edits.
3. Design reversal or adjustment.
4. Preserve audit trail.

## Validation
• Original event unchanged  
• Correction visible as new event  

## Failure Modes
• Allowing edits "just this once"  

Why this Skill exists

Multiple phases reinforced: events are facts, not drafts.
