import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';

/// "More" hub screen - provides access to secondary and admin screens.
class MoreHubScreen extends ConsumerWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.value?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(AgroSpacing.screenPadding),
        children: [
          // Reference Section
          Padding(
            padding: EdgeInsets.only(
              bottom: AgroSpacing.sm,
              top: AgroSpacing.sm,
            ),
            child: Text('Reference', style: AgroTypography.sectionTitle),
          ),
          _NavTile(
            icon: Icons.analytics_outlined,
            title: 'Inventory',
            subtitle: 'View current stock levels',
            route: '/inventory',
          ),
          _NavTile(
            icon: Icons.receipt_outlined,
            title: 'Mart Bills',
            subtitle: 'Upload and manage invoices',
            route: '/mart-bills',
          ),
          _NavTile(
            icon: Icons.category_outlined,
            title: 'Items',
            subtitle: 'Manage item catalog',
            route: '/items',
          ),
          _NavTile(
            icon: Icons.link_outlined,
            title: 'Alias Mapping',
            subtitle: 'Map invoice items to master items',
            route: '/alias-mapping',
          ),
          _NavTile(
            icon: Icons.cancel_outlined,
            title: 'Rejections',
            subtitle: 'Track rejected items',
            route: '/rejection-list',
          ),

          SizedBox(height: AgroSpacing.xl),

          // Admin Section (only visible to admins)
          if (isAdmin) ...[
            Padding(
              padding: EdgeInsets.only(
                bottom: AgroSpacing.sm,
                top: AgroSpacing.sm,
              ),
              child: Text('Administration', style: AgroTypography.sectionTitle),
            ),
            _NavTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Inventory Health',
              subtitle: 'Ledger health and drift detection',
              route: '/admin/ledger/health',
              isAdmin: true,
            ),
            _NavTile(
              icon: Icons.compare_arrows_outlined,
              title: 'Drift Report',
              subtitle: 'View detailed reconciliation',
              route: '/admin/ledger/drift',
              isAdmin: true,
            ),
            _NavTile(
              icon: Icons.build_outlined,
              title: 'UOM Diagnostics',
              subtitle: 'Items with missing configurations',
              route: '/admin/uom-diagnostics',
              isAdmin: true,
            ),
          ],

          SizedBox(height: AgroSpacing.xl),

          // Logout
          _LogoutTile(ref: ref),
        ],
      ),
    );
  }
}

/// Navigation tile widget for the More hub.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool isAdmin;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isAdmin ? AgroColors.adminAccent : AgroColors.primary;
    final borderColor =
        isAdmin
            ? const Color(0xFFFFCC80) // orange.shade200
            : AgroColors.dividerLight;

    return Card(
      margin: EdgeInsets.only(bottom: AgroSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AgroShapes.cardRadius,
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: AgroTypography.cardTitle),
        subtitle: Text(subtitle, style: AgroTypography.cardSubtitle),
        trailing: Icon(Icons.chevron_right, color: AgroColors.textDisabled),
        onTap: () => context.push(route),
      ),
    );
  }
}

/// Logout tile widget with destructive styling.
class _LogoutTile extends StatelessWidget {
  final WidgetRef ref;

  const _LogoutTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    // Use critical severity for destructive action
    final severity = AgroSeverity.fromStatus(AgroStatus.critical);

    return Card(
      margin: EdgeInsets.only(bottom: AgroSpacing.sm),
      elevation: 0,
      color: severity.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: AgroShapes.cardRadius,
        side: BorderSide(color: severity.borderColor),
      ),
      child: ListTile(
        leading: Icon(Icons.logout, color: severity.iconColor),
        title: Text(
          'Logout',
          style: AgroTypography.cardTitle.copyWith(color: severity.textColor),
        ),
        onTap: () => _confirmLogout(context),
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
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}
