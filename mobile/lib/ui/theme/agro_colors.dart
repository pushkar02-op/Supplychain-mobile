import 'package:flutter/material.dart';

/// AGRO Supply Chain — Semantic Color System
///
/// This file defines semantic colors used across the application.
/// Colors are named by INTENT, not by hue.
///
/// Usage:
/// ```dart
/// Container(color: AgroColors.critical.background)
/// Text('Error', style: TextStyle(color: AgroColors.critical.text))
/// ```
///
/// Rules:
/// - Never use Colors.red, Colors.green directly in screens
/// - Always use semantic names (critical, warning, success, etc.)
/// - This enables consistent theming and accessibility

/// A semantic color set containing background, text, and border colors.
class AgroSemanticColor {
  final Color background;
  final Color text;
  final Color border;

  const AgroSemanticColor({
    required this.background,
    required this.text,
    required this.border,
  });

  /// Create a semantic color from a base color with automatic shading.
  factory AgroSemanticColor.fromBase(Color base) {
    // Use new Color API for RGB component access
    final r = (base.r * 255).round();
    final g = (base.g * 255).round();
    final b = (base.b * 255).round();
    return AgroSemanticColor(
      background: Color.fromRGBO(r, g, b, 0.1),
      text: HSLColor.fromColor(base).withLightness(0.3).toColor(),
      border: Color.fromRGBO(r, g, b, 0.3),
    );
  }
}

/// Semantic color definitions for AGRO Supply Chain.
///
/// These colors map to business intent, not visual appearance.
abstract class AgroColors {
  AgroColors._();

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC STATUS COLORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Critical status — Stock out, system failure, immediate action required.
  /// Maps to: CRITICAL signal, negative stock, errors.
  static const critical = AgroSemanticColor(
    background: Color(0xFFFFEBEE), // red.shade50
    text: Color(0xFFC62828), // red.shade800
    border: Color(0xFFEF9A9A), // red.shade200
  );

  /// Warning status — Attention needed, approaching threshold.
  /// Maps to: REORDER_SOON signal, MAJOR drift, warnings.
  static const warning = AgroSemanticColor(
    background: Color(0xFFFFF3E0), // orange.shade50
    text: Color(0xFFEF6C00), // orange.shade800
    border: Color(0xFFFFCC80), // orange.shade200
  );

  /// Caution status — Monitor closely, minor issues.
  /// Maps to: WATCH signal, MINOR drift, adjustments.
  static const caution = AgroSemanticColor(
    background: Color(0xFFFFFDE7), // amber.shade50
    text: Color(0xFFF9A825), // amber.shade800
    border: Color(0xFFFFE082), // amber.shade200
  );

  /// Success status — Healthy, complete, verified.
  /// Maps to: STABLE signal, verified bills, successful operations.
  static const success = AgroSemanticColor(
    background: Color(0xFFE8F5E9), // green.shade50
    text: Color(0xFF2E7D32), // green.shade800
    border: Color(0xFFA5D6A7), // green.shade200
  );

  /// Info status — Informational, neutral highlight.
  /// Maps to: Disclaimers, help text, informational banners.
  static const info = AgroSemanticColor(
    background: Color(0xFFE3F2FD), // blue.shade50
    text: Color(0xFF1565C0), // blue.shade800
    border: Color(0xFF90CAF9), // blue.shade200
  );

  /// Neutral status — Default, no specific meaning.
  /// Maps to: Standard UI elements, unfocused states.
  static const neutral = AgroSemanticColor(
    background: Color(0xFFFAFAFA), // grey.shade50
    text: Color(0xFF424242), // grey.shade800
    border: Color(0xFFE0E0E0), // grey.shade300
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SURFACE & BACKGROUND COLORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Primary background color for screens.
  static const Color background = Color(0xFFF5F5F5); // grey[100]

  /// Elevated surface color (cards, dialogs).
  static const Color surface = Color(0xFFFFFFFF); // white

  /// Subtle surface for secondary containers.
  static const Color surfaceVariant = Color(0xFFFAFAFA); // grey.shade50

  /// Divider and separator color.
  static const Color divider = Color(0xFFE0E0E0); // grey.shade300

  /// Subtle divider for lighter separation.
  static const Color dividerLight = Color(0xFFEEEEEE); // grey.shade200

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT COLORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Primary text color.
  static const Color textPrimary = Color(0xFF212121); // grey.shade900

  /// Secondary text color (subtitles, captions).
  static const Color textSecondary = Color(0xFF757575); // grey.shade600

  /// Disabled text color.
  static const Color textDisabled = Color(0xFFBDBDBD); // grey.shade400

  /// Text on dark/colored backgrounds.
  static const Color textOnColor = Color(0xFFFFFFFF); // white

  // ─────────────────────────────────────────────────────────────────────────
  // BRAND COLORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Primary brand color — Used for primary actions, FABs, active states.
  static const Color primary = Color(0xFF4CAF50); // green

  /// Primary variant for hover/pressed states.
  static const Color primaryVariant = Color(0xFF388E3C); // green.shade700

  /// Admin-specific accent color.
  static const Color adminAccent = Color(0xFFFF9800); // orange
}
