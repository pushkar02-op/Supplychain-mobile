import 'package:flutter/material.dart';

import '../theme/agro_colors.dart';
import '../theme/agro_spacing.dart';
import '../theme/agro_typography.dart';

/// AGRO Empty State — Standard empty/zero-data state
///
/// Provides consistent empty state presentation across all screens.
///
/// Usage:
/// ```dart
/// AgroEmptyState(
///   icon: Icons.inventory_2_outlined,
///   title: 'No stock entries',
///   message: 'No stock entries for this date.',
///   actionLabel: 'Add stock entry',
///   onAction: () => context.push('/stock-entry'),
/// )
/// ```

/// A standard empty state widget.
class AgroEmptyState extends StatelessWidget {
  /// The icon to display.
  final IconData icon;

  /// The title text.
  final String title;

  /// Optional message text below the title.
  final String? message;

  /// Optional action button label.
  final String? actionLabel;

  /// Optional action button callback.
  final VoidCallback? onAction;

  /// Optional action button icon.
  final IconData? actionIcon;

  /// Icon size. Defaults to 64.
  final double iconSize;

  /// Icon color. Defaults to grey.
  final Color? iconColor;

  const AgroEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.iconSize = 64.0,
    this.iconColor,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must both be provided or both be null',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AgroColors.textDisabled;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AgroSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: effectiveIconColor),
            const SizedBox(height: AgroSpacing.lg),
            Text(
              title,
              style: AgroTypography.cardTitle.copyWith(
                color: AgroColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AgroSpacing.sm),
              Text(
                message!,
                style: AgroTypography.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AgroSpacing.lg),
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
