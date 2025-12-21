import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_ledger_provider.dart';

class AdminInventoryHealthScreen extends ConsumerWidget {
  const AdminInventoryHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(ledgerHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Ledger Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(ledgerHealthProvider.notifier).refresh(),
          ),
        ],
      ),
      body: healthAsync.when(
        data: (data) => _buildBody(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'unknown';
    final totalBatches = data['total_batches'] ?? 0;
    final driftedCount = data['drifted_batches'] ?? 0;
    final negativeCount = data['negative_stock_batches'] ?? 0;

    final isHealthy = status == 'healthy';
    final statusColor = isHealthy ? Colors.green : Colors.red;
    final statusIcon = isHealthy ? Icons.check_circle : Icons.warning_amber_rounded;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          Card(
            color: statusColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(statusIcon, size: 48, color: statusColor),
                  const SizedBox(height: 16),
                  Text(
                    'System Status: ${status.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Metrics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricCard(
                title: 'Total Batches',
                value: totalBatches.toString(),
                icon: Icons.inventory_2,
                color: Colors.blue,
              ),
              _MetricCard(
                title: 'Drifted Batches',
                value: driftedCount.toString(),
                icon: Icons.compare_arrows,
                color: driftedCount > 0 ? Colors.red : Colors.green,
              ),
              _MetricCard(
                title: 'Negative Stock',
                value: negativeCount.toString(),
                icon: Icons.trending_down,
                color: negativeCount > 0 ? Colors.red : Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Action Button
          if (!isHealthy)
            FilledButton.icon(
              onPressed: () => context.push('/admin/ledger/drift'),
              icon: const Icon(Icons.list_alt),
              label: const Text('View Detailed Drift Report'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
            )
          else
             const Center(
               child: Text(
                 'All systems nominal. No reconciliation actions required.',
                 style: TextStyle(color: Colors.grey),
               ),
             ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
