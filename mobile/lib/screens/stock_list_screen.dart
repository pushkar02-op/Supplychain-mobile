import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
      appBar: AppBar(
        title: const Text('Stock'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
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
                  label: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
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
                    return _buildEmptyState(context, ref);
                  }
                  return ListView.builder(
                    itemCount: stocks.length,
                    itemBuilder: (context, index) {
                      final stock = stocks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            '${stock['item']['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load stock entries',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => ref.invalidate(stockListProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No stock entries for this date',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final result = await context.push('/stock-entry', extra: null);
              if (result == true) {
                ref.invalidate(stockListProvider);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add your first stock entry'),
          ),
        ],
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

