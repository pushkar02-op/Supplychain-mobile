/// AGRO Supply Chain — Spacing System
///
/// Centralized spacing values for consistent layout across all screens.
///
/// Usage:
/// ```dart
/// SizedBox(height: AgroSpacing.md)
/// Padding(padding: EdgeInsets.all(AgroSpacing.lg))
/// ```
///
/// Rules:
/// - Never use magic numbers (8, 16, 24) directly
/// - Always use semantic spacing names
/// - These values align with the 4px grid system
library;

abstract class AgroSpacing {
  AgroSpacing._();

  // ─────────────────────────────────────────────────────────────────────────
  // BASE SPACING VALUES (4px grid)
  // ─────────────────────────────────────────────────────────────────────────

  /// Extra small spacing — 4px
  /// Use for: tight icon margins, dense lists
  static const double xs = 4.0;

  /// Small spacing — 8px
  /// Use for: compact padding, related element gaps
  static const double sm = 8.0;

  /// Medium spacing — 12px
  /// Use for: card/list item margins, section gaps
  static const double md = 12.0;

  /// Large spacing — 16px
  /// Use for: screen padding, card content padding, major gaps
  static const double lg = 16.0;

  /// Extra large spacing — 24px
  /// Use for: section separators, form group gaps
  static const double xl = 24.0;

  /// Double extra large spacing — 32px
  /// Use for: major screen sections, hero spacing
  static const double xxl = 32.0;

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC SPACING (Named by Intent)
  // ─────────────────────────────────────────────────────────────────────────

  /// Standard screen padding (horizontal and vertical).
  static const double screenPadding = 16.0;

  /// Card internal content padding.
  static const double cardPadding = 16.0;

  /// List item vertical margin.
  static const double listItemMargin = 12.0;

  /// Section header bottom margin.
  static const double sectionHeaderGap = 8.0;

  /// Gap between related form fields.
  static const double formFieldGap = 16.0;

  /// Gap between major screen sections.
  static const double sectionGap = 24.0;

  /// Icon-to-text spacing.
  static const double iconTextGap = 8.0;

  /// Compact icon-to-text spacing.
  static const double iconTextGapCompact = 6.0;
}
