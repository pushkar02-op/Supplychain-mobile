import 'package:flutter/material.dart';
import '../../services/item_service.dart';

class MapItemsScreen extends StatefulWidget {
  final int invoiceId;
  final List<Map<String, dynamic>> unmappedItems;

  const MapItemsScreen({
    super.key,
    required this.invoiceId,
    required this.unmappedItems,
  });

  @override
  State<MapItemsScreen> createState() => _MapItemsScreenState();
}

class _MapItemsScreenState extends State<MapItemsScreen> {
  late List<_MapRow> rows;

  @override
  void initState() {
    super.initState();
    rows = widget.unmappedItems.map((e) => _MapRow.fromJson(e)).toList();
    print(widget.unmappedItems);
  }

  Future<void> _saveMapping(_MapRow row) async {
    if (row.selectedMasterItem == null) return;

    final payload = {
      "alias_code": row.aliasCode,
      "alias_name": row.aliasName,
      "alias_unit": row.aliasUnit,
      "master_item_id": row.selectedMasterItem!['id'],
    };

    final saved = await ItemService.saveAliasMapping(payload);
    if (saved != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mapping saved for ${row.aliasName}")),
      );
      setState(() {
        rows.remove(row);
      });
    }
  }

  Future<void> _createNewItem(_MapRow row) async {
    final name = await _showTextInputDialog(context, 'New Item Name');
    if (name == null || name.trim().isEmpty) return;

    final newItem = await ItemService.createItem({
      "name": name.trim(),
      "default_unit": row.aliasUnit,
    });

    if (newItem != null) {
      setState(() {
        row.suggestedItems.add(newItem);
        row.selectedMasterItem = newItem;
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
    // as soon as we've removed the last row, reprocess + pop once
    if (rows.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ItemService.reprocessStock(widget.invoiceId);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("All mappings saved.")));
        Navigator.pop(context, true);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Map Invoice Items")),
      body: ListView.builder(
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
                    "Alias: ${row.aliasName} (Code: ${row.aliasCode}, ${row.aliasUnit})",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: row.selectedMasterItem?["id"],
                    items:
                        row.suggestedItems
                            .map(
                              (e) => DropdownMenuItem<int>(
                                value: e["id"],
                                child: Text(e["name"]),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      setState(() {
                        row.selectedMasterItem = row.suggestedItems.firstWhere(
                          (e) => e["id"] == val,
                        );
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      hintText: "Select Master Item",
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
                        onPressed: () => _saveMapping(row),
                        icon: const Icon(Icons.save),
                        label: const Text("Save Mapping"),
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

class _MapRow {
  final String aliasCode;
  final String aliasName;
  final String aliasUnit;
  final List<Map<String, dynamic>> suggestedItems;
  Map<String, dynamic>? selectedMasterItem;

  _MapRow({
    required this.aliasCode,
    required this.aliasName,
    required this.aliasUnit,
    required this.suggestedItems,
    this.selectedMasterItem,
  });

  factory _MapRow.fromJson(Map<String, dynamic> json) {
    return _MapRow(
      aliasCode: json['item_code'] as String,
      aliasName: json['item_name'] as String,
      aliasUnit: json['uom'] as String,
      suggestedItems: List<Map<String, dynamic>>.from(
        json['suggested_items'] ?? [],
      ),
    );
  }
}
