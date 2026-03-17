import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session_controller.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AgroSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Operations Section
            const Text('Daily Operations', style: AgroTypography.sectionTitle),
            const SizedBox(height: AgroSpacing.md),
            const _NavCard(
              icon: Icons.inventory_2,
              label: 'Stock',
              subtitle: 'Add and manage stock entries',
              route: '/stock',
              color: Colors.green,
            ),
            const SizedBox(height: AgroSpacing.md),
            const _NavCard(
              icon: Icons.assignment,
              label: 'Orders',
              subtitle: 'View and create daily orders',
              route: '/orders',
              color: Colors.blue,
            ),
            const SizedBox(height: AgroSpacing.md),
            const _NavCard(
              icon: Icons.local_shipping,
              label: 'Dispatch',
              subtitle: 'Track dispatch entries',
              route: '/dispatch',
              color: Colors.orange,
            ),
            const SizedBox(height: AgroSpacing.md),
            const _NavCard(
              icon: Icons.receipt_long,
              label: 'Mart Bills',
              subtitle: 'Upload and manage mart bills',
              route: '/mart-bills',
              color: Colors.purple,
            ),
            const SizedBox(height: AgroSpacing.xl),

            // Reference Section
            const Text('Reference', style: AgroTypography.sectionTitle),
            const SizedBox(height: AgroSpacing.md),
            const _NavCard(
              icon: Icons.warehouse,
              label: 'Inventory',
              subtitle: 'View current stock levels',
              route: '/inventory',
              color: Colors.teal,
            ),
            const SizedBox(height: AgroSpacing.md),
            const _NavCard(
              icon: Icons.category,
              label: 'Items',
              subtitle: 'Manage item catalog',
              route: '/items',
              color: Colors.indigo,
            ),
            const SizedBox(height: AgroSpacing.md),
            const _NavCard(
              icon: Icons.cancel,
              label: 'Rejections',
              subtitle: 'Track rejected items',
              route: '/rejection-list',
              color: Colors.red,
            ),

            // Administration Section (Admin only)
            Consumer(
              builder: (context, ref, child) {
                final canManageUsers = ref.watch(
                  sessionProvider.select((session) => session.canManageUsers),
                );

                if (!canManageUsers) return const SizedBox.shrink();

                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AgroSpacing.xl),
                    Text('Administration', style: AgroTypography.sectionTitle),
                    SizedBox(height: AgroSpacing.md),
                    _NavCard(
                      icon: Icons.health_and_safety,
                      label: 'Inventory Health',
                      subtitle: 'Monitor ledger status and drift',
                      route: '/admin/ledger/health',
                      color: Colors.redAccent,
                    ),
                    SizedBox(height: AgroSpacing.md),
                    _NavCard(
                      icon: Icons.rule_rounded,
                      label: 'UOM Diagnostics',
                      subtitle: 'View configuration risks',
                      route: '/admin/uom-diagnostics',
                      color: Colors.orange,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}

/// Navigation card widget using Agro UI foundation.
/// Replaces the old _buildNavCard helper method.
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final Color color;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard.outlined(
      onTap: () => context.push(route),
      child: Row(
        children: [
          // Icon container with color tint
          Container(
            padding: const EdgeInsets.all(AgroSpacing.md),
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                (color.r * 255).round(),
                (color.g * 255).round(),
                (color.b * 255).round(),
                0.1,
              ),
              borderRadius: AgroShapes.cardRadius,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AgroSpacing.lg),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AgroTypography.cardTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AgroTypography.cardSubtitle),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AgroColors.textDisabled),
        ],
      ),
    );
  }
}
