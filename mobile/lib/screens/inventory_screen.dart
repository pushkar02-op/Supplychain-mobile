import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

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
  Map<String, List<Map<String, dynamic>>> _txnCache = {};
  Map<String, bool> _expanded = {};

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

  Future<void> _fetchTransactions(int itemId, String? unit) async {
    final key = _txnKey(itemId, unit);
    if (_txnCache.containsKey(key)) return;
    try {
      final txns = await InventoryService.fetchTransactions(
        itemId: itemId,
        unit: null,
      );
      setState(() => _txnCache[key] = txns);
    } catch (_) {
      setState(() => _txnCache[key] = []);
    }
  }

  String _txnKey(int itemId, String? unit) => '$itemId|${unit ?? ""}';

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
                _txnCache.clear();
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
                _txnCache.clear();
              });
              _fetchInventory();
            },
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTxnRow(Map<String, dynamic> txn) {
    final isIn = txn['txn_type'] == 'IN';
    return ListTile(
      dense: true,
      leading: Icon(
        isIn ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIn ? Colors.green : Colors.red,
      ),
      title: Text(
        '${txn['txn_type']} — ${txn['raw_qty']} ${txn['raw_unit']}',
        style: TextStyle(
          color: isIn ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        'Date: ${txn['created_at'] ?? ''}\n'
        'Batch: ${txn['batch_id'] ?? '-'} | Ref: ${txn['ref_type'] ?? ''} ${txn['ref_id'] ?? ''}\n'
        'Remarks: ${txn['remarks'] ?? ''}',
      ),
      trailing: Text(
        (txn['base_qty'] as num?)?.toStringAsFixed(2) ?? '',
        style: TextStyle(
          color: isIn ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Your Screen Title'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
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
                      ? const Center(child: Text('No inventory records found'))
                      : ListView.builder(
                        itemCount: _inventory.length,
                        itemBuilder: (context, i) {
                          final inv = _inventory[i];
                          final itemId = inv['item_id'] as int;
                          final unit = inv['unit'] as String?;
                          final txnKey = _txnKey(itemId, unit);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ExpansionTile(
                              key: PageStorageKey(txnKey),
                              initiallyExpanded: _expanded[txnKey] ?? false,
                              onExpansionChanged: (val) async {
                                setState(() => _expanded[txnKey] = val);
                                if (val) {
                                  await _fetchTransactions(itemId, unit);
                                }
                              },
                              title: Text(inv['name'] ?? 'Unknown Item'),
                              subtitle: Text('Unit: ${inv['unit']}'),
                              trailing: Text(
                                (inv['current_stock'] as num?)?.toStringAsFixed(
                                      2,
                                    ) ??
                                    '0',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              children: [
                                if (!(_txnCache[txnKey]?.isNotEmpty ?? false))
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else
                                  ..._txnCache[txnKey]!
                                      .map(_buildTxnRow)
                                      .toList(),
                              ],
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
}
