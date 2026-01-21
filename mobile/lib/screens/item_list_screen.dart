import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/item_service.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> unmappedBillItems = [];
  bool isLoading = true;
  String error = '';
  int? selectedBillItemId;
  int? selectedItemId;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final fetchedItems = await ItemService.fetchItems();
      final billItems = await ItemService.fetchUnmappedMartBillItems();
      setState(() {
        items = fetchedItems;
        unmappedBillItems = billItems;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteItem(int id) async {
    await ItemService.deleteItem(id);
    _fetchItems();
  }

  Future<void> _mapBillItemToItem(int billItemId, int itemId) async {
    await ItemService.mapAlias(billItemId, itemId);
    _fetchItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mart Bill item mapped successfully')),
    );
  }

  void _showMappingDialog() {
    selectedBillItemId = null;
    selectedItemId = null;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Map Mart Bill Item to Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedBillItemId,
                isExpanded: true,
                items:
                    unmappedBillItems.map((inv) {
                      return DropdownMenuItem<int>(
                        value: inv['invoice_item_id'],
                        child: Text(
                          '${inv['item_name']} (${inv['item_code']})',
                        ),
                      );
                    }).toList(),
                onChanged: (val) => setState(() => selectedBillItemId = val),
                decoration: const InputDecoration(
                  labelText: 'Unmapped Mart Bill Item',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedItemId,
                isExpanded: true,
                items:
                    items.map((item) {
                      return DropdownMenuItem<int>(
                        value: item['id'],
                        child: Text(item['name']),
                      );
                    }).toList(),
                onChanged: (val) => setState(() => selectedItemId = val),
                decoration: const InputDecoration(labelText: 'Select Item'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedBillItemId != null && selectedItemId != null) {
                  _mapBillItemToItem(selectedBillItemId!, selectedItemId!);
                  Navigator.pop(context);
                }
              },
              child: const Text('Map'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Items'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Map Mart Bill Items',
            onPressed: _showMappingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Item',
            onPressed: () async {
              final ok = await context.push('/item-edit');
              if (ok == true) _fetchItems();
            },
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
              ? Center(child: Text(error))
              : items.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No items in catalog',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await context.push('/item-edit');
                        if (ok == true) _fetchItems();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add your first item'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final aliases = List<Map<String, dynamic>>.from(
                    item['aliases'] ?? [],
                  );
                  final conversions = List<Map<String, dynamic>>.from(
                    item['conversions'] ?? [],
                  );
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ExpansionTile(
                      title: Text(item['name']),
                      subtitle: Text(
                        'Default UOM: ${item['default_uom_code'] ?? 'N/A'}',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Aliases:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Wrap(
                                spacing: 6,
                                children:
                                    aliases.isNotEmpty
                                        ? aliases
                                            .map(
                                              (a) => Chip(
                                                label: Text(
                                                  '${a['alias_name']} (${a['alias_code']})',
                                                ),
                                              ),
                                            )
                                            .toList()
                                        : [const Text('No aliases')],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Conversions:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              conversions.isNotEmpty
                                  ? Column(
                                    children:
                                        conversions.map((c) {
                                          return Row(
                                            children: [
                                              Text(
                                                '1 ${item['default_uom_code'] ?? ''} = ',
                                              ),
                                              Text(
                                                '${c['conversion_factor']} ${c['target_unit']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                  )
                                  : const Text('No conversions'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.visibility,
                                      size: 18,
                                    ),
                                    label: const Text('View Details'),
                                    onPressed: () {
                                      context.push('/item-detail', extra: item);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit',
                                    onPressed: () async {
                                      final ok = await context.push(
                                        '/item-edit',
                                        extra: item,
                                      );
                                      if (ok == true) _fetchItems();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteItem(item['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
