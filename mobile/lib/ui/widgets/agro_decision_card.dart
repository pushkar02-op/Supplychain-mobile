import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../semantics/agro_severity.dart';
import '../semantics/agro_status.dart';
import '../theme/agro_colors.dart';
import '../theme/agro_spacing.dart';
import '../theme/agro_typography.dart';
import 'agro_card.dart';

/// AGRO Decision Card — Read-only, intent-aware decision strip.
///
/// Encodes a system decision or status with explanation and provenance.
///
/// Usage:
/// ```dart
/// AgroDecisionCard(
///   status: AgroStatus.critical,
///   primaryMessage: 'Stock Level Critical',
///   secondaryMessage: 'Below safety stock threshold',
///   explanation: 'Immediate restocking required to prevent stockout.',
///   source: 'Inventory Monitor',
///   lastUpdated: DateTime.now(),
/// )
/// ```
class AgroDecisionCard extends StatelessWidget {
  /// The semantic status of the decision (determines styling).
  final AgroStatus status;

  /// The main headline message.
  final String primaryMessage;

  /// Optional supporting details.
  final String? secondaryMessage;

  /// Clear explanation of *why* this status exists.
  final String explanation;

  /// The source of this decision (e.g., 'System', 'Admin').
  final String source;

  /// Timestamp of when this decision was calculated.
  final DateTime lastUpdated;

  const AgroDecisionCard({
    Key? key,
    required this.status,
    required this.primaryMessage,
    this.secondaryMessage,
    required this.explanation,
    required this.source,
    required this.lastUpdated,
  }) : assert(primaryMessage.length > 0, 'Primary message must not be empty'),
       assert(explanation.length > 0, 'Explanation must not be empty'),
       assert(
         secondaryMessage == null || secondaryMessage != primaryMessage,
         'Secondary message must not equal primary message',
       ),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final severity = AgroSeverity.fromStatus(status);

    // Using AgroCard with zero padding to allow full-bleed background tint
    return AgroCard.outlined(
      padding: EdgeInsets.zero,
      borderColor: severity.borderColor.withValues(alpha: 0.5),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thin left accent bar (2px)
            Container(width: 2, color: severity.iconColor),
            // Main content area with tinted background
            Expanded(
              child: Container(
                color: severity.backgroundColor,
                padding: EdgeInsets.all(AgroSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Message
                    Text(
                      primaryMessage,
                      style: AgroTypography.emphasis.copyWith(
                        color: AgroColors.textPrimary,
                      ),
                    ),
                    // Secondary Message (Optional)
                    if (secondaryMessage != null) ...[
                      const SizedBox(height: AgroSpacing.xs),
                      Text(
                        secondaryMessage!,
                        style: AgroTypography.body.copyWith(
                          color: AgroColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AgroSpacing.sm),
                    // Explanation
                    Text(
                      explanation,
                      style: AgroTypography.caption.copyWith(
                        color: AgroColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AgroSpacing.md),
                    // Footer Divider and Metadata
                    const Divider(height: 1, color: AgroColors.divider),
                    const SizedBox(height: AgroSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          source.toUpperCase(),
                          style: AgroTypography.caption.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: AgroColors.textDisabled,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, HH:mm').format(lastUpdated),
                          style: AgroTypography.caption.copyWith(
                            fontSize: 10,
                            color: AgroColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
