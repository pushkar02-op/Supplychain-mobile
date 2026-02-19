import 'package:flutter/material.dart';

import '../theme/agro_colors.dart';
import '../theme/agro_shapes.dart';
import '../theme/agro_spacing.dart';
import 'agro_key_value_row.dart';

/// AGRO Metrics Grid — Grid layout for metrics (forecasting, overview stats)
///
/// Provides a consistent grid of label-value pairs.
///
/// Usage:
/// ```dart
/// AgroMetricsGrid(
///   metrics: [
///     AgroMetric(label: 'Orders', value: '12'),
///     AgroMetric(label: 'Dispatches', value: '8'),
///   ],
/// )
/// ```

/// A single metric item for the grid.
class AgroMetric {
  /// The metric label.
  final String label;

  /// The metric value.
  final String value;

  const AgroMetric({required this.label, required this.value});
}

/// A grid layout for displaying metrics.
class AgroMetricsGrid extends StatelessWidget {
  /// The list of metrics to display.
  final List<AgroMetric> metrics;

  /// Number of columns. Defaults to 2.
  final int columns;

  /// Whether to show dividers between rows.
  final bool showDividers;

  /// Whether to wrap in a container with background.
  final bool withContainer;

  const AgroMetricsGrid({
    super.key,
    required this.metrics,
    this.columns = 2,
    this.showDividers = true,
    this.withContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (int i = 0; i < metrics.length; i++) {
      final metric = metrics[i];
      rows.add(AgroKeyValueRow(label: metric.label, value: metric.value));

      // Add divider between rows (but not after the last one)
      if (showDividers && i < metrics.length - 1) {
        rows.add(const Divider(height: AgroSpacing.lg));
      } else if (!showDividers && i < metrics.length - 1) {
        rows.add(const SizedBox(height: AgroSpacing.sm));
      }
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );

    if (!withContainer) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(AgroSpacing.md),
      decoration: BoxDecoration(
        color: AgroColors.surfaceVariant,
        borderRadius: AgroShapes.containerRadius,
        border: Border.all(color: AgroColors.dividerLight),
      ),
      child: content,
    );
  }
}
