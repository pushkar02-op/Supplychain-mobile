import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_status_badge.dart';
import '../widgets/inventory_detail_sheet.dart';
import 'admin_inventory_drift_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(inventoryListProvider);
    final itemsAsync = ref.watch(inventoryItemOptionsProvider);
    final unitsAsync = ref.watch(inventoryUnitOptionsProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final isAdmin = ref.watch(authProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AgroColors.adminAccent,
                ),
                tooltip: 'Reconciliation (Admin Only)',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminInventoryDriftScreen(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Text(
                e.toString(),
                style: AgroTypography.body.copyWith(
                  color: AgroColors.critical.text,
                ),
              ),
            ),
        data: (state) {
          final filterItems =
              itemsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
          final filterUnits = unitsAsync.valueOrNull ?? const <String>[];

          return Padding(
            padding: const EdgeInsets.all(AgroSpacing.screenPadding),
            child: Column(
              children: [
                _InventoryFilterBar(
                  items: filterItems,
                  units: filterUnits,
                  selectedItemId: state.selectedItemId,
                  selectedUnit: state.selectedUnit,
                  onItemChanged:
                      (id) =>
                          ref.read(inventoryListProvider.notifier).setItem(id),
                  onUnitChanged:
                      (u) =>
                          ref.read(inventoryListProvider.notifier).setUnit(u),
                ),
                const SizedBox(height: AgroSpacing.md),
                Expanded(
                  child:
                      state.items.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warehouse_outlined,
                                  size: 64,
                                  color: AgroColors.textDisabled,
                                ),
                                const SizedBox(height: AgroSpacing.lg),
                                Text(
                                  'No inventory records found',
                                  style: AgroTypography.cardTitle.copyWith(
                                    color: AgroColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            itemCount: state.items.length,
                            itemBuilder: (context, i) {
                              final inv = state.items[i];
                              final availableStock =
                                  (inv['state_qty'] as num?)?.toDouble() ?? 0.0;
                              final unit = inv['unit'] ?? '';
                              final statusKind = _deriveStatusKind(inv);
                              final lastUpdated = _resolveLastUpdated(inv);

                              return AgroCard(
                                margin: const EdgeInsets.only(
                                  bottom: AgroSpacing.md,
                                ),
                                onTap:
                                    () => InventoryDetailSheet.show(
                                      context,
                                      inv,
                                      isAdmin:
                                          ref
                                              .read(authProvider)
                                              .value
                                              ?.isAdmin ??
                                          false,
                                    ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AgroSpacing.lg,
                                    vertical: AgroSpacing.md,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              inv['name'] ?? 'Unknown',
                                              style: AgroTypography.cardTitle,
                                            ),
                                          ),
                                          const SizedBox(width: AgroSpacing.sm),
                                          _InventoryStatusBadge(
                                            kind: statusKind,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AgroSpacing.xs),
                                      Text(
                                        '$availableStock $unit',
                                        style: AgroTypography.emphasis.copyWith(
                                          fontSize: 16,
                                        ),
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: AgroSpacing.xs),
                                      Text(
                                        'Last updated: $lastUpdated',
                                        style: AgroTypography.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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

class _InventoryFilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final List<String> units;
  final int? selectedItemId;
  final String? selectedUnit;
  final ValueChanged<int?> onItemChanged;
  final ValueChanged<String?> onUnitChanged;

  const _InventoryFilterBar({
    required this.items,
    required this.units,
    this.selectedItemId,
    this.selectedUnit,
    required this.onItemChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter:', style: AgroTypography.captionEmphasis),
          const SizedBox(height: AgroSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: selectedItemId,
                  decoration: const InputDecoration(labelText: 'Item'),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('All Items'),
                    ),
                    ...items.map(
                      (item) => DropdownMenuItem(
                        value: item['id'],
                        child: Text(item['name']),
                      ),
                    ),
                  ],
                  onChanged: onItemChanged,
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: AgroSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedUnit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Units'),
                    ),
                    ...units.map(
                      (u) => DropdownMenuItem(value: u, child: Text(u)),
                    ),
                  ],
                  onChanged: onUnitChanged,
                  isExpanded: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _InventoryStatusKind { criticalDrift, drift, forecastAlert, ok }

_InventoryStatusKind _deriveStatusKind(Map<String, dynamic> inv) {
  final status = (inv['status'] as String? ?? 'HEALTHY').toUpperCase();
  final severity = (inv['severity'] as String? ?? 'NONE').toUpperCase();
  final signals =
      (inv['signals'] as List<dynamic>?)
          ?.map((e) => e.toString().toUpperCase())
          .toList() ??
      const <String>[];

  if (severity == 'CRITICAL' || status == 'CRITICAL_DRIFT') {
    return _InventoryStatusKind.criticalDrift;
  }
  if (status != 'HEALTHY' || severity == 'MAJOR' || severity == 'MINOR') {
    return _InventoryStatusKind.drift;
  }
  if (signals.any((s) => s != 'STABLE')) {
    return _InventoryStatusKind.forecastAlert;
  }
  return _InventoryStatusKind.ok;
}

String _resolveLastUpdated(Map<String, dynamic> inv) {
  final raw =
      inv['last_updated_at'] ??
      inv['updated_at'] ??
      inv['as_of'] ??
      inv['last_reconciled_at'];
  if (raw == null) return '--';
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return raw.toString();

  final now = DateTime.now();
  final diff = now.difference(parsed.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _InventoryStatusBadge extends StatelessWidget {
  final _InventoryStatusKind kind;

  const _InventoryStatusBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _InventoryStatusKind.criticalDrift:
        return const AgroStatusBadge.compact(
          status: AgroStatus.critical,
          label: 'CRITICAL_DRIFT',
        );
      case _InventoryStatusKind.drift:
        return const AgroStatusBadge.compact(
          status: AgroStatus.major,
          label: 'DRIFT',
        );
      case _InventoryStatusKind.forecastAlert:
        return const AgroStatusBadge.compact(
          status: AgroStatus.info,
          label: 'FORECAST_ALERT',
        );
      case _InventoryStatusKind.ok:
        return const AgroStatusBadge.compact(
          status: AgroStatus.stable,
          label: 'OK',
        );
    }
  }
}
