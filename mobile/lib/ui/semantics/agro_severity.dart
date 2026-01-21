import 'package:flutter/material.dart';

import 'agro_status.dart';

/// AGRO Supply Chain — Severity Visual Mapping
///
/// Maps AgroStatus to visual styling (colors, icons).
/// This is the SINGLE SOURCE OF TRUTH for severity-based visuals.
///
/// Usage:
/// ```dart
/// final severity = AgroSeverity.fromStatus(AgroStatus.critical);
/// Container(color: severity.backgroundColor)
/// Icon(severity.icon, color: severity.iconColor)
/// ```
///
/// Rules:
/// - Never hardcode severity colors in screens
/// - Always use this mapping for consistency
/// - Colors come from AgroColors semantic definitions

/// Visual styling for a severity level.
class AgroSeverityStyle {
  /// Background color for containers/badges.
  final Color backgroundColor;

  /// Text color for labels on this background.
  final Color textColor;

  /// Border color for outlined elements.
  final Color borderColor;

  /// Icon to represent this severity.
  final IconData icon;

  /// Color for the icon.
  final Color iconColor;

  const AgroSeverityStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
  });
}

/// Severity visual mapping — single source of truth.
abstract class AgroSeverity {
  AgroSeverity._();

  // ─────────────────────────────────────────────────────────────────────────
  // PREDEFINED SEVERITY STYLES
  // ─────────────────────────────────────────────────────────────────────────

  /// Critical severity — Red, error icon.
  static const AgroSeverityStyle critical = AgroSeverityStyle(
    backgroundColor: Color(0xFFFFEBEE), // AgroColors.critical.background
    textColor: Color(0xFFC62828), // AgroColors.critical.text
    borderColor: Color(0xFFEF9A9A), // AgroColors.critical.border
    icon: Icons.error,
    iconColor: Color(0xFFC62828),
  );

  /// Major severity — Orange, warning icon.
  static const AgroSeverityStyle major = AgroSeverityStyle(
    backgroundColor: Color(0xFFFFF3E0), // AgroColors.warning.background
    textColor: Color(0xFFEF6C00), // AgroColors.warning.text
    borderColor: Color(0xFFFFCC80), // AgroColors.warning.border
    icon: Icons.warning,
    iconColor: Color(0xFFEF6C00),
  );

  /// Minor severity — Amber, visibility icon.
  static const AgroSeverityStyle minor = AgroSeverityStyle(
    backgroundColor: Color(0xFFFFFDE7), // AgroColors.caution.background
    textColor: Color(0xFFF9A825), // AgroColors.caution.text
    borderColor: Color(0xFFFFE082), // AgroColors.caution.border
    icon: Icons.visibility,
    iconColor: Color(0xFFF9A825),
  );

  /// Stable severity — Green, check icon.
  static const AgroSeverityStyle stable = AgroSeverityStyle(
    backgroundColor: Color(0xFFE8F5E9), // AgroColors.success.background
    textColor: Color(0xFF2E7D32), // AgroColors.success.text
    borderColor: Color(0xFFA5D6A7), // AgroColors.success.border
    icon: Icons.check_circle,
    iconColor: Color(0xFF2E7D32),
  );

  /// Info severity — Blue, info icon.
  static const AgroSeverityStyle info = AgroSeverityStyle(
    backgroundColor: Color(0xFFE3F2FD), // AgroColors.info.background
    textColor: Color(0xFF1565C0), // AgroColors.info.text
    borderColor: Color(0xFF90CAF9), // AgroColors.info.border
    icon: Icons.info_outline,
    iconColor: Color(0xFF1565C0),
  );

  /// Unknown/neutral severity — Grey, help icon.
  static const AgroSeverityStyle unknown = AgroSeverityStyle(
    backgroundColor: Color(0xFFFAFAFA), // AgroColors.neutral.background
    textColor: Color(0xFF424242), // AgroColors.neutral.text
    borderColor: Color(0xFFE0E0E0), // AgroColors.neutral.border
    icon: Icons.help_outline,
    iconColor: Color(0xFF757575),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // MAPPING FUNCTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get severity style from AgroStatus.
  static AgroSeverityStyle fromStatus(AgroStatus status) {
    switch (status) {
      case AgroStatus.critical:
        return critical;
      case AgroStatus.major:
        return major;
      case AgroStatus.minor:
        return minor;
      case AgroStatus.stable:
        return stable;
      case AgroStatus.info:
        return info;
      case AgroStatus.unknown:
        return unknown;
    }
  }

  /// Get severity style directly from a forecast signal string.
  static AgroSeverityStyle fromForecastSignal(String? signal) {
    return fromStatus(AgroStatusParser.fromForecastSignal(signal));
  }

  /// Get severity style directly from a drift severity string.
  static AgroSeverityStyle fromDriftSeverity(String? severity) {
    return fromStatus(AgroStatusParser.fromDriftSeverity(severity));
  }

  /// Get severity style directly from bill status string.
  static AgroSeverityStyle fromBillStatus(String? status) {
    return fromStatus(AgroStatusParser.fromBillStatus(status));
  }

  /// Get severity style directly from health status string.
  static AgroSeverityStyle fromHealthStatus(String? status) {
    return fromStatus(AgroStatusParser.fromHealthStatus(status));
  }
}
