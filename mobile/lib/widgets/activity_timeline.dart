import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/audit_provider.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import 'activity_timeline_item.dart';

class ActivityTimeline extends ConsumerWidget {
  const ActivityTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);

    return AgroCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Recent Activity', style: AgroTypography.sectionTitle),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/admin/audit'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: AgroSpacing.sm),
          activityAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AgroSpacing.sm),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Text(
              'Failed to load activity: $err',
              style: AgroTypography.caption,
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return const Text(
                  'No recent activity',
                  style: AgroTypography.caption,
                );
              }
              final visible = logs.take(5).toList();
              return Column(
                children: [
                  for (final log in visible)
                    ActivityTimelineItem(log: log),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
