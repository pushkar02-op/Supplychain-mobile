import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/inventory_service.dart';
import 'admin_inventory_drift_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _items = [];
  List<String> _units = [];
  int? _selectedItemId;
  String? _selectedUnit;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _fetchInventory();
  }

  Future<void> _loadFilters() async {
    try {
      final items = await InventoryService.fetchItemOptions();
      final units = await InventoryService.fetchUnitOptions();
      setState(() {
        _items = items;
        _units = units;
      });
    } catch (_) {}
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await InventoryService.fetchInventory(
        itemId: _selectedItemId,
        unit: _selectedUnit,
      );
      setState(() => _inventory = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedItemId,
            decoration: const InputDecoration(labelText: 'Item'),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('All Items'),
              ),
              ..._items.map(
                (item) => DropdownMenuItem(
                  value: item['id'],
                  child: Text(item['name']),
                ),
              ),
            ],
            onChanged: (id) {
              setState(() {
                _selectedItemId = id;
              });
              _fetchInventory();
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedUnit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Units'),
              ),
              ..._units.map((u) => DropdownMenuItem(value: u, child: Text(u))),
            ],
            onChanged: (u) {
              setState(() {
                _selectedUnit = u;
              });
              _fetchInventory();
            },
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  void _showBatchBreakdown(int itemId, String itemName, String unit) {
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
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: InventoryService.fetchBatches(itemId),
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
                        final batches = snapshot.data ?? [];
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

  void _showItemDetail(Map<String, dynamic> item) {
    final itemId = item['item_id'] as int;
    final unit = item['unit'] as String?;
    final name = item['name'] as String;
    final ledgerStock = (item['current_stock'] as num?)?.toDouble() ?? 0.0;
    final availableStock = (item['available_stock'] as num?)?.toDouble() ?? 0.0;

    // Health Badge Logic
    final diff = (ledgerStock - availableStock).abs();
    final isHealthy = diff < 0.001;
    final isCritical = ledgerStock < 0; // Negative ledger

    String badgeLabel = isHealthy ? 'Healthy' : 'Drift';
    Color badgeColor = isHealthy ? Colors.green : Colors.orange;
    if (isCritical) {
      badgeLabel = 'Critical';
      badgeColor = Colors.red;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
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
                            color: badgeColor.withOpacity(0.1),
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
                                isHealthy ? Colors.green : Colors.orange,
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
                                  itemId,
                                  name,
                                  unit ?? '',
                                ),
                            icon: const Icon(Icons.layers_outlined, size: 18),
                            label: const Text('View Batch Breakdown'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: Colors.blue.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Stock Trend Section
                        FutureBuilder<Map<String, dynamic>>(
                          future: InventoryService.fetchItemSignals(itemId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const SizedBox.shrink();
                            final data = snapshot.data!;
                            final signals =
                                (data['signals'] as List<dynamic>?)
                                    ?.map((e) => e.toString())
                                    .toList() ??
                                [];
                            final l7 = (data['out_last_7d'] as num).toDouble();
                            final p7 = (data['out_prev_7d'] as num).toDouble();

                            String status = 'Normal';
                            Color statusColor = Colors.grey;
                            if (signals.contains('FAST_DEPLETING')) {
                              status = 'Fast Depleting';
                              statusColor = Colors.red;
                            } else if (signals.contains('LOW_STOCK')) {
                              status = 'Low Stock';
                              statusColor = Colors.orange;
                            } else if (signals.contains('STABLE')) {
                              status = 'Stable';
                              statusColor = Colors.green;
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
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.trending_up,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
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
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: statusColor,
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: InventoryService.fetchTransactions(
                        itemId: itemId,
                        unit: null,
                      ),
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
                        final txns = snapshot.data ?? [];
                        if (txns.isEmpty) {
                          return const Center(
                            child: Text('No transactions found'),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: txns.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) => _buildTxnRow(txns[i]),
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

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
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

  // Refined Transaction Row
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final isAdmin = ref.watch(authProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.orange,
                ),
                tooltip: 'Reconciliation (Admin Only)',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminInventoryDriftScreen(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFilters(),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                      : _inventory.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warehouse_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No inventory records found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: _inventory.length,
                        itemBuilder: (context, i) {
                          final inv = _inventory[i];
                          // available_stock might be missing if backend not updated, handle gracefully
                          final ledgerStock =
                              (inv['current_stock'] as num?)?.toDouble() ?? 0.0;
                          final availableStock =
                              (inv['available_stock'] as num?)?.toDouble() ??
                              0.0;
                          final unit = inv['unit'] ?? '';

                          // Phase 1 Badging (Drift/Critical)
                          final diff = (ledgerStock - availableStock).abs();
                          final isHealthy = diff < 0.001;
                          final isCritical = ledgerStock < 0;

                          // Signals (Phase 3)
                          final signals =
                              (inv['signals'] as List<dynamic>?)
                                  ?.map((e) => e.toString())
                                  .toList() ??
                              [];
                          String? signalLabel;
                          Color? signalColor;
                          if (signals.contains('FAST_DEPLETING')) {
                            signalLabel = 'Fast Depleting';
                            signalColor = Colors.red;
                          } else if (signals.contains('LOW_STOCK')) {
                            signalLabel = 'Low Stock';
                            signalColor = Colors.orange;
                          } else if (signals.contains('STABLE')) {
                            signalLabel = 'Stable';
                            signalColor = Colors.green;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showItemDetail(inv),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inv['name'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Unit: $unit',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (isHealthy)
                                          // Single line for healthy
                                          _buildCompactStat(
                                            'Available',
                                            '$availableStock $unit',
                                            Colors.green,
                                          )
                                        else ...[
                                          // Dual line for drift
                                          _buildCompactStat(
                                            'Available',
                                            '$availableStock $unit',
                                            Colors.blue,
                                          ),
                                          const SizedBox(height: 4),
                                          _buildCompactStat(
                                            'Ledger',
                                            '$ledgerStock $unit',
                                            Colors.orange,
                                          ),
                                          const SizedBox(height: 6),
                                          // Badge (Phase 1)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isCritical
                                                      ? Colors.red.withOpacity(
                                                        0.1,
                                                      )
                                                      : Colors.orange
                                                          .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color:
                                                    isCritical
                                                        ? Colors.red
                                                        : Colors.orange,
                                              ),
                                            ),
                                            child: Text(
                                              isCritical ? 'Critical' : 'Drift',
                                              style: TextStyle(
                                                color:
                                                    isCritical
                                                        ? Colors.red
                                                        : Colors.orange,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        // Signal Badge (Phase 3)
                                        if (signalLabel != null) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: signalColor!.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: signalColor,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                  color: signalColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  signalLabel,
                                                  style: TextStyle(
                                                    color: signalColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
