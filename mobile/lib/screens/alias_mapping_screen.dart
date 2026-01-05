import 'package:flutter/material.dart';

import '../services/item_service.dart';

class AliasMappingScreen extends StatefulWidget {
  const AliasMappingScreen({super.key});

  @override
  State<AliasMappingScreen> createState() => _AliasMappingScreenState();
}

class _AliasMappingScreenState extends State<AliasMappingScreen> {
  List<_AliasRow> rows = [];
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final aliases = await ItemService.fetchUnmappedMartBillItems();
      final allItems = await ItemService.fetchItems();

      setState(() {
        rows = aliases.map((e) => _AliasRow.fromJson(e)).toList();
        items = allItems;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _mapAlias(_AliasRow row) async {
    if (row.selectedItemId == null) return;

    await ItemService.mapAlias(row.id, row.selectedItemId!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Mapped ${row.aliasName} successfully")),
    );
    setState(() {
      rows.remove(row);
    });
  }

  Future<void> _createNewItem(_AliasRow row) async {
    final name = await _showTextInputDialog(context, 'New Item Name');
    if (name == null || name.trim().isEmpty) return;

    final newItem = await ItemService.createItem({
      "name": name.trim(),
      "default_unit": row.aliasUnit,
    });

    if (newItem != null) {
      setState(() {
        items.add(newItem);
        row.selectedItemId = newItem["id"];
      });
    }
  }

  Future<String?> _showTextInputDialog(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: "Enter item name"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map Aliases to Items")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
              ? Center(child: Text(error))
              : rows.isEmpty
              ? const Center(child: Text("All aliases are mapped."))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${row.aliasName} (${row.aliasCode}, ${row.aliasUnit})",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: row.selectedItemId,
                            items:
                                items
                                    .map(
                                      (e) => DropdownMenuItem<int>(
                                        value: e['id'],
                                        child: Text(e['name']),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() {
                                row.selectedItemId = val;
                              });
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              hintText: "Select Item",
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _createNewItem(row),
                                icon: const Icon(Icons.add),
                                label: const Text("New Item"),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () => _mapAlias(row),
                                icon: const Icon(Icons.save),
                                label: const Text("Map"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _AliasRow {
  final int id;
  final String aliasCode;
  final String aliasName;
  final String aliasUnit;
  int? selectedItemId;

  _AliasRow({
    required this.id,
    required this.aliasCode,
    required this.aliasName,
    required this.aliasUnit,
    this.selectedItemId,
  });

  factory _AliasRow.fromJson(Map<String, dynamic> json) {
    return _AliasRow(
      id: json['id'],
      aliasCode: json['alias_code'],
      aliasName: json['alias_name'],
      aliasUnit: json['uom'],
    );
  }
}
