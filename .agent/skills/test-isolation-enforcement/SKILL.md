---
name: test-isolation-enforcement
description: Ensures tests do not pollute shared state and can run in any order.
---

## When to Trigger
- Creating tests that interact with database
- Test passes locally but fails in CI suite
- Test failure mentions "unexpected data" or stale state

## Step-by-Step Enforcement Strategy
1. Verify test fixture uses session rollback OR explicit cleanup.
2. Check that test creates ALL required data dependencies.
3. Verify no reliance on data from other tests.
4. Ensure teardown removes created data OR transaction is rolled back.
5. Validate test passes when run:
   - In isolation (`pytest test_file.py::test_name`)
   - In full suite (`pytest`)
   - In reverse order (if determinism required)

## STOP Conditions (Mandatory)
- Test relies on data it did not create
- Fixture uses `.commit()` without cleanup
- Test modifies global/shared state without restoration

## Validation & Acceptance Criteria
- Each test creates its own fixture data
- Session state is clean after each test
- No flaky test failures due to execution order

## Failure Modes Prevented
- "Stale data" test failures
- "Works in isolation, fails in suite" pattern
- Flaky CI requiring re-runs

## Explicit Non-Responsibilities
- Does NOT enforce test naming conventions
- Does NOT validate test coverage
- Does NOT check assertion quality