---
name: pagination-before-scale
description: Prevents unbounded reads in backend and frontend.
---

## When to use
Trigger when:
- List endpoints are added
- Admin screens fetch history
- Tables expected to grow

## Strategy
1. Require skip/limit in API.
2. Return has_more.
3. UI implements Load More.
4. Reset pagination on filter change.

## Validation
• No .all() on large tables  
• UI never loads entire history  

## Failure Modes
• "We'll paginate later"  

Why this Skill exists

Unbounded reads were a time-bomb repeatedly identified.
