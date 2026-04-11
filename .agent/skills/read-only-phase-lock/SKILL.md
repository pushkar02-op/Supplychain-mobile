---
name: read-only-phase-lock
description: Enforces READ-ONLY constraints for locked phases like Forecasting.
---

## When to use
Trigger when:
- Working in a LOCKED phase
- Adding UI to read models

## Strategy
1. Identify allowed tables.
2. Block writes to forbidden tables.
3. Document constraints explicitly.

## Validation
• No mutation code exists  
• Tests assert read-only behavior  

## Failure Modes
• Sneaking in "minor" writes  

Why this Skill exists

Forecasting integrity depends on zero side effects.
