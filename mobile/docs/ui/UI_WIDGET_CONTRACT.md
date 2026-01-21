# AGRO UI Widget Contract

> **Version**: 1.0  
> **Last Updated**: 2026-01-22  
> **Status**: Active

This document defines the official widget usage contract for the AGRO Supply Chain mobile application. All new code and migrated screens MUST adhere to this contract.

---

## Table of Contents

1. [Required Widgets](#required-widgets)
2. [Forbidden Patterns](#forbidden-patterns)
3. [Allowed Exceptions](#allowed-exceptions)
4. [Design Token Reference](#design-token-reference)
5. [Semantic Status Reference](#semantic-status-reference)

---

## Required Widgets

The following widgets MUST be used in place of inline implementations:

### AgroErrorState

**REQUIRED** for all error states resulting from failed data loading.

```dart
// ✅ REQUIRED
error: (err, stack) => AgroErrorState.loadFailed(
  onRetry: () => ref.invalidate(provider),
),

// ❌ FORBIDDEN
error: (err, stack) => Center(child: Text('Error: $err')),
```

| Variant | When to Use |
|---------|-------------|
| `AgroErrorState.loadFailed()` | Failed API calls, data loading errors |
| `AgroErrorState.general()` | General errors with custom messages |

---

### AgroEmptyState

**REQUIRED** for all zero-data states.

```dart
// ✅ REQUIRED
if (items.isEmpty) {
  return AgroEmptyState(
    icon: Icons.check_circle_outline,
    iconColor: AgroColors.success.text,
    title: 'No drift detected.',
  );
}

// ❌ FORBIDDEN
if (items.isEmpty) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.check_circle, size: 64, color: Colors.green),
        Text('No drift detected.'),
      ],
    ),
  );
}
```

---

### AgroStatusBadge

**REQUIRED** for all severity/status indicators.

```dart
// ✅ REQUIRED
AgroStatusBadge.fromDriftSeverity(severity)
AgroStatusBadge.fromForecastSignal(signal)
AgroStatusBadge(status: AgroStatus.critical)

// ❌ FORBIDDEN
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: Colors.red,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text('CRITICAL', style: TextStyle(color: Colors.white)),
)
```

---

### AgroKeyValueRow

**REQUIRED** for label-value pairs in detail/summary views.

```dart
// ✅ REQUIRED
AgroKeyValueRow(
  label: 'State (Batches)',
  value: '$stateQty $unit',
)

AgroKeyValueRow(
  label: 'Net Drift',
  value: '$drift',
  emphasis: AgroKeyValueEmphasis.emphasis,
  status: AgroStatus.critical,
)

// ❌ FORBIDDEN
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text('State (Batches)', style: TextStyle(color: Colors.grey)),
    Text('$stateQty $unit'),
  ],
)
```

---

### AgroSection

**REQUIRED** for section headers with content.

```dart
// ✅ REQUIRED
AgroSection(
  title: 'Batch Snapshot (Available)',
  child: ListView(...),
)

// ❌ FORBIDDEN
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Batch Snapshot (Available)', 
         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    SizedBox(height: 8),
    ListView(...),
  ],
)
```

---

### AgroCard

**REQUIRED** for standard content containers (where applicable).

```dart
// ✅ REQUIRED
AgroCard.outlined(
  child: ListTile(...),
)

// ❌ FORBIDDEN
Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: Colors.grey[300]!),
  ),
  child: ListTile(...),
)
```

> [!WARNING]
> `AgroCard` does NOT support custom `backgroundColor`. For severity-colored cards, use a `Container` with `AgroSeverity` colors. See [Allowed Exceptions](#allowed-exceptions).

---

## Forbidden Patterns

The following patterns are **FORBIDDEN** in new code and migrated screens:

### ❌ Inline Colors

```dart
// ❌ FORBIDDEN
color: Colors.red
color: Colors.green
color: Colors.grey[400]

// ✅ REQUIRED
color: AgroColors.critical.text
color: AgroColors.success.text
color: AgroColors.textDisabled
```

---

### ❌ Inline TextStyles

```dart
// ❌ FORBIDDEN
TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
TextStyle(color: Colors.grey, fontSize: 12)

// ✅ REQUIRED
AgroTypography.cardTitle
AgroTypography.caption
```

---

### ❌ Inline EdgeInsets

```dart
// ❌ FORBIDDEN
EdgeInsets.all(16.0)
EdgeInsets.symmetric(horizontal: 12, vertical: 8)
SizedBox(height: 24)

// ✅ REQUIRED
EdgeInsets.all(AgroSpacing.lg)
EdgeInsets.symmetric(horizontal: AgroSpacing.md, vertical: AgroSpacing.sm)
SizedBox(height: AgroSpacing.xl)
```

---

### ❌ Inline Severity Logic

```dart
// ❌ FORBIDDEN
Color color;
switch (severity) {
  case 'CRITICAL':
    color = Colors.red;
    break;
  case 'MAJOR':
    color = Colors.orange;
    break;
  // ...
}

// ✅ REQUIRED
final status = AgroStatusParser.fromDriftSeverity(severity);
final style = AgroSeverity.fromStatus(status);
// Use style.textColor, style.backgroundColor, style.borderColor
```

---

### ❌ Custom Error UI

```dart
// ❌ FORBIDDEN
error: (err, stack) => Center(child: Text('Error: $err'))
error: (err, stack) => Text('Failed to load', style: TextStyle(color: Colors.red))

// ✅ REQUIRED
error: (err, stack) => AgroErrorState.loadFailed(onRetry: ...)
```

---

### ❌ Custom Empty UI

```dart
// ❌ FORBIDDEN
if (items.isEmpty) return Center(child: Text('No items found'))
if (items.isEmpty) return Column(children: [Icon(...), Text(...)])

// ✅ REQUIRED
if (items.isEmpty) return AgroEmptyState(icon: ..., title: ...)
```

---

## Allowed Exceptions

The following exceptions are **ALLOWED** with justification:

### Screen-Specific Local Widgets

When a widget is too complex for Agro components:

```dart
// ✅ ALLOWED: Complex card requiring custom layout
class _DriftItemCard extends StatelessWidget {
  // Uses Container with AgroSeverity colors because AgroCard 
  // doesn't support custom backgroundColor
}
```

**Requirements**:
- Prefix with `_` to indicate screen-private
- Add doc comment explaining why Agro widgets aren't suitable
- Use Agro design tokens internally

---

### Custom Background Colors

When cards need severity-based backgrounds:

```dart
// ✅ ALLOWED: Container with AgroSeverity styling
Container(
  decoration: BoxDecoration(
    color: severityStyle.backgroundColor,        // From AgroSeverity
    borderRadius: AgroShapes.cardRadius,         // From AgroShapes
    border: Border.all(color: severityStyle.borderColor),
  ),
  child: ...
)
```

---

### Transaction Type Indicators

For IN/OUT transaction icons:

```dart
// ✅ ALLOWED: Semantic colors for transaction direction
leading: Icon(
  isOut ? Icons.arrow_upward : Icons.arrow_downward,
  color: isOut ? AgroColors.critical.text : AgroColors.success.text,
)
```

---

### AppBar and Navigation

AppBar styling follows Material defaults, not Agro tokens:

```dart
// ✅ ALLOWED: Default AppBar styling
appBar: AppBar(
  title: const Text('Screen Title'),
  actions: [IconButton(...)],
)
```

---

## Design Token Reference

### AgroSpacing

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4.0 | Tight spacing within elements |
| `sm` | 8.0 | Spacing between related items |
| `md` | 12.0 | Card padding, medium gaps |
| `lg` | 16.0 | Standard padding, section gaps |
| `xl` | 24.0 | Large section gaps |
| `xxl` | 32.0 | Major section separation |
| `screenPadding` | 16.0 | Screen body padding |
| `cardPadding` | 12.0 | Default card padding |

---

### AgroTypography

| Token | Usage |
|-------|-------|
| `sectionTitle` | Section headers (bold, grey) |
| `cardTitle` | Card headers (bold, black) |
| `cardSubtitle` | Card secondary text |
| `body` | Standard body text |
| `bodySecondary` | Subdued body text |
| `caption` | Small helper text |
| `captionEmphasis` | Emphasized small text |
| `emphasis` | Bold emphasized text |
| `metricValue` | Large numeric values |
| `metricLabel` | Labels for metrics |
| `badgeText` | Text inside badges |

---

### AgroColors

| Token | Usage |
|-------|-------|
| `background` | Screen backgrounds |
| `surface` | Card backgrounds |
| `surfaceVariant` | Subtle card backgrounds |
| `divider` | Standard dividers |
| `dividerLight` | Subtle dividers |
| `textPrimary` | Primary text color |
| `textSecondary` | Secondary text color |
| `textDisabled` | Disabled text color |
| `primary` | Primary action color |
| `adminAccent` | Admin-specific accent |
| `critical` | Semantic color set (background, text, border) |
| `warning` | Semantic color set |
| `success` | Semantic color set |
| `info` | Semantic color set |
| `neutral` | Semantic color set |

---

### AgroShapes

| Token | Usage |
|-------|-------|
| `cardRadius` | BorderRadius.circular(12) — Cards |
| `containerRadius` | BorderRadius.circular(8) — Containers |
| `badgeRadius` | BorderRadius.circular(4) — Badges |
| `pillRadius` | BorderRadius.circular(12) — Pills |
| `bannerRadius` | BorderRadius.circular(6) — Banners |

---

## Semantic Status Reference

### AgroStatus Enum

| Status | Meaning |
|--------|---------|
| `critical` | Immediate attention required |
| `major` | Significant issue |
| `minor` | Low priority issue |
| `stable` | Normal/healthy |
| `info` | Informational |
| `unknown` | Unrecognized status |

### Status Parsers

| Parser | Input Values |
|--------|--------------|
| `fromDriftSeverity` | 'CRITICAL', 'MAJOR', 'MINOR', 'NONE' |
| `fromForecastSignal` | 'ORDER_NOW', 'LOW_STOCK', 'STABLE', 'OVERSTOCK' |
| `fromBillStatus` | 'UNPAID', 'OVERDUE', 'PARTIAL', 'PAID' |
| `fromHealthStatus` | 'healthy', 'warning', 'critical', 'unknown' |

---

> [!NOTE]
> For the full migration process, see [UI_MIGRATION_PLAYBOOK.md](./UI_MIGRATION_PLAYBOOK.md).
