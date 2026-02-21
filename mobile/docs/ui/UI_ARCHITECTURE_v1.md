# UI_ARCHITECTURE_v1.md

**Version**: 1.0  
**Status**: ACTIVE  
**UI Migration**: COMPLETED (S1-S3)  
**Provider Authority**: LOCKED  
**Service Usage in UI**: PROHIBITED  
**Date**: 2026-02-16  
**Scope**: `mobile/lib/` — All screens, widgets, providers, repositories  
**Supersedes**: Ad-hoc UI patterns, legacy service-direct state management

---

## 1. Architectural Philosophy

This UI architecture formalizes and freezes the AGRO mobile frontend design.

It is built on five non-negotiable principles:

1. **Backend is the sole source of truth.**
2. **Frontend is a thin client.**
3. **Safety over speed.**
4. **Progressive disclosure over screen proliferation.**
5. **No silent failures.**

> **Note**: This document defines structure, not visual redesign.

---

## 2. Dual-Layer UX Model

The system serves two user types:

| User Type | Goal |
|-----------|------|
| **Operator** | Complete daily tasks quickly |
| **Inspector / Admin** | Investigate lifecycle and audit deeply |

**We do NOT create two separate UIs.**  
We implement **progressive disclosure**.

### 2.1 Operational Layer (Operator)

**Goal**: Task completion in minimum taps.

**Rules**:
- Default view shows today's actionable data
- List → Action in 1–2 taps
- One primary FAB per tab
- No deep navigation required
- Maximum 2 pushes deep from a tab
- All destructive actions require confirmation dialog
- All mutations show SnackBar confirmation

**Operators MUST See**:
- Drift severity badge (read-only)
- Forecast severity badge
- Low stock warnings
- Reversal indicator (if reversed)
- Order fulfillment progress

**Operators MUST NOT See**:
- Reconciliation drill-down tables
- UOM diagnostics
- Ledger-vs-batch math
- Admin-only system health metrics

> **Principle**: Awareness without investigative complexity.

### 2.2 Inspection Layer (Admin / Power User)

**Goal**: Full lifecycle inspection and governance visibility.

**Rules**:
- Full history access
- Filters allowed
- Read-only by default
- Every status must include explanation
- Admin routes prefixed with `/admin/*`
- Admin UI gated by `isAdmin`

**Inspection Tools**:
- Inventory health dashboard
- Drift report
- Reconciliation detail screen
- Diagnostics screen
- Forecast drill-down

---

## 3. Navigation Model (FROZEN)

```
AppScaffold (IndexedStack)
├── Tab 0: OverviewScreen
├── Tab 1: StockListScreen
├── Tab 2: OrdersScreen
├── Tab 3: DispatchListScreen
└── Tab 4: MoreHubScreen
```

**Frozen Rules**:
- ✅ 5 BottomNav tabs (no expansion)
- ✅ Flat GoRouter routes
- ✅ No nested navigation
- ✅ IndexedStack preserved
- ✅ `/admin/*` prefix required
- ✅ `context.push()` for forward navigation

> **Constraint**: No ShellRoute migration. No tab restructuring.

---

## 4. Screen Depth & Complexity Rules

### 4.1 Progressive Disclosure Levels

| Level | Purpose | Tool |
|-------|---------|------|
| **L1** | List | `ListView` |
| **L2** | Inline Detail | `ExpansionTile` / `ModalBottomSheet` |
| **L3** | Full Detail Screen | `context.push()` |

> **Rule**: L2 must be preferred over L3.

**A detail screen is allowed only if**:
1. > 5 key-value fields
2. Cross-entity data
3. Lifecycle controls
4. Complex read-only inspection

### 4.2 Decomposition Rule

A screen **MUST** be decomposed if:
- File exceeds **500 lines**
- More than **3 logical sections**
- BottomSheet > **100 lines**
- Form > **5 fields**

> **Constraint**: Decomposition must not change behavior.

---

## 5. State Architecture (LOCKED)

**Final state flow**:

```mermaid
graph TD
    UI[UI (ConsumerWidget)] --> Provider[AsyncNotifier Provider]
    Provider --> Repository[Repository (pure Dart)]
    Repository --> Dio[DioClient]
    Dio --> API[Backend API]
```

### 5.1 UI Rules

