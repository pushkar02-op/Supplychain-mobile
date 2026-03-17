import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drift_item.dart';
import '../providers/admin_ledger_provider.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_key_value_row.dart';
import '../ui/widgets/agro_status_badge.dart';
import '../widgets/drift_resolution_dialog.dart';
import 'admin_reconciliation_detail_screen.dart';

class AdminInventoryDriftScreen extends ConsumerWidget {
  const AdminInventoryDriftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(driftReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drift Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(driftReportProvider.notifier).refresh(),
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) {
          if (report.isEmpty) {
            return AgroEmptyState(
              icon: Icons.check_circle_outline,
              iconColor: AgroColors.success.text,
              title: 'No drift detected.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AgroSpacing.sm),
            itemCount: report.length,
            separatorBuilder:
                (context, index) => const SizedBox(height: AgroSpacing.sm),
            itemBuilder: (context, index) {
              final item = report[index];
              return _DriftItemCard(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => AgroErrorState.loadFailed(
              onRetry: () => ref.read(driftReportProvider.notifier).refresh(),
            ),
      ),
    );
  }
}

/// Card displaying drift information for a single item with severity-based styling.
class _DriftItemCard extends StatelessWidget {
  final DriftItem item;

  const _DriftItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final delta = item.drift;
    final severity = _severityFromDrift(delta);
    final itemName = item.itemName ?? 'Unknown';
    final itemId = item.itemId;
    final available = item.stateQty;
    final ledger = item.ledgerQty;
    final canResolve = delta != 0;

    final status = AgroStatusParser.fromDriftSeverity(severity);
    final severityStyle = AgroSeverity.fromStatus(status);

    return Container(
      decoration: BoxDecoration(
        color: severityStyle.backgroundColor,
        borderRadius: AgroShapes.cardRadius,
        border: Border.all(color: severityStyle.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AgroShapes.cardRadius,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => AdminReconciliationDetailScreen(
                      itemId: itemId,
                      itemName: itemName,
                    ),
              ),
            );
          },
          borderRadius: AgroShapes.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AgroSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Item name + severity badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(itemName, style: AgroTypography.cardTitle),
                    ),
                    AgroStatusBadge(
                      status: status,
                      label: _toTitleCase(severity),
                    ),
                  ],
                ),
                const Divider(color: AgroColors.divider),
                // Available (Batch) row
                AgroKeyValueRow(
                  label: 'Available (Batch)',
                  value: '$available',
                ),
                const SizedBox(height: AgroSpacing.xs),
                // Ledger row
                AgroKeyValueRow(label: 'Ledger', value: '$ledger'),
                const Divider(color: AgroColors.divider),
                // Net Drift row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NET DRIFT:', style: AgroTypography.emphasis),
                    Text(
                      delta > 0
                          ? '+${delta.toStringAsFixed(3)}'
                          : delta.toStringAsFixed(3),
                      style: AgroTypography.metricValue.copyWith(
                        color: severityStyle.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AgroSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canResolve
                          ? () async {
                              await DriftResolutionDialog.show(context, item);
                            }
                          : null,
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Resolve Drift'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _severityFromDrift(double drift) {
  final delta = drift.abs();
  if (delta == 0) return 'NONE';
  if (delta < 1) return 'MINOR';
  return 'CRITICAL';
}

String _toTitleCase(String value) {
  return value.toLowerCase().split('_').map((part) {
    if (part.isEmpty) return part;
    return '${part[0].toUpperCase()}${part.substring(1)}';
  }).join(' ');
}
