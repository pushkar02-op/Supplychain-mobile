import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/item_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_snack_bar.dart';

final _aliasSelectionProvider = StateProvider<Map<int, int?>>((ref) => {});

class AliasMappingScreen extends ConsumerWidget {
  const AliasMappingScreen({super.key});

  Future<void> _mapAlias(
    BuildContext context,
    WidgetRef ref,
    _AliasRow row,
    int masterItemId,
  ) async {
    await ref
        .read(itemAliasProvider.notifier)
        .mapAlias(
          billItemId: row.id,
          masterItemId: masterItemId,
          itemIdToRefresh: masterItemId,
        );
    if (!context.mounted) return;
    AgroSnackBar.success(context, 'Mapped ${row.aliasName} successfully');
    ref.invalidate(aliasMappingDataProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(aliasMappingDataProvider);
    final selection = ref.watch(_aliasSelectionProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text("Map Aliases to Items"),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: AgroErrorState.loadFailed(
                message: e.toString(),
                onRetry: () => ref.invalidate(aliasMappingDataProvider),
              ),
            ),
        data: (data) {
          final rows = data.aliases.map((e) => _AliasRow.fromJson(e)).toList();
          if (rows.isEmpty) {
            return const Center(
              child: AgroEmptyState(
                icon: Icons.check_circle_outline,
                title: "All aliases are mapped.",
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AgroSpacing.lg),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final selectedItemId = selection[row.id];
              final metric = data.metrics.firstWhere(
                (m) =>
                    (m['alias_name'] ?? '').toString().toLowerCase() ==
                    row.aliasName.toLowerCase(),
                orElse: () => {'seen_count': null},
              );
              final seenCount = metric['seen_count'];
              return _AliasMappingCard(
                row: row,
                items: data.items,
                selectedItemId: selectedItemId,
                seenCount: seenCount,
                aliasMetrics: data.metrics,
                onMap:
                    (masterItemId) =>
                        _mapAlias(context, ref, row, masterItemId),
                onCreateNew: () async {
                  final newItem = await context.push<Map<String, dynamic>>(
                    '/item-edit',
                    extra: {'name': '', 'default_uom_code': row.aliasUnit},
                  );
                  if (newItem != null) {
                    ref.read(_aliasSelectionProvider.notifier).state = {
                      ...selection,
                      row.id: newItem['id'] as int,
                    };
                  }
                },
                onSelectionChanged: (val) {
                  ref.read(_aliasSelectionProvider.notifier).state = {
                    ...selection,
                    row.id: val,
                  };
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AliasMappingCard extends StatelessWidget {
  final _AliasRow row;
  final List<Map<String, dynamic>> items;
  final int? selectedItemId;
  final int? seenCount;
  final List<Map<String, dynamic>> aliasMetrics;
  final Future<void> Function(int masterItemId) onMap;
  final VoidCallback onCreateNew;
  final ValueChanged<int?> onSelectionChanged;

  const _AliasMappingCard({
    required this.row,
    required this.items,
    required this.selectedItemId,
    required this.seenCount,
    required this.aliasMetrics,
    required this.onMap,
    required this.onCreateNew,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final contextAliases =
        selectedItemId != null
            ? aliasMetrics
                .where((m) => m['master_item_id'] == selectedItemId)
                .toList()
            : <Map<String, dynamic>>[];

    return AgroCard.outlined(
      padding: const EdgeInsets.all(AgroSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(row.aliasName, style: AgroTypography.cardTitle),
              ),
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
            // ignore: deprecated_member_use
            value: selectedItemId,
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
          if (selectedItemId != null && contextAliases.isNotEmpty) ...[
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
                  const Text(
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
                        "* $name - Seen $count times",
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
                  backgroundColor: AgroColors.success.text,
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    selectedItemId == null
                        ? null
                        : () => onMap(selectedItemId!),
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

  _AliasRow({
    required this.id,
    required this.aliasCode,
    required this.aliasName,
    required this.aliasUnit,
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
