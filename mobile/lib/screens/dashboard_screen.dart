import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/providers/auth_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Operations Section
            Text(
              'Daily Operations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              context,
              icon: Icons.inventory_2,
              label: 'Stock',
              subtitle: 'Add and manage stock entries',
              route: '/stock-list',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              context,
              icon: Icons.assignment,
              label: 'Orders',
              subtitle: 'View and create daily orders',
              route: '/orders',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              context,
              icon: Icons.local_shipping,
              label: 'Dispatch',
              subtitle: 'Track dispatch entries',
              route: '/dispatch-entries',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              context,
              icon: Icons.receipt_long,
              label: 'Mart Bills',
              subtitle: 'Upload and manage mart bills',
              route: '/mart-bills',
              color: Colors.purple,
            ),
            const SizedBox(height: 24),

            // Reference Section
            Text(
              'Reference',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              context,
              icon: Icons.warehouse,
              label: 'Inventory',
              subtitle: 'View current stock levels',
              route: '/inventory',
              color: Colors.teal,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              context,
              icon: Icons.category,
              label: 'Items',
              subtitle: 'Manage item catalog',
              route: '/items',
              color: Colors.indigo,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              context,
              icon: Icons.cancel,
              label: 'Rejections',
              subtitle: 'Track rejected items',
              route: '/rejection-list',
              color: Colors.red,
            ),

            // Administration Section (Admin only)
            Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authProvider);
                final isAdmin = authState.value?.isAdmin ?? false;

                if (!isAdmin) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Administration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavCard(
                      context,
                      icon: Icons.health_and_safety,
                      label: 'Inventory Health',
                      subtitle: 'Monitor ledger status and drift',
                      route: '/admin/ledger/health',
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    _buildNavCard(
                      context,
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
      await ref.read(authProvider.notifier).logout();
    }
  }

  Widget _buildNavCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required String route,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
