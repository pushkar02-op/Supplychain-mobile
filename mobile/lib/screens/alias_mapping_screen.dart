import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/item_service.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_snack_bar.dart';

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

  // Alias metrics (Read-Only, Observational)
  List<Map<String, dynamic>> aliasMetrics = [];

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
      final metrics = await ItemService.fetchAliasMetrics();

      setState(() {
        rows = aliases.map((e) => _AliasRow.fromJson(e)).toList();
        items = allItems;
        aliasMetrics = metrics;
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
    AgroSnackBar.success(context, 'Mapped ${row.aliasName} successfully');
    setState(() {
      rows.remove(row);
    });
  }

  Future<void> _createNewItem(_AliasRow row) async {
    // Navigate to ItemManagementScreen for full guardrail flow
    final newItem = await context.push<Map<String, dynamic>>(
      '/item-edit',
      extra: {'name': '', 'default_uom_code': row.aliasUnit},
    );

    if (newItem != null) {
      if (!mounted) return;
      setState(() {
        // Add to items list if not already there
        if (!items.any((i) => i['id'] == newItem['id'])) {
          items.add(newItem);
        }
        row.selectedItemId = newItem['id'];
      });
      // Optionally map immediately logic could go here, but user can click Map.
    }
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
        // Find seen_count for this alias (by matching alias_name)
        final metric = aliasMetrics.firstWhere(
          (m) =>
              (m['alias_name'] ?? '').toString().toLowerCase() ==
              row.aliasName.toLowerCase(),
          orElse: () => {'seen_count': null},
        );
        final seenCount = metric['seen_count'];
        return _AliasMappingCard(
          row: row,
          items: items,
          seenCount: seenCount,
          aliasMetrics: aliasMetrics, // Pass metrics for context
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
  final int? seenCount;
  final List<Map<String, dynamic>> aliasMetrics; // New field for context
  final VoidCallback onMap;
  final VoidCallback onCreateNew;
  final ValueChanged<int?> onSelectionChanged;

  const _AliasMappingCard({
    required this.row,
    required this.items,
    required this.seenCount,
    required this.aliasMetrics, // Receive metrics
    required this.onMap,
    required this.onCreateNew,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 🔍 Context Logic: Filter aliases for the selected item
    final contextAliases =
        row.selectedItemId != null
            ? aliasMetrics
                .where((m) => m['master_item_id'] == row.selectedItemId)
                .toList()
            : <Map<String, dynamic>>[];

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
              // Observational metric: "Seen X times before"
              if (seenCount != null && seenCount! > 0)
                Text(
                  'Seen $seenCount times',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

          // 👁️ UX-2: Context Panel (Read-Only)
          if (row.selectedItemId != null && contextAliases.isNotEmpty) ...[
            const SizedBox(height: AgroSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AgroSpacing.sm),
              decoration: BoxDecoration(
                color: AgroColors.neutral.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Existing aliases for this item:",
                    style: AgroTypography.captionEmphasis,
                  ),
                  const SizedBox(height: 4),
                  ...contextAliases.map((alias) {
                    final name = alias['alias_name'] ?? 'Unknown';
                    final count = alias['seen_count'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        "• $name — Seen $count times",
                        style: AgroTypography.tiny.copyWith(
                          color: AgroColors.textSecondary,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

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
      id: json['invoice_item_id'] ?? json['id'],
      aliasCode: json['item_code'] ?? json['alias_code'] ?? '',
      aliasName: json['item_name'] ?? json['alias_name'] ?? '',
      aliasUnit: json['uom'] ?? '',
    );
  }
}
