import 'package:flutter/material.dart';

import '../../services/item_service.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';

class MapItemsScreen extends StatefulWidget {
  final int billId;
  final List<Map<String, dynamic>> unmappedItems;

  const MapItemsScreen({
    super.key,
    required this.billId,
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
  }

  // PRESERVED EXACTLY: Save mapping logic
  Future<void> _saveMapping(_MapRow row) async {
    if (row.selectedMasterItem == null) return;

    final payload = {
      "alias_code": row.aliasCode,
      "alias_name": row.aliasName,
      // "alias_unit": row.aliasUnit, // Preserved commented out from original
      "master_item_id": row.selectedMasterItem!['id'],
    };

    final saved = await ItemService.saveAliasMapping(payload);
    if (saved != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mapping saved for ${row.aliasName}")),
      );
      setState(() {
        rows.remove(row);
      });
    }
  }

  // PRESERVED EXACTLY: Create new item logic
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

  // PRESERVED EXACTLY: Text input dialog
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
    // PRESERVED EXACTLY: Completion logic
    if (rows.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ItemService.reprocessStock(widget.billId);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("All mappings saved.")));
        Navigator.pop(context, true);
      });
    }

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text("Map Mart Bill Items"),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(AgroSpacing.lg),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return _MappingCard(
            row: row,
            onSave: () => _saveMapping(row),
            onCreateNew: () => _createNewItem(row),
            // Pass simple callback to force rebuild on selection change
            onSelectionChanged: (val) {
              setState(() {
                row.selectedMasterItem = row.suggestedItems.firstWhere(
                  (e) => e["id"] == val,
                );
              });
            },
          );
        },
      ),
    );
  }
}

class _MappingCard extends StatelessWidget {
  final _MapRow row;
  final VoidCallback onSave;
  final VoidCallback onCreateNew;
  final ValueChanged<int?> onSelectionChanged;

  const _MappingCard({
    required this.row,
    required this.onSave,
    required this.onCreateNew,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Using AgroCard for consistent styling
    return AgroCard.outlined(
      padding: EdgeInsets.all(AgroSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Alias: ${row.aliasName}",
            style: AgroTypography.cardTitle.copyWith(fontSize: 15),
          ),
          SizedBox(height: AgroSpacing.xs),
          Text(
            "(Code: ${row.aliasCode}, Unit: ${row.aliasUnit})",
            style: AgroTypography.caption,
          ),
          SizedBox(height: AgroSpacing.md),
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
            onChanged: onSelectionChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              hintText: "Select Master Item",
            ),
          ),
          SizedBox(height: AgroSpacing.md),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onCreateNew,
                icon: const Icon(Icons.add),
                label: const Text("New Item"),
              ),
              SizedBox(width: AgroSpacing.md),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  // Use success color for Save Mapping to match "Green" semantic
                  backgroundColor: AgroColors.success.text,
                  foregroundColor: Colors.white,
                ),
                onPressed: onSave,
                icon: const Icon(Icons.save),
                label: const Text("Save Mapping"),
              ),
            ],
          ),
        ],
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
