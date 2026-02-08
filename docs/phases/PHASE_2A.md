# PHASE 2A: API Contract & Governance Alignment
Status: ACTIVE

## Scope
Ensure backend API error contracts match documented governance. Eliminate legacy paths that violate locked rules.

## Allowed File Paths
- `backend/app/core/exceptions.py`
- `backend/app/services/**`
- `backend/app/api/**`
- `docs/business_rules_and_enforcement.md`
- `docs/architecture/CHANGELOG.md`
- `backend/tests/**` (Contract tests only)

## Forbidden File Paths
- `backend/app/db/models/inventory_txn.py`
- `backend/app/db/models/batch.py`
- `alembic/**`
- `mobile/**`

## Goals
1. Audit API Error Serialization (match ORD-007).
2. Align Error Propagation (preserve rule metadata).
3. Legacy Path Governance Check (quarantine or document).

## Verification
- Contract tests pass.
- No business logic changes in forbidden paths.
