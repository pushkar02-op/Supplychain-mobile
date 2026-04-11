---
name: branch-phase-discipline
description: Prevents mixed concerns and broken history in Git.
---

## When to use
Trigger before:
- Any push
- Any merge

## Strategy
1. One branch per phase.
2. Clean working tree.
3. No unrelated changes.
4. Update docs before merge.

## Validation
• git status clean  
• Commit messages scoped  

## Failure Modes
• Sneaking fixes into wrong branch  
