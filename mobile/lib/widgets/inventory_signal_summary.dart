import 'package:flutter/material.dart';

import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';

class InventorySignalSummary extends StatelessWidget {
  final int stable;
  final int watch;
  final int critical;

  const InventorySignalSummary({
    super.key,
    required this.stable,
    required this.watch,
    required this.critical,
  });

  @override
  Widget build(BuildContext context) {
    final total = stable + watch + critical;
    return AgroCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Health', style: AgroTypography.sectionTitle),
          const SizedBox(height: AgroSpacing.sm),
          _row('Stable', stable, AgroColors.success.text),
          const SizedBox(height: AgroSpacing.xs),
          _row('Watch', watch, AgroColors.warning.text),
          const SizedBox(height: AgroSpacing.xs),
          _row('Critical', critical, AgroColors.critical.text),
          const SizedBox(height: AgroSpacing.xs),
          _row('Total', total, AgroColors.textSecondary),
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
