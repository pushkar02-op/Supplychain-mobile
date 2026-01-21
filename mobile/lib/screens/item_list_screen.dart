import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/item_service.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';

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

  // PRESERVED EXACTLY: Delete callback
  Future<void> _deleteItem(int id) async {
    await ItemService.deleteItem(id);
    _fetchItems();
  }

  // PRESERVED EXACTLY: Map bill item to item callback
  Future<void> _mapBillItemToItem(int billItemId, int itemId) async {
    await ItemService.mapAlias(billItemId, itemId);
    _fetchItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mart Bill item mapped successfully')),
    );
  }

  // PRESERVED EXACTLY: Mapping dialog
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
              SizedBox(height: AgroSpacing.sm + 2), // 10px as before
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
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Items'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error.isNotEmpty) {
      return AgroErrorState(
        title: 'Failed to load items',
        message: error,
        onRetry: _fetchItems,
      );
    }

    if (items.isEmpty) {
      return AgroEmptyState(
        icon: Icons.category_outlined,
        title: 'No items in catalog',
        actionLabel: 'Add your first item',
        onAction: () async {
          final ok = await context.push('/item-edit');
          if (ok == true) _fetchItems();
        },
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ItemCard(
          item: item,
          onRefresh: _fetchItems,
          onDelete: _deleteItem,
        );
      },
    );
  }
}

/// Item card with expansion for aliases and conversions.
/// Preserves all action callbacks exactly.
class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;
  final Future<void> Function(int) onDelete;

  const _ItemCard({
    required this.item,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final aliases = List<Map<String, dynamic>>.from(item['aliases'] ?? []);
    final conversions = List<Map<String, dynamic>>.from(
      item['conversions'] ?? [],
    );

    return Card(
      margin: EdgeInsets.all(AgroSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AgroColors.divider),
      ),
      child: ExpansionTile(
        title: Text(item['name'], style: AgroTypography.cardTitle),
        subtitle: Text(
          'Default UOM: ${item['default_uom_code'] ?? 'N/A'}',
          style: AgroTypography.caption,
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AgroSpacing.lg,
              vertical: AgroSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aliases section
                Text('Aliases:', style: AgroTypography.emphasis),
                Wrap(
                  spacing: AgroSpacing.xs + 2, // 6px as before
                  children:
                      aliases.isNotEmpty
                          ? aliases
                              .map(
                                (a) => Chip(
                                  label: Text(
                                    '${a['alias_name']} (${a['alias_code']})',
                                    style: AgroTypography.caption,
                                  ),
                                ),
                              )
                              .toList()
                          : [
                            Text(
                              'No aliases',
                              style: AgroTypography.bodySecondary,
                            ),
                          ],
                ),
                SizedBox(height: AgroSpacing.sm),

                // Conversions section
                Text('Conversions:', style: AgroTypography.emphasis),
                conversions.isNotEmpty
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          conversions.map((c) {
                            return Row(
                              children: [
                                Text(
                                  '1 ${item['default_uom_code'] ?? ''} = ',
                                  style: AgroTypography.body,
                                ),
                                Text(
                                  '${c['conversion_factor']} ${c['target_unit']}',
                                  style: AgroTypography.emphasis,
                                ),
                              ],
                            );
                          }).toList(),
                    )
                    : Text(
                      'No conversions',
                      style: AgroTypography.bodySecondary,
                    ),
                SizedBox(height: AgroSpacing.sm),

                // PRESERVED EXACTLY: Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        Icons.visibility,
                        size: 18,
                        color: AgroColors.primary,
                      ),
                      label: Text(
                        'View Details',
                        style: TextStyle(color: AgroColors.primary),
                      ),
                      onPressed: () {
                        context.push('/item-detail', extra: item);
                      },
                    ),
                    // PRESERVED EXACTLY: Edit button
                    IconButton(
                      icon: Icon(Icons.edit, color: AgroColors.textSecondary),
                      tooltip: 'Edit',
                      onPressed: () async {
                        final ok = await context.push(
                          '/item-edit',
                          extra: item,
                        );
                        if (ok == true) onRefresh();
                      },
                    ),
                    // PRESERVED EXACTLY: Delete button (no confirmation, direct call)
                    IconButton(
                      icon: Icon(Icons.delete, color: AgroColors.critical.text),
                      tooltip: 'Delete',
                      onPressed: () => onDelete(item['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
