---
name: test-schema-compliance
description: Ensures all test payloads include required Pydantic schema fields before test execution.
---

## When to Trigger
- Creating or modifying test files under `tests/`
- Adding or modifying Pydantic `*Create` schemas
- CI failure containing `ValidationError: Field required`

## Step-by-Step Enforcement Strategy
1. Identify all `*Create` or `*Update` schema usages in the test file.
2. Locate the schema definition in `app/db/schemas/`.
3. List all fields WITHOUT default values (required fields).
4. Verify the test payload includes ALL required fields.
5. If any required field is missing:
   - STOP
   - List missing fields with schema location
   - Do not proceed until fixed

## STOP Conditions (Mandatory)
- Any required schema field is missing from test payload
- Schema definition cannot be located
- Ambiguity about which schema version applies

## Validation & Acceptance Criteria
- All `*Create` payloads in tests include every required field
- Tests pass Pydantic validation before hitting database
- No `ValidationError: Field required` in CI logs

## Failure Modes Prevented
- `ValidationError: Field required` CI failures
- "Works locally, fails in CI" due to schema version drift
- Repeated `fix(tests): add missing required fields` commits

## Explicit Non-Responsibilities
- Does NOT validate business logic correctness
- Does NOT check schema design quality
- Does NOT enforce optional field usage