# Technical Debt Register

**Status:** Living Document
**Last Updated:** 2025-12-21

## High Priority

### 1. `created_by` Type Inconsistency
- **Finding:** Some services use `created_by: str` (username), others use `created_by: int` (user ID).
- **Risk:** Breaks audit trails and foreign key constraints involving User table.
- **Deferral Reason:** Requires Database Migration (changing column types) and massive refactor of all callsites.
- **Coordination:** Needs Backend + DB Freeze.

---

## Medium Priority

### 2. Pagination Parameter Drift
- **Finding:** 
    - `invoice` API uses `page` / `page_size`.
    - `batch`, `item`, `order` APIs use `skip` / `limit`.
- **Risk:** Inconsistent developer experience for frontend consumers.
- **Deferral Reason:** Changing parameters breaks the Mobile App contract.
- **Coordination:** Needs Frontend Team to update all API clients before Backend changes defaults.

### 3. Hardcoded Mobile IP
- **Finding:** `mobile/lib/core/api_config.dart` defaults to `192.168.1.44`.
- **Risk:** Mobile app build fails connectivity on any other network or developer machine.
- **Correction:** Should use a build-time configuration or runtime discovery.

---

## Low Priority

### 4. `order` Schema Patching
- **Finding:** `mart_name` is auto-populated via `model_validator` in Pydantic.
- **Note:** This is a safe fix for now, but ideally the DB model should just return what is needed, or a specific "Read Model" should be used (CQRS style).

### 5. Lack of Frontend Tests
- **Finding:** Only default `widget_test.dart` exists.
- **Risk:** Regression in UI flows is manual-testing only.
