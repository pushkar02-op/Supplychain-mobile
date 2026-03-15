import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventory_detail.dart';
import '../models/inventory_item.dart';
import '../models/inventory_signal.dart';
import '../models/inventory_transaction.dart';
import '../providers/inventory_provider.dart';
import '../screens/admin_reconciliation_detail_screen.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_status_badge.dart';

class InventoryDetailSheet extends ConsumerWidget {
  final InventoryItem item;
  final bool canManageUsers;

  const InventoryDetailSheet({
    super.key,
    required this.item,
    required this.canManageUsers,
  });

  static void show(
    BuildContext context,
    InventoryItem item, {
    required bool canManageUsers,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => InventoryDetailSheet(item: item, canManageUsers: canManageUsers),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = item.id;
    final unit = item.unit;
    final name = item.name;
    final detailFuture = ref.read(inventoryListProvider.notifier).fetchDetail(itemId);

    final ledgerStock = item.ledgerQty;
    final availableStock = item.quantity;
    final status = item.status.toUpperCase();
    final severity = item.severity.toUpperCase();
    final drift = availableStock - ledgerStock;

    final badgeStatus = AgroStatusParser.fromDriftSeverity(severity);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AgroSpacing.lg),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AgroColors.dividerLight),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AgroTypography.screenTitle),
                        Text('Unit: $unit', style: AgroTypography.caption),
                      ],
                    ),
                  ),
                  AgroStatusBadge.compact(
                    status: badgeStatus,
                    label:
                        severity == 'NONE'
                            ? 'OK'
                            : severity
                                .toLowerCase()
                                .split('_')
                                .map((part) {
                                  if (part.isEmpty) return part;
                                  return '${part[0].toUpperCase()}${part.substring(1)}';
                                })
                                .join(' '),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AgroSpacing.screenPadding),
                children: [
                  const Text('System Health', style: AgroTypography.sectionTitle),
                  const SizedBox(height: AgroSpacing.sectionHeaderGap),
                  FutureBuilder<InventoryDetail>(
                    future: detailFuture,
                    builder: (context, snapshot) {
                      final signalData = snapshot.data?.signals;
                      return _InventoryHealthSection(
                        status: status,
                        severity: severity,
                        drift: drift,
                        unit: unit,
                        canManageUsers: canManageUsers,
                        signalData: signalData,
                      );
                    },
                  ),
                  if (status != 'HEALTHY' && canManageUsers) ...[
                    const SizedBox(height: AgroSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => AdminReconciliationDetailScreen(
                                    itemId: itemId,
                                    itemName: name,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.rebase_edit, size: 18),
                        label: const Text('Admin Reconciliation'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AgroColors.warning.text,
                          padding: const EdgeInsets.symmetric(
                            vertical: AgroSpacing.md,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AgroSpacing.sectionGap),
                  const Text('Current Balance', style: AgroTypography.sectionTitle),
                  const SizedBox(height: AgroSpacing.sectionHeaderGap),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Available Stock',
                          '$availableStock $unit',
                          AgroColors.info,
                        ),
                      ),
                      const SizedBox(width: AgroSpacing.md),
                      Expanded(
                        child: _buildStatCard(
                          'Ledger Balance',
                          '$ledgerStock $unit',
                          status == 'HEALTHY'
                              ? AgroColors.success
                              : AgroColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AgroSpacing.sectionGap),
                  const Text('Batch Breakdown', style: AgroTypography.sectionTitle),
                  const SizedBox(height: AgroSpacing.sectionHeaderGap),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showBatchBreakdown(context, ref, itemId, name, unit),
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: const Text('View Batch Breakdown'),
                    ),
                  ),
                  const SizedBox(height: AgroSpacing.sectionGap),
                  const Text('Recent Transactions', style: AgroTypography.sectionTitle),
                  const SizedBox(height: AgroSpacing.sectionHeaderGap),
                  FutureBuilder<InventoryDetail>(
                    future: detailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Text(
                          'Error: ${snapshot.error}',
                          style: AgroTypography.bodySecondary,
                        );
                      }

                      final txns =
                          snapshot.data?.transactions ??
                          const <InventoryTransaction>[];
                      if (txns.isEmpty) {
                        return const AgroCard(
                          child: Center(child: Text('No transactions found')),
                        );
                      }

                      return AgroCard.outlined(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: txns.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) => _buildTxnRow(txns[i]),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    AgroSemanticColor semanticColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(AgroSpacing.md),
      decoration: BoxDecoration(
        color: semanticColor.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: semanticColor.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AgroTypography.caption),
          const SizedBox(height: AgroSpacing.xs),
          Text(
            value,
            style: AgroTypography.emphasis.copyWith(color: semanticColor.text),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnRow(InventoryTransaction txn) {
    final isIn = txn.txnType == 'IN';

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor:
            isIn
                ? AgroColors.success.background
                : AgroColors.critical.background,
        child: Icon(
          isIn ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIn ? AgroColors.success.text : AgroColors.critical.text,
          size: 20,
        ),
      ),
      title: const Text(
        'Inventory Transaction',
        style: AgroTypography.captionEmphasis,
      ),
      subtitle: Text(
        txn.createdAt?.toIso8601String().split('.').first ?? '',
        style: AgroTypography.caption,
      ),
      trailing: Text(
        '${txn.rawQty} ${txn.rawUnit}',
        style: AgroTypography.emphasis,
      ),
    );
  }

  void _showBatchBreakdown(
    BuildContext context,
    WidgetRef ref,
    int itemId,
    String itemName,
    String unit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.8,
            minChildSize: 0.4,
            expand: false,
            builder: (ctx, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AgroSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Batch Breakdown', style: AgroTypography.screenTitle),
                            Text(itemName, style: AgroTypography.caption),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<InventoryDetail>(
                      future: ref.read(inventoryListProvider.notifier).fetchDetail(itemId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        final batches = [...?snapshot.data?.batches];
                        if (batches.isEmpty) {
                          return const Center(child: Text('No batches found'));
                        }

                        batches.sort((a, b) {
                          final dateA = a.receivedAt ?? DateTime(2100);
                          final dateB = b.receivedAt ?? DateTime(2100);
                          return dateA.compareTo(dateB);
                        });

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: batches.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final batch = batches[i];
                            final qty = batch.quantity;
                            final isZero = qty <= 0.001;

                            return ListTile(
                              dense: true,
                              tileColor: isZero ? AgroColors.surfaceVariant : null,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Batch #${batch.id}',
                                    style: AgroTypography.captionEmphasis.copyWith(
                                      color:
                                          isZero
                                              ? AgroColors.textDisabled
                                              : AgroColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '$qty ${batch.unit.isEmpty ? unit : batch.unit}',
                                    style: AgroTypography.emphasis.copyWith(
                                      color:
                                          isZero
                                              ? AgroColors.textDisabled
                                              : AgroColors.info.text,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Received: ${batch.receivedAt?.toIso8601String().split('T').first ?? 'Unknown'}',
                                style: AgroTypography.caption.copyWith(
                                  color:
                                      isZero
                                          ? AgroColors.textDisabled
                                          : AgroColors.textSecondary,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _InventoryHealthSection extends StatelessWidget {
  final String status;
  final String severity;
  final double drift;
  final String unit;
  final bool canManageUsers;
  final InventorySignal? signalData;

  const _InventoryHealthSection({
    required this.status,
    required this.severity,
    required this.drift,
    required this.unit,
    required this.canManageUsers,
    required this.signalData,
  });

  @override
  Widget build(BuildContext context) {
    final isNormal = status == 'HEALTHY' && severity == 'NONE';
    final badgeStatus =
        isNormal
            ? AgroStatus.stable
            : AgroStatusParser.fromDriftSeverity(severity);

    final reconciliationAt = _resolveReconciliationTimestamp(signalData);
    final l7 = signalData?.outLast7d;
    final p7 = signalData?.outPrev7d;

    return AgroCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgroStatusBadge(
            status: badgeStatus,
            label:
                isNormal
                    ? 'Inventory Healthy'
                    : 'Inventory discrepancy detected',
          ),
          const SizedBox(height: AgroSpacing.sm),
          if (!canManageUsers)
            Text(
              isNormal ? 'Inventory Healthy' : 'Inventory discrepancy detected',
              style: AgroTypography.captionEmphasis,
            ),
          if (canManageUsers) ...[
            if (!isNormal) ...[
              Text(
                'Drift: ${drift >= 0 ? '+' : ''}$drift $unit',
                style: AgroTypography.captionEmphasis,
              ),
              const SizedBox(height: AgroSpacing.xs),
              Text('Severity: $severity', style: AgroTypography.caption),
            ],
            if (isNormal)
              const Text(
                'Inventory Healthy',
                style: AgroTypography.captionEmphasis,
              ),
            const SizedBox(height: AgroSpacing.xs),
            Text(
              'Last reconciliation: ${reconciliationAt ?? '--'}',
              style: AgroTypography.caption,
            ),
          ],
          if (l7 != null && p7 != null) ...[
            const SizedBox(height: AgroSpacing.sm),
            Text(
              'Recent outbound: $l7 vs previous $p7',
              style: AgroTypography.caption,
            ),
          ],
        ],
      ),
    );
  }

  String? _resolveReconciliationTimestamp(InventorySignal? signalData) {
    if (signalData?.lastReconciliation == null) return null;
    return signalData!.lastReconciliation!.toIso8601String();
  }
}
