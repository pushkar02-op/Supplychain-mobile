# AGRO UI Migration Playbook

> **Version**: 1.0  
> **Last Updated**: 2026-01-22  
> **Status**: Active

This playbook defines the standard process for migrating screens to use the AGRO UI Foundation and reusable widgets.

---

## Table of Contents

1. [Overview](#overview)
2. [When to Use What](#when-to-use-what)
3. [Migration Checklist](#migration-checklist)
4. [Validation Process](#validation-process)
5. [Examples from Phase 3](#examples-from-phase-3)
6. [Common Pitfalls](#common-pitfalls)

---

## Overview

### Purpose

The UI Migration effort standardizes the application's visual language by:
- Replacing inline styles with design tokens (`AgroSpacing`, `AgroTypography`, `AgroColors`)
- Replacing ad-hoc widgets with reusable components (`AgroCard`, `AgroStatusBadge`, etc.)
- Centralizing severity/status logic through semantic parsers (`AgroStatusParser`, `AgroSeverity`)

### Ground Rules

> [!IMPORTANT]
> **One Screen Per PR** — Each migration must be a single, reviewable unit.

> [!CAUTION]
> **No Behavior Changes** — Migration must preserve exact runtime behavior, navigation, and data flow.

---

## When to Use What

### Agro Foundation (Always Use)

| Pattern | Old Way | New Way |
|---------|---------|---------|
| **Spacing** | `EdgeInsets.all(16.0)` | `EdgeInsets.all(AgroSpacing.lg)` |
| **Screen padding** | `EdgeInsets.all(16.0)` | `EdgeInsets.all(AgroSpacing.screenPadding)` |
| **Section spacing** | `SizedBox(height: 24)` | `SizedBox(height: AgroSpacing.xl)` |
| **Typography** | `TextStyle(fontSize: 16, fontWeight: FontWeight.bold)` | `AgroTypography.cardTitle` |
| **Colors** | `Colors.red` | `AgroColors.critical.text` |
| **Severity colors** | `switch(severity) { case 'CRITICAL': ... }` | `AgroSeverity.fromStatus(AgroStatusParser.fromDriftSeverity(severity))` |

### Agro Widgets (Use Where Applicable)

| Widget | When to Use | When NOT to Use |
|--------|-------------|-----------------|
| `AgroCard` | Standard content containers | Complex cards with custom layouts requiring ListTile |
| `AgroCard.outlined` | Cards with visible borders | Cards needing custom background colors (use Container) |
| `AgroSection` | Section headers with child content | Standalone headers without content |
| `AgroStatusBadge` | Severity/status indicators | Non-status badges (use custom Badge) |
| `AgroKeyValueRow` | Label-value pairs | Multi-line or complex value displays |
| `AgroMetricsGrid` | Grid of metrics | Single metric or non-grid layouts |
| `AgroEmptyState` | Zero-data states | Loading states or partial data |
| `AgroErrorState` | Load failures | Validation errors in forms |
| `AgroInfoBanner` | Informational banners | Inline warnings in forms |

### Local Widgets (Allowed Exceptions)

Create local widgets (prefixed with `_`) when:
- The widget is screen-specific and won't be reused
- The layout is too complex for Agro widgets
- The widget requires custom severity-based background colors (e.g., drift cards)

```dart
// ✅ ALLOWED: Screen-specific card with custom styling
class _DriftItemCard extends StatelessWidget {
  // Uses AgroSeverity for colors, but needs custom Container for background
}

// ❌ FORBIDDEN: General-purpose card that should use AgroCard
class _MyCard extends StatelessWidget {
  // Should use AgroCard instead
}
```

---

## Migration Checklist

### Pre-Migration

- [ ] Identify screen risk level (🟢 LOW, 🟡 MEDIUM, 🔴 HIGH)
- [ ] Review screen for existing patterns (helpers, inline styles, severity logic)
- [ ] Identify required Agro widgets
- [ ] Create branch: `ui/migrate-<screen-name>`

### During Migration

- [ ] Replace inline `Colors.*` with `AgroColors.*`
- [ ] Replace inline `TextStyle(...)` with `AgroTypography.*`
- [ ] Replace inline `EdgeInsets.*` with `AgroSpacing.*`
- [ ] Replace inline severity switch/case with `AgroStatusParser` + `AgroSeverity`
- [ ] Replace inline error UI with `AgroErrorState`
- [ ] Replace inline empty UI with `AgroEmptyState`
- [ ] Replace inline cards with `AgroCard` (where applicable)
- [ ] Replace inline section headers with `AgroSection` or `AgroTypography.sectionTitle`
- [ ] Extract complex inline widgets into documented `_LocalWidget` classes
- [ ] Add doc comments to extracted widgets

### Post-Migration

- [ ] Run `flutter analyze` — must pass with no issues
- [ ] Verify screen compiles and renders correctly
- [ ] Verify exact same labels/copy
- [ ] Verify exact same navigation behavior
- [ ] Verify exact same data loading
- [ ] Document changes (lines before/after, helpers removed, widgets used)

---

## Validation Process

### "No Behavior Change" Verification

A migration has **no behavior change** if:

1. **Same Providers** — No provider changes, additions, or removals
2. **Same Navigation** — All `Navigator.push`, `context.push`, `context.go` calls unchanged
3. **Same Copy** — All user-visible text identical
4. **Same Data Flow** — Same data extraction from responses
5. **Same Conditionals** — Same `if` conditions for showing/hiding UI

### Evidence Required

For each migrated screen, document:

| Evidence | Example |
|----------|---------|
| Lines before/after | 192 → 149 (-43 lines) |
| Helpers removed | `_buildRow()`, `_buildCard()`, inline severity switch |
| Agro widgets used | `AgroErrorState`, `AgroKeyValueRow`, `AgroCard.outlined` |
| Constraint compliance | ✅ No behavior change, ✅ No copy change, ✅ No provider change |

---

## Examples from Phase 3

### DashboardScreen Migration

**Risk Level**: 🟢 LOW RISK (navigation-only)

**Changes**:
- Replaced `_buildNavCard()` helper → `_NavCard` StatelessWidget + `AgroCard.outlined`
- Replaced inline section headers → `AgroTypography.sectionTitle`
- Replaced `Colors.grey[100]` → `AgroColors.background`
- Replaced inline spacing → `AgroSpacing.*`

**Lines**: 247 → 208 (-39 lines)

---

### AdminInventoryDriftScreen Migration

**Risk Level**: 🟢 LOW RISK (read-only admin)

**Changes**:
- Replaced inline empty state → `AgroEmptyState`
- Replaced inline error state → `AgroErrorState.loadFailed`
- Replaced 13-line severity switch → `AgroStatusParser.fromDriftSeverity`
- Replaced inline severity badge → `AgroStatusBadge.fromDriftSeverity`
- Replaced `_RowInfo` widget → `AgroKeyValueRow`
- Used `Container` for severity-colored card (AgroCard doesn't support custom backgrounds)

**Lines**: 192 → 149 (-43 lines)

---

### AdminReconciliationDetailScreen Migration

**Risk Level**: 🟢 LOW RISK (read-only admin)

**Changes**:
- Replaced `_buildRow()` helper → `AgroKeyValueRow`
- Replaced inline section headers → `AgroSection`
- Replaced inline batch/transaction cards → `_BatchCard`, `_TransactionCard` with `AgroCard.outlined`
- Extracted `_SummaryCard` with `AgroSeverity` styling

**Lines**: 170 → 213 (+43 lines, but cleaner structure with extracted widgets)

---

## Common Pitfalls

### ❌ Using AgroCard with Custom Background

`AgroCard` doesn't support custom `backgroundColor`. For severity-colored cards:

```dart
// ❌ WRONG — backgroundColor not supported
AgroCard.outlined(
  backgroundColor: severityStyle.backgroundColor,  // ERROR!
  child: ...
)

// ✅ CORRECT — Use Container with AgroSeverity colors
Container(
  decoration: BoxDecoration(
    color: severityStyle.backgroundColor,
    borderRadius: AgroShapes.cardRadius,
    border: Border.all(color: severityStyle.borderColor),
  ),
  child: ...
)
```

### ❌ Forgetting to Import Agro Files

Always import all required Agro modules:

```dart
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_error_state.dart';
// ... etc
```

### ❌ Using Wrong AgroKeyValueRow Parameter

The parameter is `emphasis`, not `valueStyle`:

```dart
// ❌ WRONG
AgroKeyValueRow(
  label: 'Total',
  value: '100',
  valueStyle: AgroKeyValueStyle.emphasis,  // ERROR!
)

// ✅ CORRECT
AgroKeyValueRow(
  label: 'Total',
  value: '100',
  emphasis: AgroKeyValueEmphasis.emphasis,
)
```

### ❌ Changing Copy During Migration

Never change user-visible text:

```dart
// ❌ WRONG — Changed copy
AgroEmptyState(
  title: 'Nothing here',  // Was "No items found"
)

// ✅ CORRECT — Same copy
AgroEmptyState(
  title: 'No items found',  // Exactly as before
)
```

---

## Next Steps

After completing this migration:
1. Run `flutter analyze` to verify no issues
2. Document changes in PR description
3. Request review from UI lead
4. After approval, merge to develop

---

> [!NOTE]
> For the full widget usage contract, see [UI_WIDGET_CONTRACT.md](./UI_WIDGET_CONTRACT.md).
