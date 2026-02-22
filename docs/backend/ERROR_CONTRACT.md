# Backend Error Contract

## Unified Envelope

All handled backend errors are returned as a structured JSON envelope:

```json
{
  "detail": "human readable message",
  "rule_id": "GEN-000",
  "metadata": {}
}
```

Current handler behavior uses this envelope for `AppException`, validation errors, HTTP exceptions, and generic exceptions.

## rule_id Specification

`AppException` enforces this pattern:

```text
^[A-Z]{3}-\d{3}$
```

Pattern format:

- Prefix: 3 uppercase letters (for example `ORD`, `INV`, `DSP`, `LED`, `GEN`)
- Suffix: 3-digit numeric code

## Default Rule IDs

Current code-level defaults and mappings:

- `AppException` default when no `rule_id` is provided: `GEN-000`
- `RequestValidationError` wrapper: `GEN-422`
- `HTTPException` wrapper: `GEN-HTTP`
- Unhandled `Exception` wrapper: `GEN-500`

Note: unauthorized responses use domain-specific behavior from auth/dependency flows. There is no separate global unauthorized default constant beyond the above wrapper/default mappings.

## Handler Behavior

Global exception handlers in `backend/app/core/exceptions.py` apply these rules:

- `AppException`: preserves `detail`, `rule_id`, and `metadata`
- `UOMConfigurationError`: handled through `AppException` contract shape
- `RequestValidationError`: wrapped with fixed detail and `GEN-422`
- `HTTPException`: wrapped with `GEN-HTTP`; if incoming detail is a dict, metadata is preserved from `detail.metadata`
- `Exception`: wrapped with generic support-safe detail and `GEN-500`

Metadata behavior:

- `metadata` key is always present in envelope output
- non-dict metadata is normalized to an empty object

## Prohibitions

- No raw `HTTPException` raises in router files.
- No raw dict error return shapes from API endpoints.
- No error responses missing `rule_id`.
