import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session_controller.dart';
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
    final session = ref.watch(sessionProvider);
    final canManageUsers = session.canManageUsers;

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
        padding: const EdgeInsets.all(AgroSpacing.screenPadding),
        children: [
          const Padding(
            padding: EdgeInsets.only(
              bottom: AgroSpacing.sm,
              top: AgroSpacing.sm,
            ),
            child: Text('Workspace', style: AgroTypography.sectionTitle),
          ),
          const _WarehouseTile(),
          const SizedBox(height: AgroSpacing.xl),

          // Reference Section
          const Padding(
            padding: EdgeInsets.only(
              bottom: AgroSpacing.sm,
              top: AgroSpacing.sm,
            ),
            child: Text('Reference', style: AgroTypography.sectionTitle),
          ),
          const _NavTile(
            icon: Icons.analytics_outlined,
            title: 'Inventory',
            subtitle: 'View current stock levels',
            route: '/inventory',
          ),
          const _NavTile(
            icon: Icons.receipt_outlined,
            title: 'Mart Bills',
            subtitle: 'Upload and manage invoices',
            route: '/mart-bills',
          ),
          const _NavTile(
            icon: Icons.category_outlined,
            title: 'Items',
            subtitle: 'Manage item catalog',
            route: '/items',
          ),
          const _NavTile(
            icon: Icons.link_outlined,
            title: 'Alias Mapping',
            subtitle: 'Map invoice items to master items',
            route: '/alias-mapping',
          ),
          const _NavTile(
            icon: Icons.cancel_outlined,
            title: 'Rejections',
            subtitle: 'Track rejected items',
            route: '/rejection-list',
          ),

          const SizedBox(height: AgroSpacing.xl),

          // Admin Section (only visible to admins)
          if (canManageUsers) ...[
            const Padding(
              padding: EdgeInsets.only(
                bottom: AgroSpacing.sm,
                top: AgroSpacing.sm,
              ),
              child: Text('Administration', style: AgroTypography.sectionTitle),
            ),
            const _NavTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Inventory Health',
              subtitle: 'Ledger health and drift detection',
              route: '/admin/ledger/health',
              canManageUsers: true,
            ),
            const _NavTile(
              icon: Icons.compare_arrows_outlined,
              title: 'Drift Report',
              subtitle: 'View detailed reconciliation',
              route: '/admin/ledger/drift',
              canManageUsers: true,
            ),
            const _NavTile(
              icon: Icons.build_outlined,
              title: 'UOM Diagnostics',
              subtitle: 'Items with missing configurations',
              route: '/admin/uom-diagnostics',
              canManageUsers: true,
            ),
            const _NavTile(
              icon: Icons.people_outlined,
              title: 'Users',
              subtitle: 'Manage users and roles',
              route: '/admin/users',
              canManageUsers: true,
            ),
            const _NavTile(
              icon: Icons.store_outlined,
              title: 'Mart Management',
              subtitle: 'Create, edit, and deactivate marts',
              route: '/admin/marts',
              canManageUsers: true,
            ),
            const _NavTile(
              icon: Icons.warehouse_outlined,
              title: 'Warehouse Management',
              subtitle: 'Maintain warehouses and financial locks',
              route: '/admin/warehouses',
              canManageUsers: true,
            ),
            const _NavTile(
              icon: Icons.straighten_outlined,
              title: 'Unit Management',
              subtitle: 'Create, edit, and deactivate units',
              route: '/admin/uoms',
              canManageUsers: true,
            ),
            const _NavTile(
              icon: Icons.history_outlined,
              title: 'Audit Logs',
              subtitle: 'View system activity history',
              route: '/admin/audit-logs',
              canManageUsers: true,
            ),
          ],

          const SizedBox(height: AgroSpacing.xl),

          // Logout
          _LogoutTile(ref: ref),
        ],
      ),
    );
  }
}

class _WarehouseTile extends ConsumerWidget {
  const _WarehouseTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final warehouses = session.warehouses ?? const [];
    final activeWarehouseId = session.warehouseId;
    String? activeWarehouseName;
    String? activeWarehouseCode;
    for (final warehouse in warehouses) {
      if (warehouse.id == activeWarehouseId) {
        activeWarehouseName = warehouse.name;
        activeWarehouseCode = warehouse.displayCode;
        break;
      }
    }
    final subtitle =
        activeWarehouseName == null
            ? 'No active warehouse selected'
            : '$activeWarehouseName${activeWarehouseCode == null || activeWarehouseCode.isEmpty ? '' : ' ($activeWarehouseCode)'}';

    return Card(
      margin: const EdgeInsets.only(bottom: AgroSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AgroShapes.cardRadius,
        side: const BorderSide(color: AgroColors.dividerLight),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.warehouse_outlined,
          color: AgroColors.primary,
        ),
        title: const Text('Warehouse', style: AgroTypography.cardTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle, style: AgroTypography.cardSubtitle),
            const SizedBox(height: 2),
            Text(
              '${warehouses.length} accessible workspace${warehouses.length == 1 ? '' : 's'}',
              style: AgroTypography.caption,
            ),
          ],
        ),
        trailing: const Icon(
          Icons.lock_outline,
          color: AgroColors.textDisabled,
        ),
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
  final bool canManageUsers;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.canManageUsers = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        canManageUsers ? AgroColors.adminAccent : AgroColors.primary;
    final borderColor =
        canManageUsers
            ? const Color(0xFFFFCC80) // orange.shade200
            : AgroColors.dividerLight;

    return Card(
      margin: const EdgeInsets.only(bottom: AgroSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AgroShapes.cardRadius,
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: AgroTypography.cardTitle),
        subtitle: Text(subtitle, style: AgroTypography.cardSubtitle),
        trailing: const Icon(
          Icons.chevron_right,
          color: AgroColors.textDisabled,
        ),
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
      margin: const EdgeInsets.only(bottom: AgroSpacing.sm),
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
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}
