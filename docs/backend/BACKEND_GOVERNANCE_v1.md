# Backend Governance v1 - Stability Baseline

## Scope

Backend Governance v1 includes the completed hardening phases:

- G-B1 Error Surface Normalization
- G-B2 Drift Governance Hardening
- G-B3 Transaction Integrity
- G-B4 Decimal Safety
- G-B5 Authorization Normalization
- G-B6 Strict Error Contract Enforcement
- G-B7 Threshold Externalization
- G-B9 Observability and Audit Governance

The scope of this baseline is backend runtime governance in `backend/app`, with enforcement backed by the current backend test suite.

## Governance Invariants

- All API errors conform to the unified envelope.
- `AppException.rule_id` must match `^[A-Z]{3}-\d{3}$`.
- Quantity and financial math use Decimal.
- Domain persistence for governed quantity fields avoids float-based model types.
- Scoped mutating services follow a single-commit transaction boundary.
- Scoped mutating services explicitly roll back on failure.
- Drift and forecasting thresholds are centralized in governance configuration.
- Inline role checks are not used where dependency enforcement is applied.
- Admin routes are enforced through admin dependencies.
- Requests carry correlation IDs via middleware.
- Structured logging is required; `print` statements are prohibited in `backend/app`.

## Stability Declaration

Backend Governance v1 is locked as the backend stability baseline.

Any structural governance change requires RFC-lite review before implementation.

Related references:

- [Backend Error Contract](./ERROR_CONTRACT.md)
- [Threshold Governance Model](./THRESHOLD_GOVERNANCE.md)
- [Observability and Audit Model](./OBSERVABILITY_MODEL.md)
- [Business Rules and Enforcement](../business_rules_and_enforcement.md)
