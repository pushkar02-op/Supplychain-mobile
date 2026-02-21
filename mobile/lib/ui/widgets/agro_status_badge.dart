import 'package:flutter/material.dart';

import '../semantics/agro_severity.dart';
import '../semantics/agro_status.dart';
import '../theme/agro_shapes.dart';
import '../theme/agro_spacing.dart';
import '../theme/agro_typography.dart';

/// AGRO Status Badge — Unified status/severity badge
///
/// Displays a status indicator with consistent styling from AgroSeverity.
///
/// Usage:
/// ```dart
/// AgroStatusBadge(status: AgroStatus.critical)
/// AgroStatusBadge.compact(status: AgroStatus.stable)
/// AgroStatusBadge.fromSignal('REORDER_SOON')
/// ```

/// Size variants for the status badge.
enum AgroStatusBadgeSize {
  /// Compact badge — smaller padding, no icon.
  compact,

  /// Regular badge — standard padding with icon.
  regular,
}

/// A status badge with colors and icon from AgroSeverity.
class AgroStatusBadge extends StatelessWidget {
  /// The status to display.
  final AgroStatus status;

  /// The badge size variant.
  final AgroStatusBadgeSize size;

  /// Optional custom label (overrides status label).
  final String? label;

  /// Whether to show the icon.
  final bool showIcon;

  const AgroStatusBadge({
    super.key,
    required this.status,
    this.size = AgroStatusBadgeSize.regular,
    this.label,
    this.showIcon = true,
  });

  /// Creates a compact badge (smaller, no icon).
  const AgroStatusBadge.compact({super.key, required this.status, this.label})
    : size = AgroStatusBadgeSize.compact,
      showIcon = false;

  /// Creates a badge from a forecast signal string.
  factory AgroStatusBadge.fromSignal(
    String? signal, {
    Key? key,
    AgroStatusBadgeSize size = AgroStatusBadgeSize.regular,
    bool showIcon = true,
  }) {
    return AgroStatusBadge(
      key: key,
      status: AgroStatusParser.fromForecastSignal(signal),
      size: size,
      label: signal?.replaceAll('_', ' '),
      showIcon: showIcon,
    );
  }

  /// Creates a badge from a drift severity string.
  factory AgroStatusBadge.fromDriftSeverity(
    String? severity, {
    Key? key,
    AgroStatusBadgeSize size = AgroStatusBadgeSize.regular,
    bool showIcon = true,
  }) {
    return AgroStatusBadge(
      key: key,
      status: AgroStatusParser.fromDriftSeverity(severity),
      size: size,
      label: severity,
      showIcon: showIcon,
    );
  }

  /// Creates a badge from a mart bill status string.
  factory AgroStatusBadge.fromBillStatus(
    String? status, {
    Key? key,
    AgroStatusBadgeSize size = AgroStatusBadgeSize.regular,
    bool showIcon = true,
  }) {
    return AgroStatusBadge(
      key: key,
      status: AgroStatusParser.fromBillStatus(status),
      size: size,
      label: AgroStatusParser.getMartBillStatusLabel(status),
      showIcon: showIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final severity = AgroSeverity.fromStatus(status);
    final effectiveLabel = label ?? status.label;

    final isCompact = size == AgroStatusBadgeSize.compact;
    const horizontalPadding = AgroSpacing.sm;
    final verticalPadding = isCompact ? AgroSpacing.xs : AgroSpacing.sm;
    final iconSize = isCompact ? 12.0 : 14.0;
    final textStyle = AgroTypography.badgeText.copyWith(
      color: severity.textColor,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: severity.backgroundColor,
        borderRadius: AgroShapes.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && !isCompact) ...[
            Icon(severity.icon, size: iconSize, color: severity.iconColor),
            const SizedBox(width: AgroSpacing.xs),
          ],
          Text(effectiveLabel, style: textStyle),
        ],
      ),
    );
  }
}
