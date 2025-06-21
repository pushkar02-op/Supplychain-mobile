import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await InventoryService.fetchInventory();
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
      appBar: AppBar(title: const Text('Inventory')),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(inv['name'] ?? 'Unknown Item'),
                        subtitle: Text('Unit: ${inv['unit']}'),
                        trailing: Text(
                          (inv['current_stock'] as num?)?.toStringAsFixed(2) ??
                              '0',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
