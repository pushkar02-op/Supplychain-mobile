---
name: decimal-purity-enforcement
description: Prevents float/Decimal mixing in inventory, pricing, and quantity calculations.
---

## When to Trigger
- Backend changes to services handling quantity, price, or balance
- Arithmetic operations in inventory, dispatch, rejection, or adjustment logic
- TypeError involving Decimal and float operands

## Step-by-Step Enforcement Strategy
1. Identify all arithmetic operations in the change (+, -, *, /).
2. Trace operand sources (input, database, literal).
3. Verify:
   - Database columns use `Numeric(precision, scale, asdecimal=True)`
   - Input conversion uses `Decimal(str(value))`, never `float()`
   - No float literals in calculations (use `Decimal("1.0")`)
4. If float detected in calculation path:
   - STOP
   - Identify conversion point
   - Require Decimal conversion

## STOP Conditions (Mandatory)
- Float literal used in quantity/price calculation
- `float()` conversion on monetary or quantity values
- Database column missing `asdecimal=True` for Numeric

## Validation & Acceptance Criteria
- All quantity/price calculations use only Decimal operands
- No `TypeError: unsupported operand type(s)` in arithmetic
- Database roundtrip preserves precision

## Failure Modes Prevented
- `TypeError: unsupported operand type(s) for *: 'decimal.Decimal' and 'float'`
- Silent precision loss causing ledger drift
- Inconsistent balance calculations

## Explicit Non-Responsibilities
- Does NOT enforce specific precision/scale
- Does NOT validate business calculation correctness
- Does NOT cover display formatting (frontend)