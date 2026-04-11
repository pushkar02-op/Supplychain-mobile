---
name: receipt-batch-separation-guard
description: Prevents confusion between immutable receipts and mutable batch state.
---

## When to use this Skill
Trigger when:
- Stock list UX is changed
- Adjustments or corrections are added
- Users complain "stock looks wrong"

## Step by Step Strategy
1. Identify which quantity is being displayed:
   - Received (StockEntry)
   - Current (Batch)
2. Ensure UI labels both if they differ.
3. Never overwrite receipt quantity.
4. Add "Adjusted" indicators when divergence exists.

## Edge Cases
• Multiple receipts per day for same item  
• Multiple adjustments on same batch  

## Validation
• UI clearly distinguishes historical vs current  
• Receipt quantity never changes  

## Failure Modes
• Showing batch qty as "Received"  
• Hiding adjustments  

Why this Skill exists

This confusion caused multiple rounds of bugs and mistrust.
This Skill locks the mental model.
