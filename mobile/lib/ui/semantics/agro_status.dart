/// AGRO Supply Chain — Status Definitions
///
/// Semantic status values used across the application.
/// These define INTENT, not visual appearance.
///
/// Usage:
/// ```dart
/// final status = AgroStatus.fromSignal('CRITICAL');
/// print(status.label); // "Critical"
/// ```
///
/// Rules:
/// - Statuses define meaning, not colors
/// - Use AgroSeverity to get visual styling for a status
library;

/// Enum representing system-wide status levels.
enum AgroStatus {
  /// Critical — Immediate action required.
  /// Examples: Stock out, negative inventory, system failure.
  critical,

  /// Major — Significant issue, attention needed soon.
  /// Examples: Reorder soon, major drift, incomplete operations.
  major,

  /// Minor — Noticeable but not urgent.
  /// Examples: Watch status, minor drift, adjustments made.
  minor,

  /// Stable — Normal, healthy state.
  /// Examples: Stable signal, verified bills, successful operations.
  stable,

  /// Info — Informational, no action required.
  /// Examples: Disclaimers, help text, neutral notifications.
  info,

  /// Unknown — Status cannot be determined.
  /// Examples: Missing data, pending calculation.
  unknown,
}

/// Extension providing labels and helper methods for AgroStatus.
extension AgroStatusExtension on AgroStatus {
  /// Human-readable label for this status.
  String get label {
    switch (this) {
      case AgroStatus.critical:
        return 'Critical';
      case AgroStatus.major:
        return 'Major';
      case AgroStatus.minor:
        return 'Minor';
      case AgroStatus.stable:
        return 'Stable';
      case AgroStatus.info:
        return 'Info';
      case AgroStatus.unknown:
        return 'Unknown';
    }
  }

  /// Whether this status requires user attention.
  bool get requiresAttention {
    return this == AgroStatus.critical || this == AgroStatus.major;
  }

  /// Whether this status is positive/healthy.
  bool get isPositive {
    return this == AgroStatus.stable;
  }
}

/// Helper class for parsing status from string values.
abstract class AgroStatusParser {
  AgroStatusParser._();

  /// Parse a forecast signal string to AgroStatus.
  /// Supports: CRITICAL, REORDER_SOON, WATCH, STABLE
  static AgroStatus fromForecastSignal(String? signal) {
    switch (signal?.toUpperCase()) {
      case 'CRITICAL':
        return AgroStatus.critical;
      case 'REORDER_SOON':
        return AgroStatus.major;
      case 'WATCH':
        return AgroStatus.minor;
      case 'STABLE':
        return AgroStatus.stable;
      default:
        return AgroStatus.unknown;
    }
  }

  /// Parse a drift severity string to AgroStatus.
  /// Supports: CRITICAL, MAJOR, MINOR, NONE
  static AgroStatus fromDriftSeverity(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL':
        return AgroStatus.critical;
      case 'MAJOR':
        return AgroStatus.major;
      case 'MINOR':
        return AgroStatus.minor;
      case 'NONE':
        return AgroStatus.stable;
      default:
        return AgroStatus.unknown;
    }
  }

  /// Parse a bill status string to AgroStatus.
  /// Supports: VERIFIED, NEEDS_REVIEW, PROCESSING, PENDING
  static AgroStatus fromBillStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'VERIFIED':
        return AgroStatus.stable;
      case 'NEEDS_REVIEW':
        return AgroStatus.major;
      case 'PROCESSING':
        return AgroStatus.info;
      case 'PENDING':
        return AgroStatus.minor;
      default:
        return AgroStatus.unknown;
    }
  }

  /// Get the display label for mart bill status.
  /// Returns exact copy as used in MartBillListScreen.
  static String getMartBillStatusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'VERIFIED':
        return 'Verified';
      case 'PROCESSING':
        return 'Processing';
      case 'NEEDS_REVIEW':
      default:
        return 'Review Needed';
    }
  }

  /// Parse ledger health status to AgroStatus.
  /// Supports: healthy, unhealthy
  static AgroStatus fromHealthStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'healthy':
        return AgroStatus.stable;
      case 'unhealthy':
        return AgroStatus.critical;
      default:
        return AgroStatus.unknown;
    }
  }

  /// Derive AgroStatus from order dispatch progress.
  /// Used where status is computed from ordered vs dispatched quantities.
  ///
  /// Returns:
  /// - stable: fully dispatched (dispatched >= ordered)
  /// - minor: partially dispatched (dispatched > 0)
  /// - critical: not dispatched yet (dispatched == 0)
  static AgroStatus fromOrderDispatchProgress(num ordered, num dispatched) {
    if (dispatched >= ordered) return AgroStatus.stable;
    if (dispatched > 0) return AgroStatus.minor;
    return AgroStatus.critical;
  }

  /// Get the display label for order dispatch progress.
  /// Returns exact copy as used in OrdersScreen.
  static String getOrderDispatchLabel(num ordered, num dispatched) {
    if (dispatched >= ordered) return 'Fully dispatched';
    if (dispatched > 0) return 'Partially dispatched';
    return 'Not dispatched yet';
  }
}
