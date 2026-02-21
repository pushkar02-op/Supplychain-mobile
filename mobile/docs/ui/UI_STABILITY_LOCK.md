# UI_STABILITY_LOCK.md

Status: ACTIVE
Effective Date: 2026-02-21
Scope: mobile/lib

## Purpose

This document locks the UI platform architecture to prevent regression after migration completion (S1-S3).

## Locked Guardrails

1. No direct service usage in UI layer.
2. All domain state must flow through provider authority.
3. All SnackBars must use `AgroSnackBar`.
4. All errors must use `AgroErrorState`.
5. All severity rendering must use `AgroStatusBadge`.
6. No `Colors.*` usage for semantic status/severity rendering in UI layer.
7. No broad `ref.watch(provider)` on large states without evaluating `select(...)`.

## Enforcement

- New UI work must follow these constraints by default.
- Any exception requires explicit governance sign-off and documentation.
