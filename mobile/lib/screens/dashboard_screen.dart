import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import '/core/dio_client.dart';

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
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
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
              label: 'Invoices',
              subtitle: 'Upload and manage invoices',
              route: '/invoices',
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
          ],
        ),
      ),
    );
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
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
