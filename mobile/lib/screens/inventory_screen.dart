import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/inventory_service.dart';
import '../widgets/inventory_detail_sheet.dart';
import 'admin_inventory_drift_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
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
            _InventoryFilterBar(
              items: _items,
              units: _units,
              selectedItemId: _selectedItemId,
              selectedUnit: _selectedUnit,
              onItemChanged: (id) {
                setState(() => _selectedItemId = id);
                _fetchInventory();
              },
              onUnitChanged: (u) {
                setState(() => _selectedUnit = u);
                _fetchInventory();
              },
            ),
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
                              (inv['ledger_qty'] as num?)?.toDouble() ?? 0.0;
                          final availableStock =
                              (inv['state_qty'] as num?)?.toDouble() ?? 0.0;
                          final unit = inv['unit'] ?? '';
                          final status = inv['status'] as String? ?? 'HEALTHY';
                          final severity = inv['severity'] as String? ?? 'NONE';

                          final isHealthy = status == 'HEALTHY';
                          final isCritical = severity == 'CRITICAL';

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
                              onTap:
                                  () => InventoryDetailSheet.show(
                                    context,
                                    inv,
                                    isAdmin:
                                        ref.read(authProvider).value?.isAdmin ??
                                        false,
                                  ),
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

// ── Private Extracted Widgets ────────────────────────────────────────

class _InventoryFilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final List<String> units;
  final int? selectedItemId;
  final String? selectedUnit;
  final ValueChanged<int?> onItemChanged;
  final ValueChanged<String?> onUnitChanged;

  const _InventoryFilterBar({
    required this.items,
    required this.units,
    this.selectedItemId,
    this.selectedUnit,
    required this.onItemChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: selectedItemId,
            decoration: const InputDecoration(labelText: 'Item'),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('All Items'),
              ),
              ...items.map(
                (item) => DropdownMenuItem(
                  value: item['id'],
                  child: Text(item['name']),
                ),
              ),
            ],
            onChanged: onItemChanged,
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedUnit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Units'),
              ),
              ...units.map((u) => DropdownMenuItem(value: u, child: Text(u))),
            ],
            onChanged: onUnitChanged,
            isExpanded: true,
          ),
        ),
      ],
    );
  }
}
