import 'package:flutter/material.dart';

/// AGRO Supply Chain — Typography System
///
/// Centralized text styles for consistent typography across all screens.
///
/// Usage:
/// ```dart
/// Text('Section', style: AgroTypography.sectionTitle)
/// Text('Item name', style: AgroTypography.cardTitle)
/// ```
///
/// Rules:
/// - Never use inline font sizes or weights directly
/// - Always use semantic style names
/// - These styles are context-independent (no BuildContext dependency)

abstract class AgroTypography {
  AgroTypography._();

  // ─────────────────────────────────────────────────────────────────────────
  // BASE FONT SIZES
  // ─────────────────────────────────────────────────────────────────────────

  static const double _fontSizeXs = 10.0;
  static const double _fontSizeSm = 12.0;
  static const double _fontSizeMd = 14.0;
  static const double _fontSizeLg = 16.0;
  static const double _fontSizeXl = 18.0;
  static const double _fontSizeXxl = 20.0;
  static const double _fontSizeHero = 24.0;

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC TEXT STYLES
  // ─────────────────────────────────────────────────────────────────────────

  /// Section title — Used for section headers ("Daily Operations", "Reference").
  /// Font: 14, bold, grey
  static const TextStyle sectionTitle = TextStyle(
    fontSize: _fontSizeMd,
    fontWeight: FontWeight.bold,
    color: Color(0xFF9E9E9E), // grey
  );

  /// Card title — Used for main title in cards/list items.
  /// Font: 16, semibold, dark
  static const TextStyle cardTitle = TextStyle(
    fontSize: _fontSizeLg,
    fontWeight: FontWeight.w600,
    color: Color(0xFF212121), // grey.shade900
  );

  /// Card subtitle — Used for secondary info in cards.
  /// Font: 13, normal, medium grey
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.normal,
    color: Color(0xFF757575), // grey.shade600
  );

  /// Body text — Standard body content.
  /// Font: 14, normal, dark
  static const TextStyle body = TextStyle(
    fontSize: _fontSizeMd,
    fontWeight: FontWeight.normal,
    color: Color(0xFF212121), // grey.shade900
  );

  /// Body secondary — Muted body content.
  /// Font: 14, normal, grey
  static const TextStyle bodySecondary = TextStyle(
    fontSize: _fontSizeMd,
    fontWeight: FontWeight.normal,
    color: Color(0xFF757575), // grey.shade600
  );

  /// Caption — Small supporting text, timestamps, metadata.
  /// Font: 12, normal, grey
  static const TextStyle caption = TextStyle(
    fontSize: _fontSizeSm,
    fontWeight: FontWeight.normal,
    color: Color(0xFF9E9E9E), // grey.shade500
  );

  /// Caption emphasis — Small but important text.
  /// Font: 12, medium, dark grey
  static const TextStyle captionEmphasis = TextStyle(
    fontSize: _fontSizeSm,
    fontWeight: FontWeight.w500,
    color: Color(0xFF616161), // grey.shade700
  );

  /// Emphasis — Bold inline emphasis.
  /// Font: 14, bold, dark
  static const TextStyle emphasis = TextStyle(
    fontSize: _fontSizeMd,
    fontWeight: FontWeight.bold,
    color: Color(0xFF212121), // grey.shade900
  );

  /// Metric value — Large numeric displays (counts, quantities).
  /// Font: 24, bold
  static const TextStyle metricValue = TextStyle(
    fontSize: _fontSizeHero,
    fontWeight: FontWeight.bold,
  );

  /// Metric label — Label under metric value.
  /// Font: 12, normal, grey
  static const TextStyle metricLabel = TextStyle(
    fontSize: _fontSizeSm,
    fontWeight: FontWeight.normal,
    color: Color(0xFF757575), // grey.shade600
  );

  /// Date header — Screen/section date displays.
  /// Font: 18, semibold, dark
  static const TextStyle dateHeader = TextStyle(
    fontSize: _fontSizeXl,
    fontWeight: FontWeight.w600,
    color: Color(0xFF212121), // grey.shade900
  );

  /// Screen title — AppBar titles (for reference, not usually styled directly).
  /// Font: 20, normal
  static const TextStyle screenTitle = TextStyle(
    fontSize: _fontSizeXxl,
    fontWeight: FontWeight.normal,
    color: Color(0xFF212121),
  );

  /// Badge text — Small text inside status badges.
  /// Font: 11, bold
  static const TextStyle badgeText = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.bold,
  );

  /// Tiny text — Very small annotations, timestamps.
  /// Font: 10, normal, grey
  static const TextStyle tiny = TextStyle(
    fontSize: _fontSizeXs,
    fontWeight: FontWeight.normal,
    color: Color(0xFF9E9E9E), // grey.shade500
  );

  /// Disclaimer/info banner text.
  /// Font: 11, normal
  static const TextStyle disclaimer = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.normal,
  );

  /// Italic help text.
  /// Font: 11, normal, italic, grey
  static const TextStyle helpText = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: Color(0xFF757575), // grey.shade700
  );
}
