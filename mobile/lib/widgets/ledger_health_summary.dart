import 'package:flutter/material.dart';

import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_status_badge.dart';

class LedgerHealthSummary extends StatelessWidget {
  final String status;
  final int driftedBatches;
  final VoidCallback? onTap;

  const LedgerHealthSummary({
    super.key,
    required this.status,
    required this.driftedBatches,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = AgroStatusParser.fromHealthStatus(status);
    final badgeLabel =
        parsed == AgroStatus.stable ? 'Healthy' : 'Drift Detected';

    return AgroCard.outlined(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ledger Health', style: AgroTypography.sectionTitle),
          const SizedBox(height: AgroSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AgroStatusBadge.compact(
                status: parsed,
                label: badgeLabel,
              ),
              Text(
                'Drifted: $driftedBatches',
                style: AgroTypography.emphasis.copyWith(
                  color: parsed == AgroStatus.stable
                      ? AgroColors.success.text
                      : AgroColors.warning.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: AgroSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AgroSpacing.xs,
              horizontal: AgroSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AgroColors.surface,
              borderRadius: AgroShapes.cardRadius,
              border: Border.all(color: AgroColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Status', style: AgroTypography.captionEmphasis),
                Text(status, style: AgroTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
