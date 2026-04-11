---
name: void-trap-prevention
description: Ensures no user action leads to irreversible dead ends.
---

## When to use this Skill
Trigger when:
- Blocking deletes or voids
- Introducing guardrails
- Adding validation errors

## Step by Step Strategy
1. Identify downstream dependencies.
2. If blocking an action:
   - Ensure reversal path exists.
3. Validate:
   - User can undo downstream actions first.
4. UX must explain resolution steps.

## Best Practices
• Never block without recovery  
• Reversals > deletions  

## Validation
• User can always recover to a valid state  

## Failure Modes
• Permanent "cannot delete" errors  

Why this Skill exists

The Rejection Void Trap was a major incident.
This Skill prevents repeats.
