---
name: fact-report-first
description: Forces evidence collection before design, fixes, or refactors.
---

## When to use this Skill
Trigger when:
- UX redesign is requested
- Backend behavior is unclear
- A bug is reported without root cause
- The agent feels tempted to "assume"

## Step by Step Strategy
1. Generate a FACT REPORT:
   - Current behavior
   - Data sources
   - Constraints
   - Provable UX risks
2. Separate facts vs speculation.
3. Explicitly list unknowns.
4. Only proceed after user confirmation.

## Edge Cases & Best Practices
• Screens ≠ behavior; inspect services  
• Copy errors count as bugs  

## Validation
• All claims traceable to code or API behavior  
• No speculative language  

## Failure Modes
• Jumping directly to design  
• "This probably works like…" assumptions  

Why this Skill exists

Many early mistakes happened because agents skipped factual audits.
This Skill hard-blocks that behavior.
