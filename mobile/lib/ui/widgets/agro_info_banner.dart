import 'package:flutter/material.dart';

import '../semantics/agro_severity.dart';
import '../semantics/agro_status.dart';
import '../theme/agro_shapes.dart';
import '../theme/agro_spacing.dart';
import '../theme/agro_typography.dart';

/// AGRO Info Banner — Informational/warning/neutral banners
///
/// Provides consistent banner styling for disclaimers, warnings, and info.
///
/// Usage:
/// ```dart
/// AgroInfoBanner.info(text: 'This is informational.')
/// AgroInfoBanner.warning(text: 'Attention needed!')
/// AgroInfoBanner.neutral(text: 'General note.')
/// ```

/// Banner variant determining styling.
enum AgroInfoBannerVariant {
  /// Informational — blue styling.
  info,

  /// Warning — orange styling.
  warning,

  /// Neutral — grey styling.
  neutral,

  /// Success — green styling.
  success,
}

/// A banner for displaying informational messages.
class AgroInfoBanner extends StatelessWidget {
  /// The banner text content.
  final String text;

  /// The banner variant.
  final AgroInfoBannerVariant variant;

  /// Optional custom icon (overrides default).
  final IconData? icon;

  /// Whether the banner can be dismissed.
  final bool dismissible;

  /// Callback when dismissed (required if dismissible is true).
  final VoidCallback? onDismiss;

  const AgroInfoBanner({
    super.key,
    required this.text,
    this.variant = AgroInfoBannerVariant.info,
    this.icon,
    this.dismissible = false,
    this.onDismiss,
  }) : assert(
         !dismissible || onDismiss != null,
         'onDismiss is required when dismissible is true',
       );

  /// Creates an info-styled banner.
  const AgroInfoBanner.info({
    super.key,
    required this.text,
    this.icon,
    this.dismissible = false,
    this.onDismiss,
  }) : variant = AgroInfoBannerVariant.info;

  /// Creates a warning-styled banner.
  const AgroInfoBanner.warning({
    super.key,
    required this.text,
    this.icon,
    this.dismissible = false,
    this.onDismiss,
  }) : variant = AgroInfoBannerVariant.warning;

  /// Creates a neutral-styled banner.
  const AgroInfoBanner.neutral({
    super.key,
    required this.text,
    this.icon,
    this.dismissible = false,
    this.onDismiss,
  }) : variant = AgroInfoBannerVariant.neutral;

  /// Creates a success-styled banner.
  const AgroInfoBanner.success({
    super.key,
    required this.text,
    this.icon,
    this.dismissible = false,
    this.onDismiss,
  }) : variant = AgroInfoBannerVariant.success;

  @override
  Widget build(BuildContext context) {
    // Map variant to status for severity styling
    AgroStatus status;
    IconData defaultIcon;

    switch (variant) {
      case AgroInfoBannerVariant.info:
        status = AgroStatus.info;
        defaultIcon = Icons.info_outline;
        break;
      case AgroInfoBannerVariant.warning:
        status = AgroStatus.major;
        defaultIcon = Icons.warning_amber_outlined;
        break;
      case AgroInfoBannerVariant.neutral:
        status = AgroStatus.unknown;
        defaultIcon = Icons.help_outline;
        break;
      case AgroInfoBannerVariant.success:
        status = AgroStatus.stable;
        defaultIcon = Icons.check_circle_outline;
        break;
    }

    final severity = AgroSeverity.fromStatus(status);
    final effectiveIcon = icon ?? defaultIcon;

    return Container(
      padding: const EdgeInsets.all(AgroSpacing.sm + 2), // 10px as per original
      decoration: BoxDecoration(
        color: severity.backgroundColor,
        borderRadius: AgroShapes.bannerRadius,
        border: Border.all(color: severity.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(effectiveIcon, size: 16, color: severity.iconColor),
          const SizedBox(width: AgroSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AgroTypography.disclaimer.copyWith(
                color: severity.textColor,
              ),
            ),
          ),
          if (dismissible) ...[
            const SizedBox(width: AgroSpacing.sm),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 16, color: severity.iconColor),
            ),
          ],
        ],
      ),
    );
  }
}
