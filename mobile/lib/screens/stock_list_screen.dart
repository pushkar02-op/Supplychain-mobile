import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/stock_list_provider.dart';
import '../ui/widgets/agro_snack_bar.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/stock_history_sheet.dart';

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
                      final receivedQty = stock['quantity'];
                      final currentQty = stock['batch_quantity'] ?? receivedQty;
                      final unit = stock['unit'];
                      final isAdjusted =
                          (currentQty - receivedQty).abs() > 0.001;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${stock['item']['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isAdjusted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Adjusted',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Received: $receivedQty $unit',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Current: $currentQty $unit',
                                    style: TextStyle(
                                      color:
                                          isAdjusted
                                              ? Colors.orange.shade700
                                              : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight:
                                          isAdjusted
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '₹${stock['price_per_unit']}/$unit',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'history') {
                                final receivedQty = stock['quantity'] as num?;
                                final currentQty =
                                    (stock['batch_quantity'] as num?)
                                        ?.toDouble() ??
                                    receivedQty?.toDouble() ??
                                    0.0;
                                final unit = stock['unit'] ?? '';
                                final qtyLabel =
                                    'Current: ${currentQty.toStringAsFixed(1)} $unit';

                                StockHistorySheet.show(
                                  context,
                                  stockEntryId: stock['id'],
                                  itemName: stock['item']['name'],
                                  currentQtyLabel: qtyLabel,
                                );
                              } else if (value == 'correct') {
                                final result = await context.push(
                                  '/stock-entry',
                                  extra: {'mode': 'correct', 'stock': stock},
                                );
                                if (result == true) {
                                  ref.invalidate(stockListProvider);
                                }
                              } else if (value == 'void') {
                                _confirmVoid(context, ref, stock);
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'history',
                                    child: Text('View history'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'correct',
                                    child: Text('Correct stock'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'void',
                                    child: Text('Void receipt'),
                                  ),
                                ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const StaticSkeletonList(itemCount: 5),
                error:
                    (err, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[300],
                          ),
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
      floatingActionButton: Semantics(
        label: 'add-stock-action',
        button: true,
        onTap: () async {
          final result = await context.push('/stock-entry', extra: null);
          if (result == true) {
            ref.invalidate(stockListProvider);
          }
        },
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await context.push('/stock-entry', extra: null);
            if (result == true) {
              ref.invalidate(stockListProvider);
            }
          },
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Receive Stock'),
          heroTag: 'stock-add-fab',
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
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'add-first-stock-entry-action',
            button: true,
            onTap: () async {
              final result = await context.push('/stock-entry', extra: null);
              if (result == true) {
                ref.invalidate(stockListProvider);
              }
            },
            child: TextButton.icon(
              onPressed: () async {
                final result = await context.push('/stock-entry', extra: null);
                if (result == true) {
                  ref.invalidate(stockListProvider);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add your first stock entry'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stock,
  ) async {
    final itemName = stock['item']?['name'] ?? 'Unknown';
    final qty = stock['quantity'];
    final unit = stock['unit'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Void Stock Entry'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are about to void this receipt:'),
                const SizedBox(height: 8),
                Text(
                  '$itemName — $qty $unit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'This will reverse the inventory addition. This action cannot be undone.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Void Entry'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await ref.read(stockListProvider.notifier).deleteStock(stock['id']);
        if (context.mounted) {
          AgroSnackBar.success(context, 'Stock entry voided successfully');
        }
      } catch (e) {
        if (context.mounted) {
          // Extract message if it's a known format, otherwise show generic
          String message = e.toString().replaceAll('Exception: ', '');
          if (message.contains('Deletion would orphan')) {
            await showDialog(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Cannot void this receipt'),
                    content: const Text(
                      'Items from this receipt have already been used (for rejection, dispatch, or correction).\n\n'
                      'To protect inventory accuracy, those actions must be reversed first before this receipt can be voided.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );
          } else {
            AgroSnackBar.error(context, message);
          }
        }
      }
    }
  }
}
