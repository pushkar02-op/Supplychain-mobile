import 'package:flutter/material.dart';

import '../../services/item_service.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';

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
        error = ''; // Clear error on success
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  // PRESERVED EXACTLY: Map alias logic
  Future<void> _mapAlias(_AliasRow row) async {
    if (row.selectedItemId == null) return;

    await ItemService.mapAlias(row.id, row.selectedItemId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Mapped ${row.aliasName} successfully")),
    );
    setState(() {
      rows.remove(row);
    });
  }

  // PRESERVED EXACTLY: Create new item logic
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
    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text("Map Aliases to Items"),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error.isNotEmpty) {
      return Center(
        child: AgroErrorState.loadFailed(message: error, onRetry: _loadData),
      );
    }

    if (rows.isEmpty) {
      return const Center(
        child: AgroEmptyState(
          icon: Icons.check_circle_outline,
          title: "All aliases are mapped.",
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AgroSpacing.lg),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return _AliasMappingCard(
          row: row,
          items: items,
          onMap: () => _mapAlias(row),
          onCreateNew: () => _createNewItem(row),
          onSelectionChanged: (val) {
            setState(() {
              row.selectedItemId = val;
            });
          },
        );
      },
    );
  }
}

class _AliasMappingCard extends StatelessWidget {
  final _AliasRow row;
  final List<Map<String, dynamic>> items;
  final VoidCallback onMap;
  final VoidCallback onCreateNew;
  final ValueChanged<int?> onSelectionChanged;

  const _AliasMappingCard({
    required this.row,
    required this.items,
    required this.onMap,
    required this.onCreateNew,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard.outlined(
      padding: EdgeInsets.all(AgroSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(row.aliasName, style: AgroTypography.cardTitle),
              ),
            ],
          ),
          const SizedBox(height: AgroSpacing.xs),
          Text(
            "(${row.aliasCode}, ${row.aliasUnit})",
            style: AgroTypography.caption,
          ),
          const SizedBox(height: AgroSpacing.md),
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
            onChanged: onSelectionChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              hintText: "Select Item",
            ),
          ),
          const SizedBox(height: AgroSpacing.md),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onCreateNew,
                icon: const Icon(Icons.add),
                label: const Text("New Item"),
              ),
              const SizedBox(width: AgroSpacing.md),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  // Use success color for Map action to match "Green" semantic
                  backgroundColor: AgroColors.success.text,
                  foregroundColor: Colors.white,
                ),
                onPressed: onMap,
                icon: const Icon(Icons.save),
                label: const Text("Map"),
              ),
            ],
          ),
        ],
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
