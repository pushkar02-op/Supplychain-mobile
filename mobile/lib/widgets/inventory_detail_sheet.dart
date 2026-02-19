import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_provider.dart';
import '../screens/admin_reconciliation_detail_screen.dart';

/// Full-screen bottom sheet showing inventory item details.
///
/// Includes stock stats, batch breakdown, signals, and recent transactions.
/// Extracted from `InventoryScreen._showItemDetail` for readability.
class InventoryDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> item;
  final bool isAdmin;

  const InventoryDetailSheet({
    super.key,
    required this.item,
    required this.isAdmin,
  });

  /// Convenience method to show this sheet as a modal bottom sheet.
  static void show(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool isAdmin,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => InventoryDetailSheet(item: item, isAdmin: isAdmin),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = item['item_id'] as int;
    final unit = item['unit'] as String?;
    final name = item['name'] as String;
    final detailFuture = ref
        .read(inventoryListProvider.notifier)
        .fetchDetail(itemId);
    final ledgerStock = (item['ledger_qty'] as num?)?.toDouble() ?? 0.0;
    final availableStock = (item['state_qty'] as num?)?.toDouble() ?? 0.0;
    final status = item['status'] as String? ?? 'HEALTHY';
    final severity = item['severity'] as String? ?? 'NONE';

    // Health Badge Logic (Standardized via Backend)
    String badgeLabel = status == 'HEALTHY' ? 'Healthy' : 'Drift';
    Color badgeColor = status == 'HEALTHY' ? Colors.green : Colors.orange;

    if (severity == 'CRITICAL') {
      badgeLabel = 'Critical';
      badgeColor = Colors.red;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Unit: $unit',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: badgeColor),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Stats
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Available Stock',
                                '$availableStock $unit',
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Ledger Balance',
                                '$ledgerStock $unit',
                                status == 'HEALTHY'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                () => _showBatchBreakdown(
                                  context,
                                  ref,
                                  itemId,
                                  name,
                                  unit ?? '',
                                ),
                            icon: const Icon(Icons.layers_outlined, size: 18),
                            label: const Text('View Batch Breakdown'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: Colors.blue.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        if (status != 'HEALTHY' && isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              AdminReconciliationDetailScreen(
                                                itemId: itemId,
                                                itemName: name,
                                              ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.rebase_edit, size: 18),
                                label: const Text('Admin Reconciliation'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange.shade800,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Stock Trend Section
                        FutureBuilder<Map<String, dynamic>>(
                          future: detailFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final data = Map<String, dynamic>.from(
                              snapshot.data!['signals'] as Map,
                            );
                            final signals =
                                (data['signals'] as List<dynamic>?)
                                    ?.map((e) => e.toString())
                                    .toList() ??
                                [];
                            final l7 = (data['out_last_7d'] as num).toDouble();
                            final p7 = (data['out_prev_7d'] as num).toDouble();

                            String trendStatus = 'Normal';
                            Color trendColor = Colors.grey;
                            if (signals.contains('FAST_DEPLETING')) {
                              trendStatus = 'Fast Depleting';
                              trendColor = Colors.red;
                            } else if (signals.contains('LOW_STOCK')) {
                              trendStatus = 'Low Stock';
                              trendColor = Colors.orange;
                            } else if (signals.contains('STABLE')) {
                              trendStatus = 'Stable';
                              trendColor = Colors.green;
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Stock Trend (Last 14 days)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '7d OUT',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            '$l7 $unit',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Prev 7d OUT',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            '$p7 $unit',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Status',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: trendColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              trendStatus,
                                              style: TextStyle(
                                                color: trendColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  FutureBuilder<Map<String, dynamic>>(
                    future: detailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      final txns = List<Map<String, dynamic>>.from(
                        snapshot.data!['transactions'] as List,
                      );
                      if (txns.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('No transactions found')),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txns.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) => _buildTxnRow(txns[i]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnRow(Map<String, dynamic> txn) {
    final isIn = txn['txn_type'] == 'IN';
    final refType = txn['ref_type'] as String?;
    final refId = txn['ref_id'] as int?;

    String label = 'Transaction';
    String subLabel = '';

    switch (refType) {
      case 'stock_entry':
        label = 'Stock Received';
        subLabel = 'Stock Entry #$refId';
        break;
      case 'dispatch_entry':
        label = 'Dispatched';
        subLabel = 'Order/Dispatch #$refId';
        break;
      case 'dispatch_reversal':
        label = 'Dispatch Reversal';
        subLabel = 'Ref #$refId';
        break;
      case 'manual_adjustment':
        label = 'Manual Adjustment';
        break;
      default:
        label = refType ?? 'Unknown';
        subLabel = refId != null ? '#$refId' : '';
    }

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: isIn ? Colors.green.shade50 : Colors.red.shade50,
        child: Icon(
          isIn ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIn ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '$subLabel\n${txn['created_at']?.toString().split('.').first ?? ''}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${txn['raw_qty']} ${txn['raw_unit']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showBatchBreakdown(
    BuildContext context,
    WidgetRef ref,
    int itemId,
    String itemName,
    String unit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.8,
            minChildSize: 0.4,
            expand: false,
            builder: (ctx, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Batch Breakdown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              itemName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: ref
                          .read(inventoryListProvider.notifier)
                          .fetchDetail(itemId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final batches = List<Map<String, dynamic>>.from(
                          snapshot.data!['batches'] as List,
                        );
                        if (batches.isEmpty) {
                          return const Center(child: Text('No batches found'));
                        }

                        // FIFO Sort: Oldest received_at first
                        batches.sort((a, b) {
                          final dateA =
                              DateTime.tryParse(a['received_at'] ?? '') ??
                              DateTime.now();
                          final dateB =
                              DateTime.tryParse(b['received_at'] ?? '') ??
                              DateTime.now();
                          return dateA.compareTo(dateB);
                        });

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: batches.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final batch = batches[i];
                            final qty =
                                (batch['quantity'] as num?)?.toDouble() ?? 0.0;
                            final isZero = qty <= 0.001;

                            return ListTile(
                              dense: true,
                              tileColor: isZero ? Colors.grey[50] : null,
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Batch #${batch['id']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isZero ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '$qty ${batch['unit']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isZero
                                              ? Colors.grey
                                              : Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Received: ${batch['received_at']?.toString().split("T").first ?? "Unknown"}',
                                style: TextStyle(
                                  color:
                                      isZero
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}
