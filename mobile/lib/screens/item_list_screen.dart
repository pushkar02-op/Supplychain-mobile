import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/create_result.dart';
import '../providers/item_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_snack_bar.dart';

class ItemListScreen extends ConsumerWidget {
  const ItemListScreen({super.key});

  Future<void> _showMappingDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> unmappedBillItems,
    List<Map<String, dynamic>> items,
  ) async {
    int? selectedBillItemId;
    int? selectedItemId;

    await showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Map Mart Bill Item to Item'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
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
                        onChanged:
                            (val) =>
                                setDialogState(() => selectedBillItemId = val),
                        decoration: const InputDecoration(
                          labelText: 'Unmapped Mart Bill Item',
                        ),
                      ),
                      const SizedBox(height: AgroSpacing.sm + 2),
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: selectedItemId,
                        isExpanded: true,
                        items:
                            items.map((item) {
                              return DropdownMenuItem<int>(
                                value: item['id'],
                                child: Text(item['name']),
                              );
                            }).toList(),
                        onChanged:
                            (val) => setDialogState(() => selectedItemId = val),
                        decoration: const InputDecoration(
                          labelText: 'Select Item',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedBillItemId == null ||
                            selectedItemId == null) {
                          return;
                        }
                        await ref
                            .read(itemAliasProvider.notifier)
                            .mapAlias(
                              billItemId: selectedBillItemId!,
                              masterItemId: selectedItemId!,
                              itemIdToRefresh: selectedItemId,
                            );
                        if (!context.mounted) return;
                        AgroSnackBar.success(
                          context,
                          'Mart Bill item mapped successfully',
                        );
                        ref.invalidate(aliasMappingDataProvider);
                        Navigator.pop(context);
                      },
                      child: const Text('Map'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(itemListProvider);
    final aliasData = ref.watch(
      aliasMappingDataProvider.select((async) => async.valueOrNull),
    );

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Items'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
        actions: [
          stateAsync.when(
            data:
                (state) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Inactive',
                      style: AgroTypography.caption.copyWith(
                        color: AgroColors.textSecondary,
                      ),
                    ),
                    Switch(
                      value: state.statusFilter == 'all',
                      onChanged:
                          (val) => ref
                              .read(itemListProvider.notifier)
                              .setStatusFilter(val ? 'all' : 'active'),
                      // ignore: deprecated_member_use
                      activeColor: AgroColors.primary,
                    ),
                  ],
                ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Map Mart Bill Items',
            onPressed: () async {
              final data = aliasData;
              if (data == null) return;
              await _showMappingDialog(context, ref, data.aliases, data.items);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Item',
            onPressed: () async {
              final result = await context.push('/item-edit');
              if (result == CreateResult.created) {
                ref.invalidate(itemListProvider);
              }
            },
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => AgroErrorState(
              title: 'Failed to load items',
              message: e.toString(),
              onRetry: () => ref.read(itemListProvider.notifier).refresh(),
            ),
        data:
            (state) => RefreshIndicator(
              onRefresh: () async => ref.refresh(itemListProvider.future),
              child:
                  state.items.isEmpty
                      ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 420,
                            child: AgroEmptyState(
                              icon: Icons.category_outlined,
                              title: 'No items in catalog',
                              actionLabel: 'Add your first item',
                              onAction: () async {
                                final result = await context.push('/item-edit');
                                if (result == CreateResult.created) {
                                  ref.invalidate(itemListProvider);
                                }
                              },
                            ),
                          ),
                        ],
                      )
                      : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return _ItemCard(item: item);
                        },
                      ),
            ),
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aliases = List<Map<String, dynamic>>.from(item['aliases'] ?? []);
    final conversions = List<Map<String, dynamic>>.from(
      item['conversions'] ?? [],
    );
    final isInactive = item['status'] == 'INACTIVE';

    return Opacity(
      opacity: isInactive ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.all(AgroSpacing.sm),
        elevation: 0,
        color: isInactive ? AgroColors.surfaceVariant : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isInactive ? AgroColors.textSecondary : AgroColors.divider,
          ),
        ),
        child: ExpansionTile(
          title: Row(
            children: [
              Expanded(
                child: Text(item['name'], style: AgroTypography.cardTitle),
              ),
              if (isInactive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AgroSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AgroColors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Inactive',
                    style: AgroTypography.caption.copyWith(
                      color: AgroColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Default UOM: ${item['default_uom_code'] ?? 'N/A'}',
                style: AgroTypography.caption,
              ),
              if (aliases.isNotEmpty || conversions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      if (aliases.isNotEmpty) 'Aliases: ${aliases.length}',
                      if (conversions.isNotEmpty)
                        'Conversions: ${conversions.length}',
                    ].join(' - '),
                    style: AgroTypography.caption.copyWith(
                      color: AgroColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AgroSpacing.lg,
                vertical: AgroSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aliases:', style: AgroTypography.emphasis),
                  Wrap(
                    spacing: AgroSpacing.xs + 2,
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
                              const Text(
                                'No aliases',
                                style: AgroTypography.bodySecondary,
                              ),
                            ],
                  ),
                  const SizedBox(height: AgroSpacing.sm),
                  const Text('Conversions:', style: AgroTypography.emphasis),
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
                      : const Text(
                        'No conversions',
                        style: AgroTypography.bodySecondary,
                      ),
                  const SizedBox(height: AgroSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(
                          Icons.visibility,
                          size: 18,
                          color: AgroColors.primary,
                        ),
                        label: const Text(
                          'View Details',
                          style: TextStyle(color: AgroColors.primary),
                        ),
                        onPressed: () {
                          context.push('/item-detail', extra: item);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: AgroColors.textSecondary,
                        ),
                        tooltip: 'Edit',
                        onPressed: () async {
                          final result = await context.push(
                            '/item-edit',
                            extra: item,
                          );
                          if (result == CreateResult.created) {
                            ref.invalidate(itemListProvider);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
