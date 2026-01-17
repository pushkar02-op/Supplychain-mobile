import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

/// "More" hub screen - provides access to secondary and admin screens.
class MoreHubScreen extends ConsumerWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.value?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Reference Section
          _buildSectionHeader('Reference'),
          _buildNavTile(
            context,
            icon: Icons.analytics_outlined,
            title: 'Inventory',
            subtitle: 'View current stock levels',
            route: '/inventory',
          ),
          _buildNavTile(
            context,
            icon: Icons.receipt_outlined,
            title: 'Mart Bills',
            subtitle: 'Upload and manage invoices',
            route: '/mart-bills',
          ),
          _buildNavTile(
            context,
            icon: Icons.category_outlined,
            title: 'Items',
            subtitle: 'Manage item catalog',
            route: '/items',
          ),
          _buildNavTile(
            context,
            icon: Icons.link_outlined,
            title: 'Alias Mapping',
            subtitle: 'Map invoice items to master items',
            route: '/alias-mapping',
          ),
          _buildNavTile(
            context,
            icon: Icons.cancel_outlined,
            title: 'Rejections',
            subtitle: 'Track rejected items',
            route: '/rejection-list',
          ),

          const SizedBox(height: 24),

          // Admin Section (only visible to admins)
          if (isAdmin) ...[
            _buildSectionHeader('Administration'),
            _buildNavTile(
              context,
              icon: Icons.health_and_safety_outlined,
              title: 'Inventory Health',
              subtitle: 'Ledger health and drift detection',
              route: '/admin/ledger/health',
              isAdmin: true,
            ),
            _buildNavTile(
              context,
              icon: Icons.compare_arrows_outlined,
              title: 'Drift Report',
              subtitle: 'View detailed reconciliation',
              route: '/admin/ledger/drift',
              isAdmin: true,
            ),
            _buildNavTile(
              context,
              icon: Icons.build_outlined,
              title: 'UOM Diagnostics',
              subtitle: 'Items with missing configurations',
              route: '/admin/uom-diagnostics',
              isAdmin: true,
            ),
          ],

          const SizedBox(height: 24),

          // Logout
          _buildLogoutTile(context, ref),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    bool isAdmin = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAdmin ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: isAdmin ? Colors.orange : Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => context.push(route),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: ListTile(
        leading: Icon(Icons.logout, color: Colors.red.shade700),
        title: Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
          ),
        ),
        onTap: () async {
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
        },
      ),
    );
  }
}
