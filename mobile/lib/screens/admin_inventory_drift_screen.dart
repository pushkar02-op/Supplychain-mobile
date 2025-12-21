import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_ledger_provider.dart';

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
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
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
    final drift = (item['drift'] as num?)?.toDouble() ?? 0.0;
    final status = item['status'] as String? ?? 'unknown';
    
    final isNegative = status == 'negative';
    final cardColor = isNegative ? Colors.orange.shade50 : Colors.red.shade50;
    final borderColor = isNegative ? Colors.orange : Colors.red;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor.withOpacity(0.5)),
      ),
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
                    item['item_name'] ?? 'Unknown Item',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(),
            _RowInfo('Batch ID', '#${item['batch_id']}'),
            const SizedBox(height: 4),
            _RowInfo('Cached Qty', '${item['batch_qty_raw']} ${item['batch_unit_raw']}'),
            const SizedBox(height: 4),
            _RowInfo(
              'Base Qty',
              '${(item['batch_qty_base'] as num).toStringAsFixed(3)} ${item['base_unit']}',
              valueStyle: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _RowInfo(
              'Ledger Qty',
              '${(item['ledger_qty'] as num).toStringAsFixed(3)} ${item['base_unit']}',
              valueStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NET DRIFT:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  drift > 0 ? '+${drift.toStringAsFixed(3)}' : drift.toStringAsFixed(3),
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
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
