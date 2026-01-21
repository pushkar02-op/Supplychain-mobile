import 'package:flutter/material.dart';

/// AGRO Supply Chain — Shape System
///
/// Centralized shape definitions for consistent border radii across all screens.
///
/// Usage:
/// ```dart
/// Card(shape: RoundedRectangleBorder(borderRadius: AgroShapes.cardRadius))
/// Container(decoration: BoxDecoration(borderRadius: AgroShapes.badgeRadius))
/// ```
///
/// Rules:
/// - Never use BorderRadius.circular(12) directly
/// - Always use semantic shape names
/// - These values reflect current common usage patterns

abstract class AgroShapes {
  AgroShapes._();

  // ─────────────────────────────────────────────────────────────────────────
  // BASE RADIUS VALUES
  // ─────────────────────────────────────────────────────────────────────────

  /// Extra small radius — 4px
  static const double _radiusXs = 4.0;

  /// Small radius — 6px
  static const double _radiusSm = 6.0;

  /// Medium radius — 8px
  static const double _radiusMd = 8.0;

  /// Large radius — 12px
  static const double _radiusLg = 12.0;

  /// Extra large radius — 16px
  static const double _radiusXl = 16.0;

  /// Full/pill radius — 20px
  static const double _radiusPill = 20.0;

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC BORDER RADII (BorderRadius)
  // ─────────────────────────────────────────────────────────────────────────

  /// Card border radius — 12px (used for navigation cards, list cards).
  static final BorderRadius cardRadius = BorderRadius.circular(_radiusLg);

  /// Container border radius — 8px (used for info containers, metrics).
  static final BorderRadius containerRadius = BorderRadius.circular(_radiusMd);

  /// Badge/chip border radius — 4px (used for status badges).
  static final BorderRadius badgeRadius = BorderRadius.circular(_radiusXs);

  /// Pill/chip full radius — 12px (used for round badges, chips).
  static final BorderRadius pillRadius = BorderRadius.circular(_radiusLg);

  /// Banner border radius — 6px (used for info/warning banners).
  static final BorderRadius bannerRadius = BorderRadius.circular(_radiusSm);

  /// Bottom sheet top radius — 16px.
  static final BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(_radiusXl),
  );

  /// Input field radius — 4px (for text fields, dropdowns).
  static final BorderRadius inputRadius = BorderRadius.circular(_radiusXs);

  /// Filter chip radius — 20px (rounded filter chips).
  static final BorderRadius filterChipRadius = BorderRadius.circular(
    _radiusPill,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC SHAPE BORDERS (RoundedRectangleBorder)
  // ─────────────────────────────────────────────────────────────────────────

  /// Card shape with standard radius.
  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: cardRadius,
  );

  /// Card shape with subtle grey border.
  static RoundedRectangleBorder cardShapeWithBorder({Color? borderColor}) {
    return RoundedRectangleBorder(
      borderRadius: cardRadius,
      side: BorderSide(color: borderColor ?? const Color(0xFFE0E0E0)),
    );
  }

  /// Container shape with standard radius.
  static final RoundedRectangleBorder containerShape = RoundedRectangleBorder(
    borderRadius: containerRadius,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // RAW RADIUS VALUES (for custom BoxDecoration)
  // ─────────────────────────────────────────────────────────────────────────

  /// Raw card radius value — 12.0
  static const double cardRadiusValue = _radiusLg;

  /// Raw container radius value — 8.0
  static const double containerRadiusValue = _radiusMd;

  /// Raw badge radius value — 4.0
  static const double badgeRadiusValue = _radiusXs;

  /// Raw banner radius value — 6.0
  static const double bannerRadiusValue = _radiusSm;
}
