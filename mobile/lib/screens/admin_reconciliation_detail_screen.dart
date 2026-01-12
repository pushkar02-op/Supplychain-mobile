import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_ledger_provider.dart';

class AdminReconciliationDetailScreen extends ConsumerWidget {
  final int itemId;
  final String itemName;

  const AdminReconciliationDetailScreen({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(reconciliationDetailProvider(itemId));

    return Scaffold(
      appBar: AppBar(title: Text(itemName)),
      body: detailAsync.when(
        data: (data) {
          final item = data['item'] as Map<String, dynamic>;
          final available = (data['available_stock'] as num).toDouble();
          final ledger = (data['ledger_stock'] as num).toDouble();
          final delta = (data['delta'] as num).toDouble();
          final txns = data['recent_transactions'] as List<dynamic>;
          final batches = data['batch_snapshot'] as List<dynamic>;
          final unit = item['unit'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Card(
                  elevation: 0,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildRow('Available (Batches)', '$available $unit'),
                        const SizedBox(height: 8),
                        _buildRow('Ledger (Transactions)', '$ledger $unit'),
                        const Divider(),
                        _buildRow(
                          'Net Drift',
                          '${delta > 0 ? "+" : ""}$delta $unit',
                          isBold: true,
                          color:
                              delta == 0
                                  ? Colors.green
                                  : (delta.abs() /
                                              (ledger == 0 ? 1 : ledger).abs() >
                                          0.05
                                      ? Colors.red
                                      : Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Batch Snapshot
                const Text(
                  'Batch Snapshot (Available)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (batches.isEmpty)
                  const Text('No active batches found.')
                else
                  ...batches.map((b) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text('Batch #${b['batch_id']}'),
                        subtitle: Text('Received: ${b['received_at']}'),
                        trailing: Text(
                          '${b['qty']} $unit',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // Recent Transactions
                const Text(
                  'Recent Transactions (Ledger)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  const Text('No transactions found.')
                else
                  ...txns.map((t) {
                    final isOut = t['type'] == 'OUT';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          isOut ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isOut ? Colors.red : Colors.green,
                          size: 16,
                        ),
                        title: Text('${t['type']} - ${t['ref']}'),
                        subtitle: Text(t['created_at']),
                        trailing: Text(
                          '${t['qty']} $unit',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
