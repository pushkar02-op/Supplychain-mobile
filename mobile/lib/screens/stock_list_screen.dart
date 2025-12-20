import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/stock_list_provider.dart';
import '../services/stock_service.dart'; // Still needed for update logic if we didn't migrate edit page yet, OR we can use repository for deleting.

class StockListScreen extends ConsumerWidget {
  const StockListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final stockListAsync = ref.watch(stockListProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('STOCK LIST')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final today = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(today.year - 1),
                      lastDate: today,
                    );
                    if (picked != null) {
                      ref.read(selectedDateProvider.notifier).state = picked;
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(selectedDate.toIso8601String().split('T')[0]),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () async {
                    final result = await context.push(
                      '/stock-entry',
                      extra: null,
                    );
                    if (result == true) {
                      ref.invalidate(stockListProvider);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Stock'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: stockListAsync.when(
                data: (stocks) {
                  if (stocks.isEmpty) {
                    return const Center(
                      child: Text('No stock entries found for this date'),
                    );
                  }
                  return ListView.builder(
                    itemCount: stocks.length,
                    itemBuilder: (context, index) {
                      final stock = stocks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('Item: ${stock['item']['name']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Qty: ${stock['quantity']} ${stock['unit']}',
                              ),
                              Text(
                                'Price: ₹${stock['price_per_unit']}/${stock['unit']}',
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                final result = await context.push(
                                  '/stock-entry',
                                  extra: stock,
                                );
                                if (result == true) {
                                  ref.invalidate(stockListProvider);
                                }
                              } else if (value == 'delete') {
                                _confirmDelete(context, ref, stock['id']);
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (err, stack) => Center(
                      child: Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int stockId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Stock Entry'),
            content: const Text('Are you sure you want to delete this entry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(stockListProvider.notifier).deleteStock(stockId);
    }
  }
}

