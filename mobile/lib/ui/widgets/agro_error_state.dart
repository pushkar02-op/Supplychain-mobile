import 'package:flutter/material.dart';

import '../semantics/agro_severity.dart';
import '../semantics/agro_status.dart';
import '../theme/agro_spacing.dart';
import '../theme/agro_typography.dart';

/// AGRO Error State — Standard error presentation with optional retry
///
/// Provides consistent error state presentation across all screens.
///
/// Usage:
/// ```dart
/// AgroErrorState(
///   title: 'Could not load data',
///   message: 'Please check your connection and try again.',
///   onRetry: () => ref.invalidate(dataProvider),
/// )
/// ```

/// A standard error state widget.
class AgroErrorState extends StatelessWidget {
  /// The error title.
  final String title;

  /// Optional error message with details.
  final String? message;

  /// Optional retry callback. If provided, shows a retry button.
  final VoidCallback? onRetry;

  /// Retry button label. Defaults to 'Retry'.
  final String retryLabel;

  /// Icon to display. Defaults to error_outline.
  final IconData icon;

  /// Icon size. Defaults to 48.
  final double iconSize;

  const AgroErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.error_outline,
    this.iconSize = 48.0,
  });

  /// Creates an error state for network/load failures.
  const AgroErrorState.loadFailed({
    super.key,
    String? customTitle,
    this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
  }) : title = customTitle ?? 'Could not load data',
       icon = Icons.cloud_off,
       iconSize = 48.0;

  /// Creates an error state for general failures.
  const AgroErrorState.general({
    super.key,
    String? customTitle,
    this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
  }) : title = customTitle ?? 'Something went wrong',
       icon = Icons.error_outline,
       iconSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final severity = AgroSeverity.fromStatus(AgroStatus.critical);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AgroSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: severity.iconColor),
            const SizedBox(height: AgroSpacing.md),
            Text(
              title,
              style: AgroTypography.cardTitle.copyWith(
                color: severity.textColor,
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
            if (onRetry != null) ...[
              const SizedBox(height: AgroSpacing.lg),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
