import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import 'quick_action_card.dart';

class OverviewQuickActions extends StatelessWidget {
  const OverviewQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.grid_view, color: AgroColors.textSecondary, size: 18),
            SizedBox(width: AgroSpacing.sm),
            Text('Quick Actions', style: AgroTypography.sectionTitle),
          ],
        ),
        const SizedBox(height: AgroSpacing.sm),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: AgroSpacing.sm,
          crossAxisSpacing: AgroSpacing.sm,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            QuickActionCard(
              icon: Icons.receipt_long,
              label: 'Orders',
              color: AgroColors.info.text,
              onTap: () => context.go('/orders'),
            ),
            QuickActionCard(
              icon: Icons.receipt_outlined,
              label: 'Mart Bills',
              color: AgroColors.primary,
              onTap: () => context.push('/mart-bills'),
            ),
            QuickActionCard(
              icon: Icons.inventory_2,
              label: 'Inventory',
              color: AgroColors.success.text,
              onTap: () => context.push('/inventory'),
            ),
            QuickActionCard(
              icon: Icons.list_alt,
              label: 'Items',
              color: AgroColors.info.text,
              onTap: () => context.push('/items'),
            ),
            QuickActionCard(
              icon: Icons.local_shipping,
              label: 'Dispatch',
              color: AgroColors.warning.text,
              onTap: () => context.go('/dispatch'),
            ),
            QuickActionCard(
              icon: Icons.cancel_outlined,
              label: 'Rejections',
              color: AgroColors.caution.text,
              onTap: () => context.push('/rejection-list'),
            ),
          ],
        ),
      ],
    );
  }
}
