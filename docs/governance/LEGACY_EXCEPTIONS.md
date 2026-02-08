# Legacy Governance Exceptions

This document tracks known deviations from the [Architecture Governance](./AGENT_EXECUTION_PROTOCOL.md) and [Business Rules](../business_rules_and_enforcement.md). These are technical debt items that must be preserved for backward compatibility but are slated for future remediation.

## Active Exceptions

### 1. Implicit Dispatch-to-Order Linking (Heuristic Fallback)
- **Component**: `backend/app/services/dispatch_entry.py`
- **Function**: `create_dispatch_entry`
- **Violation**: `ORD-007` (Strict Order-Dispatch Linkage)
- **Description**: 
  When `order_id` is not provided in `DispatchEntryCreate`, the system attempts to heuristically link the dispatch to an active order for the same Item+Mart.
  ```python
  # Heuristic Fallback (Legacy)
  order = db.scalar(
      select(Order).where(
          Order.item_id == entry.item_id,
          Order.mart_id == mart.id,
          Order.status.notin_(["Cancelled", "Completed"]),
      )
  )
  ```
- **Impact**: 
  - Verification tests (`test_inventory_rules.py`) heavily rely on this fallback.
  - Frontend dispatch screens may historically omit `order_id`.
- **Remediation Plan**:
  - Phase 5A: Update frontend to always send `order_id`.
  - Phase 5B: Deprecate fallback with warning logs.
  - Phase 5C: Remove fallback and enforce strict `ORD-007`.

### 2. Legacy Pagination Parameters
- **Component**: `backend/app/api/mart_bill.py`
- **Endpoint**: `GET /mart-bills/`
- **Violation**: API Standardization (Offset/Limit)
- **Description**:
  Accepts `page` and `page_size` query parameters alongside `skip` and `limit`.
- **Remediation Plan**:
  - Deprecate `page` and `page_size` in OpenAPI spec (Done).
  - Remove in v2 API.

---

## Runtime Containment Signals (Phase 2B)

Phase 2B introduced **observability-only** signals to make legacy path usage visible in logs without changing any runtime behavior.

### Signal 1: `LEGACY_PATH_TRIGGERED` (Dispatch Heuristic)
- **Location**: `backend/app/services/dispatch_entry.py`
- **Trigger**: When `order_id` is not provided and heuristic fallback finds an active order
- **Log Level**: WARNING
- **Structured Fields**:
  - `rule_violation`: "ORD-007"
  - `legacy_path`: "implicit_dispatch_order_link"
  - `item_id`: The item being dispatched
  - `mart_id`: The mart receiving the dispatch
  - `linked_order_id`: The order that was heuristically linked
- **Behavior Change**: ❌ None. Dispatch continues as before.

### Signal 2: `LEGACY_PARAM_USED` (Pagination)
- **Location**: `backend/app/api/mart_bill.py`
- **Trigger**: When `page` or `page_size` query parameters are used
- **Log Level**: WARNING
- **Structured Fields**:
  - `legacy_param`: "page" or "page_size"
  - `replacement`: "skip/limit"
  - `endpoint`: "/mart-bills"
- **Behavior Change**: ❌ None. Pagination continues as before.

### Purpose

These signals exist to:
1. Surface legacy usage in production logs for monitoring
2. Prevent silent dependency on deprecated paths
3. Enable gradual migration tracking before Phase 5 deprecation

**No behavior changes were introduced. All API contracts remain intact.**

