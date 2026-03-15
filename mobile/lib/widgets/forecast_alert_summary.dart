import 'package:flutter/material.dart';

import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';

class ForecastAlertSummary extends StatelessWidget {
  final int critical;
  final int warning;
  final VoidCallback? onTap;

  const ForecastAlertSummary({
    super.key,
    required this.critical,
    required this.warning,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard.outlined(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forecast Alerts', style: AgroTypography.sectionTitle),
          const SizedBox(height: AgroSpacing.sm),
          _row('Stockout < 3 days', critical, AgroColors.critical.text),
          const SizedBox(height: AgroSpacing.xs),
          _row('Stockout < 7 days', warning, AgroColors.warning.text),
        ],
      ),
    );
  }

  Widget _row(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AgroSpacing.xs,
        horizontal: AgroSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AgroShapes.cardRadius,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AgroTypography.captionEmphasis),
          Text(
            value.toString(),
            style: AgroTypography.emphasis.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
