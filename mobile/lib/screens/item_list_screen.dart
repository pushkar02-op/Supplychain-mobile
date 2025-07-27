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
  List<Map<String, dynamic>> unmappedInvoiceItems = [];
  bool isLoading = true;
  String error = '';
  int? selectedInvoiceItemId;
  int? selectedItemId;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final fetchedItems = await ItemService.fetchItems();
      final invoiceItems = await ItemService.fetchUnmappedAliases();
      setState(() {
        items = fetchedItems;
        unmappedInvoiceItems = invoiceItems;
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

  Future<void> _mapInvoiceItemToItem(int invoiceItemId, int itemId) async {
    await ItemService.mapAlias(invoiceItemId, itemId);
    _fetchItems();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice item mapped successfully')),
    );
  }

  void _showInvoiceMappingDialog() {
    selectedInvoiceItemId = null;
    selectedItemId = null;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Map Invoice Item to Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedInvoiceItemId,
                isExpanded: true,
                items:
                    unmappedInvoiceItems.map((inv) {
                      return DropdownMenuItem<int>(
                        value: inv['invoice_item_id'],
                        child: Text(
                          '${inv['item_name']} (${inv['item_code']})',
                        ),
                      );
                    }).toList(),
                onChanged: (val) => setState(() => selectedInvoiceItemId = val),
                decoration: const InputDecoration(
                  labelText: 'Unmapped Invoice Item',
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
                if (selectedInvoiceItemId != null && selectedItemId != null) {
                  _mapInvoiceItemToItem(
                    selectedInvoiceItemId!,
                    selectedItemId!,
                  );
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
      appBar: AppBar(
        title: const Text('Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: "Map Invoice Item",
            onPressed: _showInvoiceMappingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
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