**UI may**:
- `ref.watch(provider)`
- `ref.read(provider.notifier)`
- Render `AsyncValue.when()`

**UI must NOT**:
- ❌ Call Dio directly
- ❌ Call services directly
- ❌ Implement business rules
- ❌ Interpret `rule_id` logic
- ❌ Mutate state outside provider

### 5.2 Repository Rules

**Repositories**:
- Call API
- Map Dio errors → `AppException`
- ❌ Never format UI messages
- ❌ Never return `null` silently
- ✅ All failures must throw.

### 5.3 Provider Rules

**Providers**:
- Own loading/error state
- Wrap repository calls
- Expose mutation methods
- ❌ Never implement domain logic

---

## 6. Error Contract (FINAL)

Errors are classified into:
1. Transport errors
2. Business rule errors
3. Authorization errors
4. System errors

### 6.1 Transport Errors (UI May Polish)

**Examples**:
- No internet
- Timeout

**UI may convert**:
> `SocketException` → "No internet connection. Please check your network."

_Allowed because this is infrastructure mapping._

### 6.2 Business Rule Errors (UI Must Not Interpret)

**Example**:
> "Dispatch quantity exceeds remaining batch quantity"

**UI must display backend message.**  
UI may improve tone slightly but must not change meaning.

**Allowed**:
> "This item is missing default UOM configuration. Please contact an administrator."

**Forbidden**:
- ❌ Changing thresholds
- ❌ Rewriting rule logic
- ❌ Hiding backend phrasing
- ❌ Interpreting `rule_id`

### 6.3 Error Surface Matrix

| Context | Surface |
|---------|---------|
| Full page load fail | `AgroErrorState` |
| Section fail | Inline `AgroErrorState` |
| Form submit fail | Red floating `SnackBar` |
| Field validation | `TextFormField` `errorText` |
| Success | Default floating `SnackBar` |
| 401 | Auto logout |

**All SnackBars**:
- `behavior: SnackBarBehavior.floating`

**Error SnackBars**:
- `backgroundColor: AgroColors.critical.background`
- ❌ No `Colors.red`.

---

## 7. Migration Strategy

### Phase M0 — Baseline Capture
- Tag `ui-v1-baseline`
- Capture screenshots
- Save analyzer output
- Save test results
- Document route map

### Phase M1 — Structural Cleanup
- Decompose large screens
- Standardize SnackBars
- Add error normalizer
- **No behavior change.**

### Phase M2 — Repository Buildout
Create repositories for:
- Orders
- Dispatch
- MartBill
- Inventory
- Item
- Rejection
- Forecasting

_Services remain temporarily._

### Phase M3 — Provider Buildout
- Create `AsyncNotifier` providers.
- Screens untouched.

### Phase M4 — Screen Migration (One per PR)
**Order**:
1. Rejection
2. Orders
3. Dispatch
4. ItemList
5. MartBill
6. Inventory

_One screen per PR. No behavior change._

### Phase M5 — Delete Legacy Services
- After full provider migration.

### Phase M6 — Documentation Cleanup
**Archive**:
- Agent-specific governance docs
- Legacy refactor guides
- Ephemeral committed logs

**Merge** redundant governance documents.

**Freeze** `UI_ARCHITECTURE_v1`.

---

## 7.1 Platform Stability Milestones

- S1: Error Surface Standardization
- S2: Provider Rebuild Optimization
- S3: Badge & Severity Normalization

---

## 8. Non-Goals

This initiative does **NOT** include:
- ❌ Visual redesign
- ❌ Navigation restructuring
- ❌ Backend modification
- ❌ Copy rewrite
- ❌ New features
- ❌ Offline support
- ❌ Pagination redesign

---

## 9. End-State Definition

The UI is considered aligned when:
- ✅ 100% screens use Riverpod
- ✅ 0 direct service calls in widgets
- ✅ 0 Dio calls in UI
- ✅ 0 inline `Colors.*`
- ✅ 0 silent null returns
- ✅ All large screens decomposed
- ✅ Error handling unified
- ✅ Documentation aligned

---

## 10. Governance Clause

**This document is LOCKED.**

Any change to:
- Navigation structure
- State architecture
- Error contract
- Dual-layer model

**Requires an RFC.**

**Status**: ACTIVE
