import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_ledger_provider.dart';
import 'admin_reconciliation_detail_screen.dart';

class AdminInventoryDriftScreen extends ConsumerWidget {
  const AdminInventoryDriftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(driftReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drift Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(driftReportProvider.notifier).refresh(),
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) {
          if (report.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text('No drift detected.'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: report.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = report[index];
              return _DriftItemCard(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _DriftItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _DriftItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final delta = (item['delta'] as num?)?.toDouble() ?? 0.0;
    final severity = item['severity'] as String? ?? 'NONE';
    final itemName = item['item_name'] ?? 'Unknown';
    final itemId = item['item_id'] as int;
    final available = (item['available_stock'] as num?)?.toDouble() ?? 0.0;
    final ledger = (item['ledger_stock'] as num?)?.toDouble() ?? 0.0;

    // Severity Colors
    Color color;
    switch (severity) {
      case 'CRITICAL':
        color = Colors.red;
        break;
      case 'MAJOR':
        color = Colors.orange;
        break;
      case 'MINOR':
        color = Colors.amber;
        break;
      default:
        color = Colors.green;
    }

    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => AdminReconciliationDetailScreen(
                    itemId: itemId,
                    itemName: itemName,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      severity,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _RowInfo('Available (Batch)', '$available'),
              const SizedBox(height: 4),
              _RowInfo('Ledger', '$ledger'),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'NET DRIFT:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    delta > 0
                        ? '+${delta.toStringAsFixed(3)}'
                        : delta.toStringAsFixed(3),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _RowInfo(this.label, this.value, {this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: valueStyle),
      ],
    );
  }
}
