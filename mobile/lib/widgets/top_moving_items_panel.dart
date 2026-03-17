import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/top_moving_items_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';

class TopMovingItemsPanel extends ConsumerWidget {
  const TopMovingItemsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(topMovingItemsProvider);

    return AgroCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Moving Items', style: AgroTypography.sectionTitle),
          const SizedBox(height: AgroSpacing.sm),
          asyncItems.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AgroSpacing.sm),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Text(
              'Failed to load top moving items: $err',
              style: AgroTypography.caption,
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Text(
                  'No movement today',
                  style: AgroTypography.caption,
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == items.length - 1 ? 0 : AgroSpacing.xs,
                      ),
                      child: _TopMovingItemRow(
                        rank: i + 1,
                        name: items[i].itemName,
                        totalOut: items[i].totalOut,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopMovingItemRow extends StatelessWidget {
  final int rank;
  final String name;
  final double totalOut;

  const _TopMovingItemRow({
    required this.rank,
    required this.name,
    required this.totalOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AgroSpacing.xs,
        horizontal: AgroSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AgroColors.surfaceVariant,
        borderRadius: AgroShapes.cardRadius,
        border: Border.all(color: AgroColors.dividerLight),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AgroColors.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: AgroTypography.captionEmphasis,
              ),
            ),
          ),
          const SizedBox(width: AgroSpacing.sm),
          Expanded(
            child: Text(name, style: AgroTypography.captionEmphasis),
          ),
          Text(
            totalOut.toStringAsFixed(2),
            style: AgroTypography.emphasis.copyWith(
              color: AgroColors.warning.text,
            ),
          ),
        ],
      ),
    );
  }
}
