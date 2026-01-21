import 'package:flutter/material.dart';

import '../semantics/agro_severity.dart';
import '../semantics/agro_status.dart';
import '../theme/agro_typography.dart';

/// AGRO Key-Value Row — Label–value rows for metrics and details
///
/// Provides consistent key-value display across inventory, forecasting, etc.
///
/// Usage:
/// ```dart
/// AgroKeyValueRow(label: 'Current Quantity', value: '100 kg')
/// AgroKeyValueRow.emphasis(label: 'Total', value: '₹5,000')
/// AgroKeyValueRow.status(label: 'Status', value: 'Critical', status: AgroStatus.critical)
/// ```

/// Emphasis level for key-value rows.
enum AgroKeyValueEmphasis {
  /// Normal emphasis — standard styling.
  normal,

  /// Emphasized — bold value.
  emphasis,
}

/// A label-value row with consistent styling.
class AgroKeyValueRow extends StatelessWidget {
  /// The label text (left side).
  final String label;

  /// The value text (right side).
  final String value;

  /// Emphasis level for the value.
  final AgroKeyValueEmphasis emphasis;

  /// Optional status to color the value.
  final AgroStatus? status;

  /// Whether the value can wrap to multiple lines.
  final bool multiline;

  /// Custom value widget (overrides value text and status).
  final Widget? valueWidget;

  const AgroKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = AgroKeyValueEmphasis.normal,
    this.status,
    this.multiline = false,
    this.valueWidget,
  });

  /// Creates a row with emphasized (bold) value.
  const AgroKeyValueRow.emphasis({
    super.key,
    required this.label,
    required this.value,
    this.status,
    this.multiline = false,
    this.valueWidget,
  }) : emphasis = AgroKeyValueEmphasis.emphasis;

  /// Creates a row with status-colored value.
  const AgroKeyValueRow.status({
    super.key,
    required this.label,
    required this.value,
    required AgroStatus this.status,
    this.multiline = false,
    this.valueWidget,
  }) : emphasis = AgroKeyValueEmphasis.normal;

  @override
  Widget build(BuildContext context) {
    // Determine value text style
    TextStyle valueStyle;
    if (emphasis == AgroKeyValueEmphasis.emphasis) {
      valueStyle = AgroTypography.emphasis;
    } else {
      valueStyle = AgroTypography.body.copyWith(fontWeight: FontWeight.w600);
    }

    // Apply status color if provided
    if (status != null) {
      final severity = AgroSeverity.fromStatus(status!);
      valueStyle = valueStyle.copyWith(color: severity.textColor);
    }

    final valueContent =
        valueWidget ??
        Text(
          value,
          style: valueStyle,
          textAlign: multiline ? TextAlign.start : TextAlign.end,
          maxLines: multiline ? null : 1,
          overflow: multiline ? null : TextOverflow.ellipsis,
        );

    if (multiline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AgroTypography.bodySecondary),
          const SizedBox(height: 4),
          valueContent,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(label, style: AgroTypography.bodySecondary),
        ),
        const SizedBox(width: 8),
        Flexible(flex: 3, child: valueContent),
      ],
    );
  }
}
